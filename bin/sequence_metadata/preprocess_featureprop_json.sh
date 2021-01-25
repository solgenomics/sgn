#! /usr/bin/env bash

# This shell script is called by the verify_featureprop_json.pl script and 
# is used to preprocess the gff3 file for the featureprop_json table.  It will:
# 1) remove comment lines from the file
# 2) sort the gff3 file by the seqid and start columns (1, 4)

# Usage: ./process_featurprop_json.sh <infile> <outfile>

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <infile> <outfile>"
    exit 1
fi

grep -o '^[^#]*' "$1" | sort -t$'\t' -k1,1 -k4n,4 > "$2"
