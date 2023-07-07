#!/usr/bin/env bash

# 1b is as 1a but uses xconfigs.


# First the options that are passed through to run_ivector_common.sh
# (some of which are also used in this script directly).
stage=9
decode_nj=8
train_set=train_English          #Train set Name
test_sets=dev_English        #"test_dev93 test_eval92"
gmm=tri3_7500_600000  # this is the source gmm-dir for the data-type of interest; it
                   # should have alignments for the specified training data.
nnet3_affix=_cleaned
exp=exp_jun22_nnet3

num_threads_ubm=5
lang=lang_iitm
mfcc_conf=${INI__mfcc__mfcc_conf}
nj_extractor=2
# It runs a JOB with '-pe smp N', where N=$[threads*processes]
num_threads_extractor=2
num_processes_extractor=2

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

local/nnet3/run_ivector_common.sh --stage $stage \
                                  --train-set $train_set \
                                  --gmm $gmm \
                                  --nnet3-affix "$nnet3_affix" \
                                  --exp $exp || exit 1;

# local/nnet3/run_ivector_common_IITM.sh \
#   --stage $stage --nj $nj \
#   --train-set $train_set --gmm $gmm --test-sets $test_sets --data-folder $datadir --exp-folder $expdir \
#   --mfcc-config=$mfcc_conf
#   --num-threads-ubm $num_threads_ubm \
#   --nj-extractor $nj_extractor \
#   --num-processes-extractor $num_processes_extractor \
#   --num-threads-extractor $num_threads_extractor \
#   --nnet3-affix "$nnet3_affix"


gmm_dir=$exp/${gmm}
graph_dir=$gmm_dir/graph
ali_dir=$exp/${gmm}_ali_${train_set}_sp
dir=exp/nnet3${nnet3_affix}/tdnn${affix:+_$affix}_sp
train_data_dir=data/${train_set}_sp_hires
train_ivector_dir=exp/nnet3${nnet3_affix}/ivectors_${train_set}_sp_hires


for f in $train_data_dir/feats.scp $train_ivector_dir/ivector_online.scp \
     $graph_dir/HCLG.fst $ali_dir/ali.1.gz $gmm_dir/final.mdl; do
  [ ! -f $f ] && echo "$0: expected file $f to exist" && exit 1
done

if [ $stage -le 11 ]; then
  echo "$0: creating neural net configs";

  num_targets=$(tree-info $ali_dir/tree |grep num-pdfs|awk '{print $2}')

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

if [ $stage -le 12 ]; then
  if [[ $(hostname -f) == *.clsp.jhu.edu ]] && [ ! -d $dir/egs/storage ]; then
    utils/create_split_dir.pl \
     /export/b0{3,4,5,6}/$USER/kaldi-data/egs/librispeech-$(date +'%m_%d_%H_%M')/s5/$dir/egs/storage $dir/egs/storage
  fi

  steps/nnet3/train_dnn.py --stage=$train_stage \
    --cmd="$decode_cmd" \
    --feat.online-ivector-dir $train_ivector_dir \
    --feat.cmvn-opts="--norm-means=false --norm-vars=false" \
    --trainer.num-epochs 2 \
    --trainer.optimization.num-jobs-initial 2 \
    --trainer.optimization.num-jobs-final 2 \
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

if [ $stage -le -13 ]; then
  # this does offline decoding that should give about the same results as the
  # real online decoding (the one with --per-utt true)
  rm $dir/.error 2>/dev/null || true
  for test in test_clean test_other dev_clean dev_other; do
    (
    steps/nnet3/decode.sh --nj $decode_nj --cmd "$decode_cmd" \
      --online-ivector-dir $exp/nnet3${nnet3_affix}/ivectors_${test}_hires \
      ${graph_dir} data/${test}_hires $dir/decode_${test}_tgsmall || exit 1
    steps/lmrescore.sh --cmd "$decode_cmd" data/lang_test_{tgsmall,tgmed} \
      data/${test}_hires $dir/decode_${test}_{tgsmall,tgmed}  || exit 1
    steps/lmrescore_const_arpa.sh \
      --cmd "$decode_cmd" data/lang_test_{tgsmall,tglarge} \
      data/${test}_hires $dir/decode_${test}_{tgsmall,tglarge} || exit 1
    steps/lmrescore_const_arpa.sh \
      --cmd "$decode_cmd" data/lang_test_{tgsmall,fglarge} \
      data/${test}_hires $dir/decode_${test}_{tgsmall,fglarge} || exit 1
    ) || touch $dir/.error &
  done
  wait
  [ -f $dir/.error ] && echo "$0: there was a problem while decoding" && exit 1
fi

exit 0;
