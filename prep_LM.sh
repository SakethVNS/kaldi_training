#!/bin/bash

stage=0
cmd=run.pl
nj=8
lm_order=3
GM_path=""
use_transcripts=0

. ./cmd.sh
[ -f ./path.sh ] && . ./path.sh;
. ./config_retrain_2.ini
. utils/parse_options.sh || exit 1;

<<com
Variables in config_retrain.ini:
  gwt
  canonical_story_folder
  storyname
  paragraph_id
  lm_order
  exp_folder
  aser=/media/run/kaldi/egs/iitm_baseline/English_ASR_Challenge/asr/test_valid_splits/ASER_Hindi_models
  garb_model_dir
  garb_model_words
  garb_model_sil
  CreateCTM
  test_set(valid set included)
  valid_set
  test_set_only
  GM_path
  transcripts_use

com

if [[ $# -ne 2 && $# -ne 3 ]]; then
  echo "Usage: $0 <dict-dir> <lang-dir> <data-dir>"
  echo dict directory: Directory containing lexicon.txt, non_silence_phones.txt, silence_phones.txt, optional_silence.txt
  echo lang directory: Directory in which another directory is created with lang_storyname
  echo data directory: Directory containing text file corresponding to training experiments
  exit 1;
fi

dict_dir=$1
lang_dir=$2
if [ $# -eq 3 ];then
data_dir=$3
canonical_story_folder=$3
fi
form_GM=0

if [ $stage -le 1 ];then
    echo "========================================="
    echo "Stage 1: Pronunciation Model creation"
    echo "========================================="
    
    # If check needed for redundant L.fst computation edit here

    echo "Using $dict_dir to create lang_$storyname"
    echo "Creating a lang directory with name: lang_$storyname"
    
    
    rm -f $dict_dir/lexiconp.txt

    sed -i '/^[[:space:]]*$/d' ${dict_dir}/lexicon.txt
    gawk -i inplace 'NF > 1' ${dict_dir}/lexicon.txt
    sort -u -o ${dict_dir}/lexicon.txt ${dict_dir}/lexicon.txt

    #utils/prepare_lang.sh --sil-prob 0.4 --phone-symbol-table data/lang_eng_wpp_one_sil/phones.txt $dict_dir "!SIL" $dict_dir/tmp ${lang_dir}/lang_$storyname || exit 1
    utils/prepare_lang.sh --sil-prob 0.4 $dict_dir "!SIL" $dict_dir/tmp ${lang_dir}/lang_$storyname || exit 1
    rm -rf $dict_dir/tmp
    echo -e "\n****Created lang directory $lang_dir/lang_$storyname using $dict_dir****\n"
fi
#exit 0
if [ $stage -le 2 ];then
    echo "========================================="
    echo "Stage 2: Language Model creation"
    echo "========================================="
    
    #This creates a temp.txt file inside lang_directory that contains canonical text with removed special characters and appended <s> and </s>
    #python3 create_LM_saketh.py $canonical_story_folder $lang_dir $storyname
    python3 create_LM_GM_saketh.py --lm_or_gm lm --order $lm_order ${lang_dir}/lang_$storyname/ $canonical_story_folder
    echo "LM creation with order = $lm_order"
    if [ $lm_order -eq 0 ];then
        lm_order=1
    fi
    build-lm.sh -i ${lang_dir}/lang_$storyname/temp_lm.txt -n $lm_order -s improved-kneser-ney -o ${lang_dir}/lang_$storyname/lm_phone_bg.ilm.gz
    compile-lm ${lang_dir}/lang_$storyname/lm_phone_bg.ilm.gz -t=yes /dev/stdout | grep -v unk > ${lang_dir}/lang_$storyname/lm_phone_bg.arpa
    python convert_lm_to_fst.py ${lang_dir}/lang_$storyname/lm_phone_bg.arpa | sed 's/<s>/SIL/g' |sed 's/<\/s>/SIL/g' > ${lang_dir}/lang_$storyname/G.txt
    echo "LM created using canonical story folder $canonical_story_folder"
    echo " ### Building GM = $form_GM  ##### "
    
    if [[ $form_GM == 1 ]];then
    echo "Building Garbage Model"
    #python3 create_GM_saketh.py $data_dir/text $lang_dir $storyname $gm_order
    python3 change_G.py 0.4 ${lang_dir}/lang_$storyname/ $GM_path
    #python3 create_LM_GM_saketh.py --lm_or_gm gm --order $gm_order --use_transcripts=$use_transcripts ${lang_dir}/lang_$storyname/ $GM_path || exit 1
    #echo "Creating Garbage Model using Transcripts in $data_dir"
    #build-lm.sh -i ${lang_dir}/lang_$storyname/temp_gm.txt -n 1 -o ${lang_dir}/lang_$storyname/gm_phone_bg.ilm.gz
    #compile-lm ${lang_dir}/lang_$storyname/gm_phone_bg.ilm.gz -t=yes /dev/stdout | grep -v unk > ${lang_dir}/lang_$storyname/gm_phone_bg.arpa
    #python convert_lm_to_fst.py ${lang_dir}/lang_$storyname/gm_phone_bg.arpa | sed 's/<s>/SIL/g' |sed 's/<\/s>/SIL/g' > ${lang_dir}/lang_$storyname/G_GM.txt
    

    sed -i '1d' ${lang_dir}/lang_$storyname/G_GM.txt
    #sed -i '$ d' ${lang_dir}/lang_$storyname/G_GM.txt
    cp ${lang_dir}/lang_$storyname/G.txt ${lang_dir}/lang_$storyname/G_LM.txt
    cat ${lang_dir}/lang_$storyname/G_GM.txt >> ${lang_dir}/lang_$storyname/G.txt
    else
    echo "Not building Garbage Model"
    fi
    rm -f ${lang_dir}/lang_$storyname/*.gz
    
    fstcompile --isymbols=${lang_dir}/lang_$storyname/words.txt --osymbols=${lang_dir}/lang_$storyname/words.txt ${lang_dir}/lang_$storyname/G.txt | fstarcsort --sort_type=ilabel > ${lang_dir}/lang_$storyname/G.fst
    mkdir -p ${lang_dir}/lang_$storyname/log/
    echo "****Validating Language Model directory****"
    #utils/validate_lang.pl ${lang_dir}/lang_$storyname/ > ${lang_dir}/lang_$storyname/log/validate_lang.log || exit 1





fi
    
exit 1


