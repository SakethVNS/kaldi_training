#!/usr/bin/env bash

# This script uses weight transfer as Transfer learning method

set -e

# configs for 'chain'
stage=0
train_stage=-4
get_egs_stage=-10

exp_fold=exp_feb23
# adapt_no_sp="marathi_train"
# adapt=${adapt_no_sp}_sp
adapt_no_sp_pp="eng_train_dahanu"
main_adapt="eng_train_dahanu_augment"
test_sets="eng_valid"
## ASER_RJ_Hindi_test" # "DFS_2019 Nasik_2018 Ooloi_Ahmednagar_2019 DF_Ballaravada_2019"
dir=$exp_fold/chain/tdnn
datadir=/home/shreeharsha/Desktop/english_iitm_asr_challenge/NPTEL_IITM_English_Challenge/Train_Dev/transcription_dictionary/Trans_and_dict
# configs for transfer learning
#cp -r exp_eng_ready exp_eng_1
no_augment=0


#common_egs_dir=
lr1_factor=0.005 # learning-rate factor for blocks in the TDNN architecture
lr2_factor=0.005
lr3_factor=0.005
lr4_factor=0.005
lr5_factor=0.0
lr6_factor=0.0
lr7_factor=0.0
lr8_factor=0.0
lr9_factor=0.0
lr10_factor=0.0
lr11_factor=0.0
lr12_factor=0.0
lr13_factor=0.0
lr14_factor=0.00625
lr15_factor=0.00625
# New model 15 hidden layers and 2 final layers
#lr16_factor=0.00625
#lr17_factor=0.00625

nnet_affix=_online_iitm

#phone_lm_scales="1,10" # comma-separated list of positive integer multiplicities
                       # to apply to the different source data directories (used
                       # to give the adapt data a higher weight).

# model and dirs for source model used for transfer learning
src_mdl=$dir/final.mdl # input chain model
                                                    # trained on source dataset (wsj) and
                                                    # this model is transfered to the target domain.

src_mfcc_config=conf/mfcc_hires.conf # mfcc config used to extract higher dim
                                                  # mfcc features used for ivector training
                                                  # in source domain.
src_ivec_extractor_dir=$exp_fold/nnet3/extractor/  # source ivector extractor dir used to extract ivector for
                         # source data and the ivector for target data is extracted using this extractor.
                         # It should be nonempty, if ivector is used in source model training.

#src_lang=data/lang_generic_newtopo # source lang directory used to train source model.
                                # new lang dir for transfer learning experiment is prepared
                                # using source phone set phone.txt and lexicon.txt in src lang dir and
                                # word.txt target lang dir.
src_dict=data/local/all_dictionaries/english_dictionary/english_dictionary_one_sil/  # dictionary for source dataset containing lexicon.txt,
                                            # nonsilence_phones.txt,...
                                            # lexicon.txt used to generate lexicon.txt for
                                            # src-to-tgt transfer.

src_tree_dir=$exp_fold/chain/tree_a_sp # chain tree-dir for src data;
                                         # the alignment in target domain is
                                         # converted using src-tree

# End configuration section.

echo "$0 $@"  # Print the command line for logging

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

# dirs for src-to-tgt transfer experiment
lang_dir=data/lang_eng_wpp/   # lang dir for target data.# In harsha's experiment both lang_dir and src_lang_dir are same with new topo in src_lang_dir
#lang_src_tgt=$datadir/lang_iitm_eng_adapt #data/lang_adapt_${adapt}_test_$test_sets # This dir is prepared using phones.txt and lexicon from
#lang_src_tgt=$datadir/lang_hindi_adapt
lang_src_tgt=$datadir/lang_eng_wpp
lat_dir=$exp_fold/chain_lats_iitm
## Replacing LM files directly, ensure lang_dir is proper ####
# %%%%%%%%%%%%%%%%%% ^^^^^^^^^^^^^^^ Check the LM used ^^^^^^^^^^^^ ############### Best procedure is to just copy lang_generic/all-stories from asr folder in ../asr/data/
feat_calc=0 # Set this to 1 if stage 0 and feature calculation by local/online//nnet2_adapt_specaug is done(set to 0 for perturbation calculation else 1)



