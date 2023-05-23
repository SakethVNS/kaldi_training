#!/bin/bash

set -e -o pipefail

# Modified ivector common script, extracts ivectors given a trained extractor
stage=0
nj=5
data_folder=data
exp_folder=exp #exp_hindi_model_1
test_sets="dev" #"dev eval"
gmm=tri3_3200_48000                 # This specifies a GMM-dir from the features of the type you're training the system on;
                         # it should contain alignments for 'train_set'.
mfcc_config=conf/mfcc_hires.conf
num_threads_ubm=10

nj_extractor=2
# It runs a JOB with '-pe smp N', where N=$[threads*processes]
num_processes_extractor=4
num_threads_extractor=4

nnet3_affix=             # affix for exp/nnet3 directory to put iVector stuff in (e.g.
                         # in the tedlium recip it's _cleaned).

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

echo "---------------exp folder: $exp_folder---------------"
echo "---------------test sets: $test_sets---------------"
#gmm_dir=$exp_folder/${gmm}
#ali_dir=$exp_folder/${gmm}_ali_${train_set}_sp

#for f in $data_folder/${train_set}/feats.scp ${gmm_dir}/final.mdl; do
#  if [ ! -f $f ]; then
#    echo "$0: expected file $f to exist"
#    exit 1
#  fi
#done


if [ $stage -le 2 ]; then
  echo "$0: creating high-resolution MFCC features for test set only"

  for datadir in ${test_sets}; do
    utils/copy_data_dir.sh $data_folder/$datadir $data_folder/${datadir}_hires
  done

  # do volume-perturbation on the training data prior to extracting hires
  # features; this helps make trained nnets more invariant to test data volume.
  #utils/data/perturb_data_dir_volume.sh $data_folder/${train_set}_sp_hires

  for datadir in ${test_sets}; do
    steps/make_mfcc.sh --nj $nj --mfcc-config $mfcc_config \
      --cmd "$train_cmd" $data_folder/${datadir}_hires
    steps/compute_cmvn_stats.sh $data_folder/${datadir}_hires
    utils/fix_data_dir.sh $data_folder/${datadir}_hires
  done
fi


if [ $stage -le 5 ]; then
  for data in ${test_sets}; do
    nspk=$(wc -l <$data_folder/${data}_hires/spk2utt)
    nspk_nj=$nj
    steps/online/nnet2/extract_ivectors_online.sh --cmd "run.pl" --nj "${nspk_nj}" \
      $data_folder/${data}_hires $exp_folder/nnet3/extractor \
      $exp_folder/nnet3/ivectors_${data}_hires
  done
fi


exit 0;
