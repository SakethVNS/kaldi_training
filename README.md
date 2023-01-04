# GMM-HMM and TDNN training procedure Repository

In Kaldi all projects are present inside the egs directory from Kaldi root directory. An example is shown in the [figure](#fold_structure) below 

![fold_structure](https://user-images.githubusercontent.com/18468722/210463980-5cea2acf-b585-44f5-8647-9ff846fca5b4.png)
Ref: https://www.eleanorchodroff.com/tutorial/kaldi/familiarization.html

Go through this website https://kaldi-asr.org/doc/kaldi_for_dummies.html for initial understanding of file structure used in kaldi

In Kaldi Operations are executed in stage wise manner. Before proceeding to training we have to prepare four files(utt2spk, spk2utt, text, wav.scp). 
Details of these files are mentioned in the link above
Next we need dictionary files that contain lexicon, silence and non silence phones
After creating data directory and dictionary directory we can proceed to create language model using dictionary.

