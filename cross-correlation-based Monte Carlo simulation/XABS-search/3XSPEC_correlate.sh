#!/bin/bash
export OMP_NUM_THREADS=4
mkdir ${PWD}/simulation
DIR_home=${PWD}/simulation
mkdir ${DIR_home}/MC_spectrum
mkdir ${DIR_home}/model
mkdir ${DIR_home}/res
MC_spectrum=${DIR_home}/MC_spectrum
model_dir=${DIR_home}/model
res_spectrum=${DIR_home}/res

num_simulations=10000
max_item=`echo "${number}-1" | bc`

xi_min=0.0
xi_max=5.0
xi_step=0.1
zv_min=0
zv_max=105000
linewidth=(500 1500 100)
vstep_list=(500 700 300)

#logNH_min=19.0 ### cm^-2
#logNH_max=23.0
#logNH_step=1.0

N_cpu=12
#min_energy=0.4
#max_energy=1.77

xspec_startup_xcm=${PWD}/nthcomp+relxillCp.xcm #change the localtion of data into global location not e.g. ../../analysis
#xspec_startup_xcm=${PWD}/ism_WA_relxilllpCp+diskbb+3gaussian_2021.xcm  #change the localtion of data into global location not e.g. ../../analysis
################save real residual spectrum
#linewidth=(500 1500)
for a in 2
do
echo "linewidth: ${linewidth[$a]} km/s"

python3<<EOF
import numpy as np
import pandas as pd
import time
import itertools
import math
import multiprocessing as mp
def where_is_str(array,string="NO"):
	index=np.where(array== string)
	seen=set()
	dupes=[x for x in index[0] if x in seen or seen.add(x)]
	return dupes
def func(params):
        a=params[0]
        b=params[1]
        return np.correlate(a,b)
#dtype=[('x','float'),('errx','float'),('y','float'),('erry','float')]
infile='${DIR_home}/real_res_area.qdp'
data = np.loadtxt(infile,skiprows=3,dtype=str)
index=where_is_str(data)
data=np.delete(data,index,0)
index=where_is_str(data,string="0")
data=np.delete(data,index,0)
data=data.astype(np.float64)
x=data[:,0];errx=data[:,1];y=data[:,2];erry=data[:,3]
y=y/erry**2
y=np.nan_to_num(y)
y_RGS=y[:600]
std_RGS=np.std(y_RGS)
print("standard deviation: ",std_RGS)


inmodel='${DIR_home}/merge_model_lw'+str(${linewidth[$a]})+'.txt'
df=pd.read_csv(inmodel,header=None,delimiter=' ')
num_model=len(df.columns)-1
correlate=[]
for i in range(num_model):
	#y_model=np.array(df[i+1])
	y_model=np.array(df[i+1][:600])
	#if i==0:
		#print(y,y_model)
	
	cor=np.correlate(y_RGS,y_model)
	#cor=np.correlate(y,y_model*std_RGS)
	correlate.extend(cor)
#print(len(correlate),correlate)
#en=np.logspace(np.log10(${min_energy}),np.log10(${max_energy}),num=num_model)

xi=[];zv=[]
#for k in np.arange(${logNH_min}, ${logNH_max}+0.01, ${logNH_step}):
for i in np.arange(${xi_min}, ${xi_max}+0.01,${xi_step}):
	for j in np.arange(${zv_min},${zv_max}+1,${vstep_list[$a]}):
		xi.extend([i]);zv.extend([j*-1])
np.savetxt('${DIR_home}/'+'raw_correlate_real_lw'+str(${linewidth[$a]})+'.txt',np.column_stack([ np.array(xi), np.array(zv), np.array(correlate)]))
#print('mean CC of real:', np.mean(correlate))

