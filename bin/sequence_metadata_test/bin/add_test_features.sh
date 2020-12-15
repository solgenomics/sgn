#! /usr/bin/env bash

#
# This script adds 21 chromosomes as features to the database (chr1A-chr7D)
# Usage: add_test_features.sh -h db_host -d db_name -U db_user -p db_pass
#

# Default Argument Values
db_host="localhost"
db_name="cxgn_triticum"
db_user="postgres"
remove=0
organism_genus="Triticum"
organism_species="aestivum"
type_name="chromosome"
type_cv="sequence"

# Parse CLI arguments
while getopts ":h:d:u:p:" opt; do
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
    esac
done

# Define chromosomes
chromosomes=("chr1A" "chr1B" "chr1D" "chr2A" "chr2B" "chr2D" "chr3A" "chr3B" "chr3D" "chr4A" "chr4B" "chr4D" "chr5A" "chr5B" "chr5D" "chr6A" "chr6B" "chr6D" "chr7A" "chr7B" "chr7D")

# Get organism and type ids
sql="SELECT organism_id FROM public.organism WHERE genus='$organism_genus' AND species='$organism_species';"
organism_id=$(psql -h $db_host -d $db_name -U $db_user -XAtc "$sql")
sql="SELECT cvterm_id FROM cvterm WHERE cv_id = (SELECT cv_id FROM cv WHERE name = '$type_cv') AND name = '$type_name';"
type_id=$(psql -h $db_host -d $db_name -U $db_user -XAtc "$sql")

# Add the chromosomes as features
sql="INSERT INTO public.feature (organism_id, name, uniquename, type_id, is_obsolete) VALUES "
for chr in "${chromosomes[@]}"; do
    sql+="($organism_id, '$chr', '$chr', $type_id, 'f'), "
done
sql=$(echo "$sql" | sed 's/\(.*\),.*/\1/')
sql+=";"
psql -h $db_host -d $db_name -U $db_user -c "$sql"
