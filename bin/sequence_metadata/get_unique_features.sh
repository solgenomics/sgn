#! /usr/bin/env bash

# This script will return a line-separated list of unique features in the provided gff3 file, by
# getting the unique values from the first column.

# Usage: ./get_unique_features.sh <infile>

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <infile>"
    exit 1
fi

awk -F $'\t' '{print $1}' "$1" | sort | uniq
