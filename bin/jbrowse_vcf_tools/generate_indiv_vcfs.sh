#!/bin/bash                                                                                                                                                                                                 
#-------------------------------------------------------------------------------------------------------------------------------                                                                            
# NAME   
#
# generate_indiv_vcfs.sh 
# 
# SYNOPSIS
# Shell script for creating multiple versions of individual VCF files from a single multivcf and imputed dosage file.
# 
# ./generate_indiv_vcfs.sh -v [multivcf file] -d [dosage file] 
#
# To run, this script requires create_indiv.pl
#                      finish_indiv.pl
#-------------------------------------------------------------------------------------------------------------------------------


#--------------------------------------------------------------------------------
# 1 Parse command line arguments:
#-------------------------------------------------------------------------------

while [[ $# > 1 ]]
do
key="$1"

case $key in
    -v|--multi.vcf)
    MULTI_VCF="$2"
    shift
    ;;
    -d|--dosage)
    DOSAGE="$2"
    ;;
esac
shift
done
echo MULTI_VCF  = "$MULTI_VCF"
echo DOSAGE  = "$DOSAGE"
if [ -z "$MULTI_VCF" ] || [ -z "$DOSAGE" ]
then
    echo "Trouble reading command line arguments, make sure
    -v [multi vcf file] and
    -d [dosage file] are both specified";
    exit
fi


#----------------------------------------------------------------------------------
# 2 create a nearly empty vcf file for each accession in the multi-vcf
#----------------------------------------------------------------------------------

echo Creating starter vcf files...

mkdir output

./create_indiv.pl -v $MULTI_VCF -o output   

#--------------------------------------------------------------------------------
# 3 add genotype data to complete indiv vcf files. then generate filt and imputed files too.  Requires long operations, so do it in parallel to speed it up
#-------------------------------------------------------------------------------

ls output/* | parallel -j 30 --gnu --verbose "./finish_indiv.pl -v $MULTI_VCF -d $DOSAGE -f {}"
 

