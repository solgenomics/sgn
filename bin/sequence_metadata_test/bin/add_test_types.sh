#! /usr/bin/env bash

#
# This script adds n test featureprop_json types to the database with the name
# 'feature_test_type_n' 
# Usage: add_test_types.sh -d db_host -d db_name -U db_user -p db_pass -n count
#

# Default Argument Values
db_host="localhost"
db_name="cxgn_triticum"
db_user="postgres"
count=5

# Parse CLI arguments
while getopts ":h:d:u:p:n:" opt; do
    case ${opt} in
        h)
            db_host=$OPTARG
            ;;
        d) 
            db_name=$OPTARG
            ;;
        U)
            db_user=$OPTARG
            ;;
        p)
            export PGPASSWORD="$OPTARG"
            ;;
        n)
            count=$OPTARG
            ;;
    esac
done

# Define type names
type_name="feature_test_type"
cv_name="genotype_property"

# Parse each type and add to the database
n=1
while [[ $n -le $count ]]; do 
    cvterm_name="$type_name"_$n
    sql="INSERT INTO public.dbxref (db_id, accession) SELECT db_id, '$cvterm_name' FROM public.db WHERE name = 'null'; "
    sql+="INSERT INTO public.cvterm (cv_id, name, dbxref_id) SELECT cv.cv_id, '$cvterm_name', dbxref.dbxref_id FROM public.cv JOIN public.dbxref ON (1=1) WHERE cv.name = '$cv_name' AND dbxref.accession = '$cvterm_name' LIMIT 1;"
    psql -h $db_host -d $db_name -U $db_user -c "$sql"
    n=$((n+1))
done