mkdir -p $datadir/$main_adapt
if [ $stage -le 0 ]; then
    for ada in $adapt_no_sp_pp;do
        echo "**********  $ada    **********************"
        adapt_pp=${ada}_pp
        adapt=${ada}_sp
    #done
   echo "$0: Augmenting retrain + valid set using speed perturbation"
   ./utils/data/perturb_data_dir_speed_3way.sh --always-include-prefix true $datadir/$ada $datadir/$adapt
   ./utils/data/perturb_data_dir_pitch_3way.sh --always-include-prefix true $datadir/$ada $datadir/$adapt_pp
   ./utils/combine_data.sh $datadir/${ada}_sp_pp $datadir/$adapt $datadir/$adapt_pp
   mv $datadir/${ada}_sp_pp/* $datadir/$adapt/
   rm -r $datadir/${ada}_sp_pp/
   echo "Check arguments in utils/custom_harsha_valid.sh. Now finding speed perturbed train versions only. Loss to be computed only on valid set, not valid_sp"
   echo "Using lang_dir variable for LM"
   mkdir -p $datadir/${adapt}_valid_nsp
   for file in {utt2spk,spk2utt,text,wav.scp};do cat $datadir/$adapt/$file > $datadir/${adapt}_valid_nsp/$file;done
   ./utils/fix_data_dir.sh $datadir/${adapt}_valid_nsp
   echo "Using lang_dir variable for LM"
   rm -rf $lang_src_tgt
   mv $lang_dir $lang_src_tgt
   cp -r $lang_src_tgt $lang_dir
   adapt="${adapt}_valid_nsp"
   echo "Now combining pitch perturbed versions of ${adapt_no_sp} into the adapt folder. 
   This will bring 2 new versions ((orig)*pitch perturbed at 2 factors)"
   #./utils/combine_data.sh $datadir/${adapt}_pp $datadir/${adapt}/ data/marathi_train_downshift_pp/ data/marathi_train_upshift_pp/
   adapt="${adapt}_pp"
done
utils/combine_data.sh $datadir/$main_adapt $datadir/eng_train_dahanu_sp_valid_nsp $datadir/wpp_train_set
fi
adapt=$main_adapt
if [ $feat_calc -eq 1 ]; then
#adapt="${adapt}_valid_nsp"
adapt1="${adapt}_pp"
fi
if [ $no_augment -eq 1  ]; then
    echo "Using dataset with no augmentation"
    utils/combine_data.sh $datadir/$adapt $datadir/$adapt_no_sp_pp
fi
echo $adapt
#exit 1

required_files="$src_mfcc_config $src_mdl $lang_src_tgt/phones.txt $src_dict/lexicon.txt $src_tree_dir/tree"
#echo $required_files
use_ivector=false
ivector_dim=$(nnet3-am-info --print-args=false $src_mdl | grep "ivector-dim" | cut -d" " -f2)
if [ -z $ivector_dim ]; then ivector_dim=0 ; fi

if [ ! -z $src_ivec_extractor_dir ]; then
  if [ $ivector_dim -eq 0 ]; then
    echo "$0: Source ivector extractor dir '$src_ivec_extractor_dir' is "
    echo "specified but ivector is not used in training the source model '$src_mdl'."
  else
    required_files="$required_files $src_ivec_extractor_dir/final.dubm $src_ivec_extractor_dir/final.mat $src_ivec_extractor_dir/final.ie"
    use_ivector=true
  fi
else
  if [ $ivector_dim -gt 0 ]; then
    echo "$0: ivector is used in training the source model '$src_mdl' but no "
    echo " --src-ivec-extractor-dir option as ivector dir for source model is specified." && exit 1;
  fi
fi

#exit 0
for f in $required_files; do
  if [ ! -f $f ]; then
    echo "$0: no such file $f" && exit 1;
  fi
done
echo "Copying perturbed data to data folder for SpecAugment"
echo $datadir
echo $adapt
cp -r $datadir/$adapt data/

if [ $stage -lt 3 ];then
    stage=0
fi
if [ $feat_calc != 1  ];then
echo "SpecAug copy features are found for all 10 versions (orig+noisy) speed pert*3 + (orig+noisy) pitch pert*2. So 20 versions in all"
local/online/run_nnet2_adapt_SpecAug.sh  --stage $stage \
                                 --ivector-dim $ivector_dim \
                                 --nnet-affix "$nnet_affix" \
                                 --mfcc-config $src_mfcc_config \
                                 --extractor $src_ivec_extractor_dir \
                                 --exp-fold $exp_fold \
                                 --train-sets $adapt \
                                 --test-sets $test_sets || exit 1;

fi
src_mdl_dir=`dirname $src_mdl`
ivec_opt=""
adapt=${adapt}_specaug1
if $use_ivector;then ivec_opt="--online-ivector-dir ${exp_fold}/nnet2${nnet_affix}/ivectors_adapt" ; fi
echo "here"

if [ $stage -le 4 ]; then
  # Get the alignments as lattices (gives the chain training more freedom).
  # use the same num-jobs as the alignments
  steps/nnet3/align_lats.sh --nj 5 --cmd "$train_cmd" $ivec_opt \
    --generate-ali-from-lats true \
    --acoustic-scale 1.0 --extra-left-context-initial 0 --extra-right-context-final 0 \
    --frames-per-chunk 70 \
    --scale-opts "--transition-scale=1.0 --self-loop-scale=1.0" \
    data/${adapt}_hires $lang_src_tgt $src_mdl_dir $lat_dir || exit 1;
  rm $lat_dir/fsts.*.gz # save space
  exit 0
fi

#nnet3-am-copy --raw=true --edits="set-learning-rate-factor name=* learning-rate-factor=$lr1_factor; set-learning-rate-factor name=tdnn1 learning-rate-factor=$lr1_factor;set-learning-rate-factor name=tdnnf2 learning-rate-factor=$lr2_factor ;set-learning-rate-factor name=tdnnf3 learning-rate-factor=$lr3_factor;set-learning-rate-factor name=tdnnf4 learning-rate-factor=$lr4_factor; set-learning-rate-factor name=tdnnf5 learning-rate-factor=$lr5_factor; set-learning-rate-factor name=tdnnf6 learning-rate-factor=$lr6_factor;set-learning-rate-factor name=tdnnf7 learning-rate-factor=$lr7_factor ;set-learning-rate-factor name=tdnnf8 learning-rate-factor=$lr8_factor;set-learning-rate-factor name=tdnnf9 learning-rate-factor=$lr9_factor;set-learning-rate-factor name=tdnnf10 learning-rate-factor=$lr10_factor;set-learning-rate-factor name=tdnnf11 learning-rate-factor=$lr11_factor ;set-learning-rate-factor name=tdnnf12 learning-rate-factor=$lr12_factor;set-learning-rate-factor name=tdnnf13 learning-rate-factor=$lr13_factor;set-learning-rate-factor name=prefinal-l learning-rate-factor=$lr14_factor;set-learning-rate-factor name=prefinal-chain learning-rate-factor=$lr14_factor ;set-learning-rate-factor name=prefinal-xent learning-rate-factor=$lr14_factor;set-learning-rate-factor name=output learning-rate-factor=$lr15_factor; set-learning-rate-factor name=output-xent learning-rate-factor=$lr15_factor" \
# Use above line for older model
# Use below line for newer larger model
#nnet3-am-copy --raw=true --edits="set-learning-rate-factor name=* learning-rate-factor=$lr1_factor; set-learning-rate-factor name=tdnn1 learning-rate-factor=$lr1_factor;set-learning-rate-factor name=tdnnf2 learning-rate-factor=$lr2_factor ;set-learning-rate-factor name=tdnnf3 learning-rate-factor=$lr3_factor;set-learning-rate-factor name=tdnnf4 learning-rate-factor=$lr4_factor; set-learning-rate-factor name=tdnnf5 learning-rate-factor=$lr5_factor; set-learning-rate-factor name=tdnnf6 learning-rate-factor=$lr6_factor;set-learning-rate-factor name=tdnnf7 learning-rate-factor=$lr7_factor ;set-learning-rate-factor name=tdnnf8 learning-rate-factor=$lr8_factor;set-learning-rate-factor name=tdnnf9 learning-rate-factor=$lr9_factor;set-learning-rate-factor name=tdnnf10 learning-rate-factor=$lr10_factor;set-learning-rate-factor name=tdnnf11 learning-rate-factor=$lr11_factor ;set-learning-rate-factor name=tdnnf12 learning-rate-factor=$lr12_factor;set-learning-rate-factor name=tdnnf13 learning-rate-factor=$lr13_factor;set-learning-rate-factor name=tdnnf14 learning-rate-factor=$lr14_factor;set-learning-rate-factor name=tdnnf15 learning-rate-factor=$lr15_factor;set-learning-rate-factor name=prefinal-l learning-rate-factor=$lr16_factor;set-learning-rate-factor name=prefinal-chain learning-rate-factor=$lr16_factor ;set-learning-rate-factor name=prefinal-xent learning-rate-factor=$lr16_factor;set-learning-rate-factor name=output learning-rate-factor=$lr17_factor; set-learning-rate-factor name=output-xent learning-rate-factor=$lr17_factor"
if [ $stage -le 5 ]; then
  $train_cmd $dir/log/generate_input_mdl.log \
      nnet3-am-copy --raw=true --edits="set-learning-rate-factor name=* learning-rate-factor=$lr1_factor; set-learning-rate-factor name=tdnn1 learning-rate-factor=$lr1_factor;set-learning-rate-factor name=tdnnf2 learning-rate-factor=$lr2_factor ;set-learning-rate-factor name=tdnnf3 learning-rate-factor=$lr3_factor;set-learning-rate-factor name=tdnnf4 learning-rate-factor=$lr4_factor; set-learning-rate-factor name=tdnnf5 learning-rate-factor=$lr5_factor; set-learning-rate-factor name=tdnnf6 learning-rate-factor=$lr6_factor;set-learning-rate-factor name=tdnnf7 learning-rate-factor=$lr7_factor ;set-learning-rate-factor name=tdnnf8 learning-rate-factor=$lr8_factor;set-learning-rate-factor name=tdnnf9 learning-rate-factor=$lr9_factor;set-learning-rate-factor name=tdnnf10 learning-rate-factor=$lr10_factor;set-learning-rate-factor name=tdnnf11 learning-rate-factor=$lr11_factor ;set-learning-rate-factor name=tdnnf12 learning-rate-factor=$lr12_factor;set-learning-rate-factor name=tdnnf13 learning-rate-factor=$lr13_factor;set-learning-rate-factor name=prefinal-l learning-rate-factor=$lr14_factor;set-learning-rate-factor name=prefinal-chain learning-rate-factor=$lr14_factor ;set-learning-rate-factor name=prefinal-xent learning-rate-factor=$lr14_factor;set-learning-rate-factor name=output learning-rate-factor=$lr15_factor; set-learning-rate-factor name=output-xent learning-rate-factor=$lr15_factor" \
      $src_mdl $dir/input.raw || exit 1;
fi

echo $adapt
#exit 0
if [ $stage -le 6 ]; then
  echo "Not doing this, seems to weigh the adapt and train data phone LMs if trees of train and adapt model are different and creates a new one; no need for my case; $0: compute {den,normalization}.fst using weighted phone LM."
 # steps/nnet3/chain/make_weighted_den_fst.sh --cmd "$train_cmd" \
 #   --num-repeats $phone_lm_scales \
 #   --lm-opts '--num-extra-lm-states=200' \
 #   $src_tree_dir $lat_dir $dir || exit 1;
fi

if [ $stage -le 7 ]; then
  if [[ $(hostname -f) == *.clsp.jhu.edu ]] && [ ! -d $dir/egs/storage ]; then
    utils/create_split_dir.pl \
     /export/b0{3,4,5,6}/$USER/kaldi-data/egs/rm-$(date +'%m_%d_%H_%M')/s5/$dir/egs/storage $dir/egs/storage
  fi
  # exclude phone_LM and den.fst generation training stage
  if [ $train_stage -lt -4 ]; then train_stage=-4 ; fi

  ivector_dir=
  if $use_ivector; then ivector_dir="${exp_fold}/nnet2${nnet_affix}/ivectors_adapt" ; fi

  # we use chain model from source to generate lats for target and the
  # tolerance used in chain egs generation using this lats should be 1 or 2 which is
  # (source_egs_tolerance/frame_subsampling_factor)
  # source_egs_tolerance = 5

 # %%%%%%% For tree_dir argument no denominator fst part from stage 0 in this script is done so just passing lat_dir, default: $src_tree_dir if new tree is built #### 
  chain_opts=(--chain.alignment-subsampling-factor=1 --chain.left-tolerance=1 --chain.right-tolerance=1)
  steps/nnet3/chain/train.py --stage $train_stage ${chain_opts[@]} \
    --cmd "$decode_cmd" \
    --trainer.input-model $dir/input.raw \
    --feat.online-ivector-dir "$ivector_dir" \
    --feat.cmvn-opts "--norm-means=false --norm-vars=false" \
    --chain.xent-regularize 0.000001 \
    --chain.leaky-hmm-coefficient 0.001 \
    --chain.l2-regularize 0.000001 \
    --chain.apply-deriv-weights false \
    --egs.dir "$common_egs_dir" \
    --egs.opts "--frames-overlap-per-eg 0" \
    --egs.chunk-width 100 \
    --trainer.num-chunk-per-minibatch=64 \
    --trainer.frames-per-iter 1000000 \
    --trainer.num-epochs 6 \
    --trainer.optimization.num-jobs-initial=1 \
    --trainer.optimization.num-jobs-final=1 \
    --trainer.optimization.initial-effective-lrate=0.00005 \
    --trainer.optimization.final-effective-lrate=0.000005 \
    --trainer.max-param-change 2.0 \
    --cleanup.remove-egs true \
    --feat-dir data/${adapt}_hires \
    --tree-dir $lat_dir \
    --lat-dir $lat_dir \
    --dir $dir || exit 1;
echo "Done"
fi
echo "Do decoding with decode_run script, for consistency"
exit 0
