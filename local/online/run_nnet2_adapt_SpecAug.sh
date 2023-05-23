#!/usr/bin/env bash
# This script extracts mfcc features using mfcc_config and trains ubm model and
# ivector extractor and extracts ivector for train and test.
. ./cmd.sh


stage=0
nnet_affix=_online_iitm
ivector_dim=100
mfcc_config=conf/mfcc_hires.conf
use_ivector=true # If false, it skips training ivector extractor and
                 # ivector extraction stages.
online_cmvn_iextractor=false
exp_fold=exp
extractor="$exp_fold/nnet3/extractor"
train_sets="cs"
test_sets="ASER_RJ_Hindi_test"

nj=8
. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh
use_gpu=1
if $use_gpu; then
  if ! cuda-compiled; then
    cat <<EOF && exit 1
This script is intended to be used with GPUs but you have not compiled Kaldi with CUDA
If you want to use GPUs (and have them), go to src/, and configure and make on a machine
where "nvcc" is installed.  Otherwise, call this script with --use-gpu false
EOF
  fi
  parallel_opts="--gpu 1"
  num_threads=1
  minibatch_size=512
else
  # Use 4 nnet jobs just like run_4d_gpu.sh so the results should be
  # almost the same, but this may be a little bit slow.
  num_threads=16
  minibatch_size=128
  parallel_opts="--num-threads $num_threads"
  dir=$exp_fold/nnet2${nnet_affix}/nnet
fi

echo $test_sets

#mfccdir=dumpdir/mfcc_data

#./steps/make_mfcc.sh --cmd "run.pl" --nj "5" data/$test_set $exp_fold/make_mfcc/$adapt $mfccdir/$test_set || exit 1;
#./steps/compute_cmvn_stats.sh data/$test_set $exp_fold/make_mfcc/$test_set $mfccdir/$test_set || exit 1;
#./utils/fix_data_dir.sh data/$test_set || exit 1;

if [ $stage -le 0 ]; then
  echo "$0: creating high-resolution MFCC features."
  mfccdir=data/${train_sets}_hires/data

  for datadir in $train_sets; do
    utils/copy_data_dir.sh data/$datadir data/${datadir}_hires
    utils/copy_data_dir.sh --utt-suffix spec1 data/$datadir data/${datadir}_specaug_hires

    steps/make_mfcc.sh --nj $nj --mfcc-config $mfcc_config \
      --cmd "$train_cmd" data/${datadir}_hires || exit 1;
    steps/compute_cmvn_stats.sh data/${datadir}_hires

    grep -vf /media/run/kaldi/egs/iitm_baseline/English_ASR_Challenge/asr/valid_spec_english_IITM_set data/${datadir}_specaug_hires/text > data/${datadir}_specaug_hires/text_spec_tmp
    mv data/${datadir}_specaug_hires/text_spec_tmp data/${datadir}_specaug_hires/text
    echo "Removed specaugmented valid versions. Ensure valid_spec_UP_RJ_set text file is correctly maintained in retrained_asr directory"

    utils/fix_data_dir.sh data/${datadir}_specaug_hires

    steps/make_mfcc_specaug.sh --nj $nj --mfcc-config $mfcc_config \
      --cmd "$train_cmd" data/${datadir}_specaug_hires || exit 1;
    steps/compute_cmvn_stats.sh data/${datadir}_specaug_hires

   # sid/compute_vad_decision.sh --nj $nj --cmd "$train_cmd" \
   # data/${datadir}_hires $exp_fold/make_vad  data/${datadir}_hires/data

    utils/fix_data_dir.sh data/${datadir}_hires
    utils/fix_data_dir.sh data/${datadir}_specaug_hires

  done

  for datadir in $test_sets; do # doing two separate loops so that I don't get confused as to whether specaug is operating on valid?!. It is not
    utils/copy_data_dir.sh data/$datadir data/${datadir}_hires

    steps/make_mfcc.sh --nj $nj --mfcc-config $mfcc_config \
      --cmd "$train_cmd" data/${datadir}_hires || exit 1;
    steps/compute_cmvn_stats.sh data/${datadir}_hires

    utils/fix_data_dir.sh data/${datadir}_hires

  done
fi


if [ $stage -le 3 ] && [ $ivector_dim -gt 0 ]; then
  # having a larger number of speakers is helpful for generalization, and to
  # handle per-utterance decoding well (iVector starts at zero).
  # steps/online/nnet2/copy_data_dir.sh --utts-per-spk-max 2 data/${train_set}_hires data/${train_set}_max2
# specaug1 is the version that is finally used ################################
#for file in {utt2spk,spk2utt,text,wav.scp};do cat data/${train_sets}_hires/$file data/$test_sets/$file > data/${adapt}_valid_nsp/$file;done
   #./utils/combine_data.sh data/${train_sets}_specaug1_hires data/${train_sets}_hires/ data/${train_sets}_specaug_hires/ 
   ./utils/combine_data.sh data/${train_sets}_specaug1_hires data/${train_sets}_hires/ 
   ./utils/fix_data_dir.sh data/${train_sets}_specaug1_hires
echo "SpecAug modified feature creation successful"
  steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj $nj --use-vad false \
    data/${train_sets}_specaug1_hires $extractor $exp_fold/nnet2${nnet_affix}/ivectors_adapt

  for t_set in ${test_sets};do
    echo $t_set
    steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj $nj --use-vad false \
    data/${t_set}_hires $extractor $exp_fold/nnet2${nnet_affix}/ivectors_${t_set}
  done
fi
