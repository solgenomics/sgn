#! /usr/bin/env bash

#
# This script runs the sequence metadata query tests
# It adds the dummy data to the database the specified number of times (counts) 
#   using the specified chunk sizes (chunks)
# It will then time a query of scores on a single chromosome of a single 
#   featureprop_json type between 0 and the specifed sequence lengths (lengths, in kilobases)
# NOTE: THIS WILL DELETE EVERYTHING FROM THE FEATUREPROP_JSON TABLE BEFORE RUNNING EACH CHUNK SIZE
# 
# Usage: run_tests.sh -h db_host -d db_name -U db_user -p db_pass
#                     -l loader (path to loading script)
#                     -i input (path to input data file)
#                     -o output (path to output directory, where the csv files will be written)
#                     -n query count (number of times to perform the same query)
#                     -x counts (the number of times the input data is loaded) ("1 2 3 4 5 6 7 8 9 10")
#                     -y chunks (the number of individual scores to save per row) ("100 1000 10000 100000")
#                     -z lengths (the sequence length to query, in kilobases) ("1 100 500 1000 10000")
#

# Default Argument Values
db_host="localhost"
db_name="breedbase"
db_user="postgres"
query_count=5
counts="1 2 3 4 5 6 7 8 9 10"
chunks="100 1000 10000 100000"
lengths="1 100 500 1000 10000"
type_name="feature_test_type"
query_start_length_pos=1
query_chromosome="chr1D"
input="/home/production/cxgn/sgn/bin/sequence_metadata_test/data/mnase-dummy.txt"
output="/home/production/cxgn/sgn/bin/sequence_metadata_test/results/"
loader="/home/production/cxgn/sgn/bin/load_featureprop_json.pl"

# Parse CLI arguments
while getopts ":h:d:u:p:l:i:o:n:x:y:z:" opt; do
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
        l)
            loader="$OPTARG"
            ;;
        i) 
            input="$OPTARG"
            ;;
        o)
            output="$OPTARG"
            ;;
        n)
            query_count=$OPTARG
            ;;
        x)
            counts="$OPTARG"
            ;;
        y)
            chunks="$OPTARG"
            ;;
        z)
            lengths="$OPTARG"
            ;;
    esac
done

# Create arrays of variables
IFS=' ' read -r -a counts <<< "$counts"
IFS=' ' read -r -a chunks <<< "$chunks"
IFS=' ' read -r -a lengths <<< "$lengths"


# CSV Tables of Results
load_results="load,existing,chunk,load_time_total,load_time_avg"
query_results="count,chunk,length,results,query_time_toal,query_time_avg"


# Write headers to output files
mkdir -p "$output"
ts=$(date +"%Y%m%d-%H%M")
echo "$load_results" > "$output"/$ts-load.csv
echo "$query_results" > "$output"/$ts-query.csv


# Loop through the chunk sizes
for chunk in "${chunks[@]}"; do

    echo "==> Running tests on a chunk size of $chunk..."

    # Remove everything from the featureprop_json table
    echo "--> Cleaning out featureprop_json table"
    sql="DELETE FROM public.featureprop_json;"
    psql -h $db_host -d $db_name -U $db_user -c "$sql"
    
    # Keep track of the number of loaded datasets
    loaded=0

    # Loop through the number of datasets
    for count in "${counts[@]}"; do

        echo "==> Running tests on $count loaded datasets..."

        # Load required number of datasets
        to_load=$((count-loaded))
        existing=$loaded
        SECONDS=0
        while [ $loaded -lt $count ]; do
            echo "--> Adding data to database"
            perl "$loader" -H $db_host -D $db_name -U "$db_user" -p "$PGPASSWORD" -i "$input" -t "$type_name"_$count -c $chunk
            loaded=$((loaded+1))
        done
        load_total=$SECONDS
        load_avg=$(echo $load_total/$to_load | R --vanilla --quiet | sed -n '2s/.* //p')
        echo "$to_load,$existing,$chunk,$load_total,$load_avg" >> "$output"/$ts-load.csv

        # Loop through the sequence lengths to query
        for length in "${lengths[@]}"; do
            echo "==> Querying a sequence length of $length kb"
            
            # Set up the query
            start=$query_start_length_pos
            end=$((start+length*1000))
            chromosome=$query_chromosome
            type="$type_name"_$count
            sql="SELECT feature_json_id, feature_id, type_id, s.json->>'start' AS start, s.json->>'end' AS end, s.json->>'score' AS score
FROM featureprop_json, jsonb_array_elements(featureprop_json.json) as s
WHERE start_pos <= $start AND end_pos >= $end
AND (s.json->>'start')::int >= $start AND (s.json->>'end')::int <= $end
AND feature_id = (SELECT feature_id FROM feature WHERE uniquename = '$chromosome')
AND type_id = (SELECT cvterm_id FROM cvterm WHERE name = '$type');"

            # Run the query
            SECONDS=0
            n=1
            while [[ $n -le $query_count ]]; do
                echo "--> Performing query #$n/$query_count..."
                results=$(psql -h $db_host -d $db_name -U $db_user -XAtc "$sql")
                results_count=$(echo "$results" | wc -l)
                n=$((n+1))
            done
            query_total=$SECONDS
            query_avg=$(echo $query_total/$query_count | R --vanilla --quiet | sed -n '2s/.* //p')
            echo "$count,$chunk,$length,$results_count,$query_total,$query_avg" >> "$output"/$ts-query.csv
            
        done

    done
done
