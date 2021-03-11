#! /usr/bin/env bash

# This script will return a line-separated list of unique attribute keys in the last column 
# of the provided gff3 file

# Usage ./get_unique_attributes.sh <infile>

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <infile>"
    exit 1
fi

attributes=$(awk -F $'\t' '{print $9}' "$1")
keys=$(echo "$attributes" | grep -o "\([^=;]\+\)=" | cut -d '=' -f 1)
echo "$keys" | sort | uniq