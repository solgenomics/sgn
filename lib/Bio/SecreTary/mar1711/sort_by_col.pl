#!/usr/bin/perl -w
use strict;

my $col = shift;

my @lines = ();
while(<>){
push @lines, $_;
}

my @sorted_lines = sort {
my @cols_a = split(" ", $a);
my @cols_b = split(" ", $b);
return ($cols_a[$col] <=> $cols_b[$col]);
} @lines;
 

foreach (@sorted_lines){
print $_;
}

