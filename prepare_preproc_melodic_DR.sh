#HP filters de-spiked, MNI normalised, 6mm smoothed EPI images (but not touched otherwise) 
#from the preprocessing pipeline and runs ICA decomp.
#Why? Assuming the preprocessing pipeline is naffed (unlikely), 
#this gives data in it's "purest" form to troubleshoot with. 

hdir=/home/peter/Desktop/prepare/rest/output/
holddir=/home/peter/Desktop/melodic/prepare/subj_hold/
outdir=/home/peter/Desktop/melodic/prepare/


#Select only baseline files (note - the -v in grep inverts the pattern search), writes to file 
find $hdir/*/preproc_epis -name 'sraepi*.nii' | grep -v 12months > $outdir'baseline_subs_test.txt' 
#find $hdir/*/preproc_epis -name 'sbp*_global*.nii' | grep -v 12months > ~/Desktop/melodic/prepare/baseline_subs.txt


subj_files=$(cat $outdir'baseline_subs_test.txt')

for subj in $subj_files;
    do subj_path=`dirname $subj`
    subj_id=${subj_path/$hdir'/'/''} #Remove $hdir path retaining subj id
    subj_id=${subj_id%/*}  #Retain subj_id, dump preproc path.
    
    echo $subj_id

    #Extract temporal mean (Tmean) image.
    fslmaths $subj -Tmean $holddir'/tempmean.nii.gz'

    #Filter (16.66...7 = hp in volumes, -1 = no LP), re-add mean
    fslmaths $subj -bptf 16.666666667 -1 -add $holddir'/tempmean.nii.gz' $holddir/$subj_id'_epi_hpfilt.nii'
    
    #Remove temporal mean file.
    rm $holddir'/tempmean.nii.gz'

done

find $holddir -name *hpfilt* | sort > $holddir/subj_files.txt

#Run melodic using a tensor ICA approach (instead of a space x time decomposition, data is decomposed into
#space x time x subject matricies that allow for modellling of between subject variance. 
melodic -i $holddir/subj_files.txt -o $outdir'baseline' -v --nobet --bgthreshold=1 --tr=3.000 --report --mmthresh=0.5 --Ostats --approach=concat --dim=20

#Run FSLview to select components for removal
fslview -m ortho $FSLDIR/data/standard/MNI152_T1_3mm_brain.nii.gz $outdir'baseline/melodic_IC.nii.gz' -l 'Hot' -b 1.9,10 &
 
#Remove artifactual data from ICA
mkdir $outdir'baseline/split/'
fslsplit $outdir'baseline/melodic_IC.nii.gz' $outdir'baseline/split/'

echo -e '\nPlease enter artifactual components (starting from 0), with a space between each component number.\n'

read rem_comps

for x in $rem_comps; 
    do echo 'Remvoing component ' $x 
    if [ "$x" -gt "9" ] 
    then 
        rm -f $outdir'baseline/split/00'$x'.nii.gz'
    else
        rm -f $outdir'baseline/split/000'$x'.nii.gz'
    fi
done

comp_files=$(ls $outdir'baseline/split/'*.nii.gz)

fslmerge -a $outdir'baseline/clean_ica.nii' $comp_files

rm -f -R $outdir'baseline/split/'

#Running dual regression

echo -e '\n***RUNNING DUAL REGRESSION***\n'
infiles=$(cat $holddir/subj_files.txt | sort)

#Run dual_regression to get images
dual_regression_thr $outdir'baseline/clean_ica.nii' 1 $outdir'dm/prepare_madrs.mat' $outdir'dm/prepare_madrs.con' 5000 $outdir'DR' $infiles
#dual_regression_thr_mask $outdir'baseline/0001.nii.gz' 1 $outdir'dm/prepare_madrs.mat' $outdir'dm/prepare_madrs.con' 5000 $outdir'DR' $infiles
#Note: The ...thr_mask version specifies the mask to use rather than use a whole brain mask.

#Run randomise (more control over masking)
dr_infiles=$(find $outdir'DR' -name '*stage2*Z.nii.gz' | sort)
fslmerge -a $outdir'baseline/dr_files.nii.gz' $dr_infiles

#randomise -i $outdir'baseline/dr_files.nii.gz' -o $outdir'randomise/' -m '/home/peter/Desktop/melodic/prepare/baseline/smn_mask.nii' -d $outdir'dm/prepare_madrs_split.mat' -t $outdir'dm/prepare_madrs_split.con' -T -n 5000

randomise -i $outdir'baseline/dr_files.nii.gz' -o $outdir'randomise/' -d $outdir'dm/prepare_madrs_split.mat' -t $outdir'dm/prepare_madrs_split.con' -T -n 5000



