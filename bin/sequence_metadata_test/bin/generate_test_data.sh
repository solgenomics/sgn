#! /usr/bin/env bash

#
# This script duplicates the chr1D mnase data to the 20 other chromosomes
# Usage: generate_test_data.sh -i mnase-chr1D.txt -o mnase-dummy.txt
#

# Default Argument Values
input="/home/production/cxgn/sgn/bin/sequence_metadata_test/data/mnase-chr1D.txt"
output="/home/production/cxgn/sgn/bin/sequence_metadata_test/data/mnase-dummy.txt"
input_chr="chr1D"

# Parse CLI arguments
while getopts ":i:o:" opt; do
    case ${opt} in
        i)
            input=$OPTARG
            ;;
        o) 
            output=$OPTARG
            ;;
    esac
done

# Define chromosomes
chromosomes=("chr1A" "chr1B" "chr1D" "chr2A" "chr2B" "chr2D" "chr3A" "chr3B" "chr3D" "chr4A" "chr4B" "chr4D" "chr5A" "chr5B" "chr5D" "chr6A" "chr6B" "chr6D" "chr7A" "chr7B" "chr7D")

# Parse each chromosome and add to output file
echo "" > "$output"
for chr in "${chromosomes[@]}"; do
    echo "Writing $chr..."
    sed "s/$input_chr/$chr/g" "$input" >> "$output"
done