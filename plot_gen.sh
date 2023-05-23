
if [ $# -ne 1  ]; then
    echo "Usage: $0 [exp_folder_path] "
    exit 1
fi

exp_fold=$1/chain/tdnn

if [ ! -d $exp_fold ]; then
    echo "Given path doesn't exist"
    exit 1
fi


cat run_finetune_tdnn.sh | grep "\-\-chain.xent-regularize"
cat run_finetune_tdnn.sh | grep "\-\-egs.chunk"
cat run_finetune_tdnn.sh | grep "\-\-trainer.num-epochs"
cat run_finetune_tdnn.sh | grep "\-\-trainer.optimization.initial-effective-lrate"
cat run_finetune_tdnn.sh | grep "\-\-trainer.optimization.final-effective-lrate"


if [ -d "$exp_fold/log/plots/" ]; then
    echo "Directory $exp_fold/log/plots/ exists"
    read -p "Do you want to delete it [y]/n: " i
    i=${i:-y}
    echo "$i"
    if [ $i == 'y' ];then
        rm -r $exp_fold/log/plots/
        echo "$exp_fold/log/plots/ is deleted"
    else
        echo "Try new folder path"
        exit 1
    fi
fi
mkdir -p $exp_fold/log/plots/

echo "$exp_fold/log/plots/ created"
python3 steps/nnet3/report/generate_plots.py --is-chain true $exp_fold $exp_fold/log/plots/
echo -e "\n --------------Plots saved to $exp_fold/log/plots/ --------------------"

