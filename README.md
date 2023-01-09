# GMM-HMM and TDNN training procedure Repository

In Kaldi all projects are present inside the egs directory from Kaldi root directory. An example is shown in the [figure](#fold_structure) below 

![fold_structure](https://user-images.githubusercontent.com/18468722/210463980-5cea2acf-b585-44f5-8647-9ff846fca5b4.png) <br>
Ref: https://www.eleanorchodroff.com/tutorial/kaldi/familiarization.html

The explanation used in this is mainly dervied from the references given below. First let's go through the _wsj_ folder structure and then create an example directory of our own.
## Data Preparation

### WSJ directory structure
In _wsj_ directory we see other directory _s5_(different versions) where actual files reside. <br>
* _utils_,  _steps_ and _local_ directories contain the necessary files for further processing. <br>
* _exp_ directory contain all the model parameters be it GMM or TDNN model. It will have the acoustic model. <br>
* _conf_ directory contain config files that indicate any parameters that are to be set like sampling frequency of audios, beam and lattice beam widths etc. <br>
* _data_ directory contain all the input data that is needed for training, validation and testing. In ASR as input we need audios, transcripts, words and their phonetic representation, nonsilence phones, silence phones etc. These files are to be created by the user. <br> 

Inside _data_ directory we have _train_, _lang_ and _dict_ directories. <br> 
* In _train_ sub-directory four files are needed to be created fundamentally. _wav.scp_, _text_, _utt2spk_ and _spk2utt_.  Further details of these files can be found in [here][data_kaldi] and [here][eleanor_data]. <br> 
* In _dict_(mentioned here as local/lang ) sub-directory we need files that are mentioned in detail [here][lang_data_kaldi] and [here][eleanor_dict] <br>

### Creating custom directory
![custom_folder](https://user-images.githubusercontent.com/18468722/210492141-4b354189-ddc4-44f1-847b-bcfd16ba3631.png) <br>
As the directories utils and steps are common to may projects we can simply create a symbolic link as shown [here][eleanor_symlink]



After creating train(and correspondingly validation and test) and dictionary directories. We will create _L.fst_. For that we need an OOV entry which is used for any word that is not present in the lexicon. That OOV symbol is needed to be present in lexicon as a word. Follow the commands [here][eleanor_lang] to create the _lang_ directory where L.fst is created. This will be used later. L.fst is nothing but the pronunciation model for the corpus. After we create a lanugage model in following steps a G.fst file will be created in this location. <br>

After this we proceed to compute features from the audios. Config files are set as shown [here][eleanor_conf]. In the _config.ini_ file a variable(mfcc_conf) is present. This variable has path to mfcc config file

At this stage train folder, dictionary folder and pronunciation model have been prepared. In the Hybrid ASR system an HCLG graph is obtained from four components Acoustic Model(H), Context Transducer(C), Pronunciation Model(L) and Language Model(G). All these components are individually obtained and then a decoding graph is constructed. Pronunciation Model(L) is already obtained. Now we will look at Acoustic Model(H) Training.
## GMM-HMM Training
Starting with monophone training steps are mentioned [here][eleanor_mono]. 
Next we move to triphone training using the alignment obtained from monophone training.
There are three levels of triphone training and parameters for each are given in config.ini file
After each level we use the decode script and get the decoded output of the trained triphone system

## TDNN Training
After gmm-hmm training we proceed to tdnn training. A brief overview is given [here][medium_kaldi_tdnn]. Training parameters can be changed under stage 16 where _train.py_ is called. The baseline training has finished. Decode any test set with this trained model. 


## References
- [https://www.eleanorchodroff.com/tutorial/kaldi/training-acoustic-models.html][eleanor]
- [http://jrmeyer.github.io/][josh_meyer]
- [https://desh2608.github.io/blog/][desh_raj]
- [https://www.superlectures.com/icassp2011/category.php?lang=en&id=131][kaldi_lectures]
- [https://medium.com/@qianhwan/understanding-kaldi-recipes-with-mini-librispeech-example-part-1-hmm-models-472a7f4a0488][medium_kaldi_gmm]
- [https://medium.com/@qianhwan/understanding-kaldi-recipes-with-mini-librispeech-example-part-2-dnn-models-d1b851a56c49][medium_kaldi_tdnn]

[josh_meyer]: http://jrmeyer.github.io/
[desh_raj]: https://desh2608.github.io/blog/
[eleanor]: https://www.eleanorchodroff.com/tutorial/kaldi/training-acoustic-models.html
[kaldi_lectures]: https://www.superlectures.com/icassp2011/category.php?lang=en&id=131
[medium_kaldi_gmm]: https://medium.com/@qianhwan/understanding-kaldi-recipes-with-mini-librispeech-example-part-1-hmm-models-472a7f4a0488
[medium_kaldi_tdnn]: https://medium.com/@qianhwan/understanding-kaldi-recipes-with-mini-librispeech-example-part-2-dnn-models-d1b851a56c49

[data_kaldi]: https://kaldi-asr.org/doc/kaldi_for_dummies.html#:~:text=for%20each%20speaker.-,Acoustic%20data,-Now%20you%20have
[lang_data_kaldi]: https://kaldi-asr.org/doc/kaldi_for_dummies.html#:~:text=and%20so%20on...-,Language%20data,-This%20section%20relates
[eleanor_data]: https://www.eleanorchodroff.com/tutorial/kaldi/training-acoustic-models.html#create-files-for-datatrain:~:text=5.2-,Create%20files%20for%20data/train,-The%20files%20in
[eleanor_dict]: https://www.eleanorchodroff.com/tutorial/kaldi/training-acoustic-models.html#create-files-for-datalocallang:~:text=5.3-,Create%20files%20for%20data/local/lang,-data/local/lang
[eleanor_lang]: https://www.eleanorchodroff.com/tutorial/kaldi/training-acoustic-models.html#create-files-for-datalang:~:text=5.4-,Create%20files%20for%20data/lang,-Now%20that%20we
[eleanor_conf]: https://www.eleanorchodroff.com/tutorial/kaldi/training-acoustic-models.html#create-files-for-datalang:~:text=5.6-,Create%20files%20for%20conf,-The%20directory%20conf
[eleanor_symlink]: https://www.eleanorchodroff.com/tutorial/kaldi/training-acoustic-models.html#create-files-for-datalang:~:text=cd%20mycorpus%0Aln%20%2Ds%20../wsj/s5/steps%20.%0Aln%20%2Ds%20../wsj/s5/utils%20.%0Aln%20%2Ds%20../../src%20.%0A%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%0Acp%20../wsj/s5/path.sh%20.
[eleanor_mono]: https://www.eleanorchodroff.com/tutorial/kaldi/training-acoustic-models.html#monophone-training-and-alignment:~:text=5.8-,Monophone%20training%20and%20alignment,-Take%20subset%20of
