import sys
import numpy as np
import pdb
import glob
import os
a = sys.argv[1]
lang_dir = sys.argv[2]
#garbageModelTxtFile='test_garb.txt'
fpath=sys.argv[3]
print(fpath)
if os.path.isdir(fpath):
    #print(glob.glob(lang_dir+sys.argv[3]+'*.txt')[0])
    print(glob.glob(sys.argv[3]+'*.txt'))
    garbageModelTxtFile=glob.glob(sys.argv[3]+'*.txt')
else:
    garbageModelTxtFile=[fpath]

# a = [xx.strip().split(' ')[4] for xx in open('data/lang_combined/G.txt') if len(xx.strip().split(' '))==5 and xx.strip().split(' ')[3]=='<unk>']
uniq_words=[]
for gfile in garbageModelTxtFile:
    uniq_words += [xx.strip() for xx in open(gfile)]
    print("Length of unique words in garbage model file",gfile,len(uniq_words))
uniq_words = list(set(uniq_words))
#pdb.set_trace()
a=float(a)
if a!=0.0:
	if a==1.0 and len(uniq_words)>0:
		print("Weight =1.0!!!!!!!!!, taking as 0.99")
		a=0.99
		a=str(np.log10((1-a)*len(uniq_words)/a))
	elif len(uniq_words)==0:
		a=str(0)
	else:
        	a=str(np.log10((1-a)*len(uniq_words)/a))
	#a=str(a)
	#G = [xx.strip() for xx in open(lang_dir+'G.txt')]
	fid = open(lang_dir+'G_GM.txt','w')
	#fid.write('\n'.join(G))
	for word in uniq_words:
		fid.write('\n3 3 '+word+' '+word+' '+a)
	fid.close()