sim_res_file='${DIR_home}/merge_res_'+str(${num_simulations})+'_area.txt'
df_sim=pd.read_csv(sim_res_file,header=None,delimiter=' ')
paramlist=list(itertools.product(np.array(df_sim.iloc[:600,1:]).T,np.array(df.iloc[:600,1:]).T))


print('start to parallel')
star=time.time()
pool=mp.Pool(${N_cpu})
correlate_sim=pool.map(func,paramlist)
end=time.time()
print('{:.4f} s'.format(end-star))
print(np.array(correlate_sim).reshape($num_simulations,num_model).shape)
correlate_stack=np.array(correlate_sim).reshape($num_simulations,num_model)
np.savetxt('${DIR_home}/'+'raw_correlate_sim_lw'+str(${linewidth[$a]})+'.txt',np.column_stack([np.array(xi), np.array(zv), np.array(correlate_stack).T]))

raw_file='${DIR_home}/'+'raw_correlate_sim_lw'+str(${linewidth[$a]})+'.txt'
df_raw=pd.read_csv(raw_file,header=None, delimiter=' ')
N_corr=[]
N_corr_real=[]
for i in range(num_model):
	corr=df_raw.iloc[i][3:]	
	#count_pos=np.sum([1 if c>0 else 0 for c in corr])
	#count_neg=np.sum([1 if c<0 else 0 for c in corr])
	#index_pos=[True if c>0 else False for c in corr]	
	#index_neg=[True if c<0 else False for c in corr]
	count=len(corr);corr[abs(corr)>1e100]=0;corr_mean=np.mean(corr);print(corr_mean)
	if i==0:
		np.savetxt('${DIR_home}/'+'test.txt',corr)
#	if count_pos==0:
#		norm_pos=np.infty
#	else:
	norm=np.sqrt(sum([k*k for k in corr])/count);print('norm:',norm)	
#	if count_neg==0:
#		norm_neg=np.infty
#	else:
#		norm_neg=np.sqrt(sum([k**2 for k in corr[index_neg]])/count_neg)
	n_corr=[c/norm for c in corr]
	#n_corr=ccorr
	#print(n_corr)
	N_corr.append(n_corr)
	#print(len(N_corr))
	#print(correlate,len(correlate))
	#n_corr_real=[correlate[i]/norm_pos if correlate[i]>0 else correlate[i]/norm_neg]
	n_corr_real=correlate[i]/norm
	N_corr_real.append(n_corr_real)
	print('calculate the normalized significance of the '+str(i)+'th model point')

np.savetxt('${DIR_home}/'+'norm_correlate_sim_lw'+str(${linewidth[$a]})+'.txt',np.column_stack([ np.array(xi), np.array(zv),np.array(N_corr)]))
np.savetxt('${DIR_home}/'+'norm_correlate_real_lw'+str(${linewidth[$a]})+'.txt',np.column_stack([ np.array(xi), np.array(zv),np.array(N_corr_real)]))
#np.savetxt('${DIR_home}/'+'norm_correlate_sim_lw'+str(${linewidth[$a]})+'.txt',np.column_stack([np.array(nh), np.array(xi), np.array(zv),np.array(correlate_stack).T]))
#np.savetxt('${DIR_home}/'+'norm_correlate_real_lw'+str(${linewidth[$a]})+'.txt',np.column_stack([np.array(nh), np.array(xi), np.array(zv),np.array(correlate)]))

EOF
#cp ${DIR_home}/raw_correlate_sim_lw${linewidth[$a]}.txt ${DIR_home}/norm_correlate_sim_lw${linewidth[$a]}.txt 
#cp ${DIR_home}/raw_correlate_real_lw${linewidth[$a]}.txt ${DIR_home}/norm_correlate_real_lw${linewidth[$a]}.txt 
#cp '${DIR_home}/'+'raw_correlate_real_lw'+str(${linewidth[$a]})+'.txt' '${DIR_home}/'+'norm_correlate_real_lw'+str(${linewidth[$a]})+'.txt' 

done
echo "done"
