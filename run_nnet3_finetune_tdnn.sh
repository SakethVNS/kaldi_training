#!/usr/bin/env bash

# 1b is as 1a but uses xconfigs.

# At this script level we don't support not running on GPU, as it would be painfully slow.
# If you want to run without GPU you'd have to call train_tdnn.sh with --gpu false,
# --num-threads 16 and --minibatch-size 128.

# First the options that are passed through to run_ivector_common.sh
# (some of which are also used in this script directly).
stage=0
decode_nj=8
nj=8
datadir=data
train_set=train_English          #Train set Name
test_sets=dev_English        #"test_dev93 test_eval92"

                   # should have alignments for the specified training data.
nnet3_affix=_cleaned
exp=exp_jun22_nnet3
use_gpu=true # This is for align script in stage 3


num_threads_ubm=5
lang=lang_iitm
mfcc_conf=${INI__mfcc__mfcc_conf}
nj_extractor=2
# It runs a JOB with '-pe smp N', where N=$[threads*processes]
num_threads_extractor=2
num_processes_extractor=2

src_ivector_extractor=$exp/nnet3_cleaned/extractor/

# Options which are not passed through to run_ivector_common.sh
affix=
train_stage=-10
common_egs_dir=
reporting_email=
remove_egs=true

input_model=
use_old_model=false

chunk_width=140,100,100


. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh


if ! cuda-compiled; then
  cat <<EOF && exit 1
This script is intended to be used with GPUs but you have not compiled Kaldi with CUDA
If you want to use GPUs (and have them), go to src/, and configure and make on a machine
where "nvcc" is installed.
EOF
fi

if [ $stage -le 1 ]; then
  echo "$0: Augmenting retrain set using speed and pitch perturbation"
  ./utils/data/perturb_data_dir_speed_3way.sh --always-include-prefix true $datadir/${train_set} $datadir/${train_set}_sp
  ./utils/data/perturb_data_dir_pitch_3way.sh --always-include-prefix true $datadir/${train_set} $datadir/${train_set}_pp
  ./utils/combine_data.sh $datadir/${train_set}_sp_pp $datadir/${train_set}_sp $datadir/${train_set}_pp
  ./utils/fix_data_dir.sh $datadir/${train_set}_sp_pp
fi

if [ $stage -le 2 ]; then
  echo "Feature extraction"
  steps/make_mfcc.sh --nj $nj --mfcc-config conf/mfcc_hires.conf \
  --cmd "$train_cmd" $datadir/${train_set}_sp_pp
  steps/compute_cmvn_stats.sh $datadir/${train_set}_sp_pp
  utils/fix_data_dir.sh $datadir/${train_set}_sp_pp

  echo "ivector extraction"
  echo "Checking if $src_ivector_extractor has features for ivector extractor information"
  for f in $src_ivector_extractor/final.dubm $src_ivector_extractor/final.mat $src_ivector_extractor/global_cmvn.stats \
      $src_ivector_extractor/online_cmvn.conf $src_ivector_extractor/splice_opts $src_ivector_extractor/num_jobs; do
      if [ ! -f $f ]; then
          echo "$f doesn't exist; make sure that ivector model is properly trained"
          exit 1
      fi

  steps/online/nnet2/extract_ivectors_online.sh --cmd "$cmd" --nj $nj \
  $datadir/${train_set}_sp_pp $src_ivector_extractor $datadir/${train_set}_sp_pp/ivectors || exit 1

fi

if [ $stage -le 3 ]; then
  echo "Get alignments from train set using trained model $exp"
  steps/nnet3/align.sh \
        --extra-left-context-initial 0 --extra-right-context-final 0 \
        --scale-opts "--transition-scale=1.0 --acoustic-scale=0.1 --self-loop-scale=0.1" \
        --use-gpu $use_gpu \
        --online-ivector-dir $datadir/${train_set}_sp_pp/ivectors $datadir/${train_set}_sp_pp data/$lang $exp $datadir/${train_set}_sp_pp/ali || exit 1;

fi



tdnn_dir=$exp/${nnet3_cleaned}/tdnn_sp
graph_dir=$tdnn_dir/../graph
ali_dir=$datadir/${train_set}_sp_pp/ali
dir=$exp/${nnet3_cleaned}/tdnn_sp
train_data_dir=$datadir/${train_set}_sp_pp
train_ivector_dir=$datadir/${train_set}_sp_pp/ivectors


for f in $train_data_dir/feats.scp $train_ivector_dir/ivector_online.scp \
     $ali_dir/ali.1.gz $tdnn_dir/final.mdl; do
  [ ! -f $f ] && echo "$0: expected file $f to exist" && exit 1
done

if [ $stage -le 11 ]; then
  echo "$0: creating neural net configs";

  num_targets=5456 # Change this to change the output dimension of tdnn

  mkdir -p $dir/configs
  cat <<EOF > $dir/configs/network.xconfig
  input dim=100 name=ivector
  input dim=40 name=input
  fixed-affine-layer name=lda input=Append(-2,-1,0,1,2,ReplaceIndex(ivector, t, 0)) affine-transform-file=$dir/configs/lda.mat

  relu-batchnorm-layer name=tdnn0 dim=1280
  relu-batchnorm-layer name=tdnn1 dim=1280 input=Append(-1,2)
  relu-batchnorm-layer name=tdnn2 dim=1280 input=Append(-3,3)
  relu-batchnorm-layer name=tdnn3 dim=1280 input=Append(-7,2)
  relu-batchnorm-layer name=tdnn4 dim=1280
  output-layer name=output input=tdnn4 dim=$num_targets max-change=1.5
EOF
  steps/nnet3/xconfig_to_configs.py --xconfig-file $dir/configs/network.xconfig \
    --config-dir $dir/configs || exit 1;
fi

if [ $stage -le 12 ] && [[ $use_old_model == true  ]]; then
  echo "This is to use already trained model to finetune"
  $train_cmd $dir/log/generate_input_model.log \
    nnet3-am-copy --raw=true $dir/final.mdl $dir/input.raw
  input_model=$dir/input.raw
fi

if [ $stage -le 12 ]; then
  if [[ $(hostname -f) == *.clsp.jhu.edu ]] && [ ! -d $dir/egs/storage ]; then
    utils/create_split_dir.pl \
     /export/b0{3,4,5,6}/$USER/kaldi-data/egs/librispeech-$(date +'%m_%d_%H_%M')/s5/$dir/egs/storage $dir/egs/storage
  fi

  steps/nnet3/train_dnn.py --stage=$train_stage \
    --cmd="$decode_cmd" \
    --feat.online-ivector-dir $train_ivector_dir \
    --feat.cmvn-opts="--norm-means=false --norm-vars=false" \
    --trainer.input-model $input_model \
    --trainer.num-epochs 2 \
    --trainer.optimization.num-jobs-initial 1 \
    --trainer.optimization.num-jobs-final 1 \
    --trainer.optimization.initial-effective-lrate 0.0017 \
    --trainer.optimization.final-effective-lrate 0.00017 \
    --egs.dir "$common_egs_dir" \
    --cleanup.remove-egs $remove_egs \
    --cleanup.preserve-model-interval 300 \
    --feat-dir=$train_data_dir \
    --ali-dir $ali_dir \
    --lang data/$lang \
    --reporting.email="$reporting_email" \
    --dir=$dir  || exit 1;

fi



exit 0;
