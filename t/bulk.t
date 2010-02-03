#!/usr/bin/perl
use strict;
use warnings;

# Test script for UnigeneConverter module.
# Matthew Crumb and Alexander Naydich
# July 9th 2007

# Bulk.pm and UnigeneConverter.pm need modification for test to run properly.

use Test::More 'no_plan';
use CXGN::Bulk::UnigeneConverter;
use Data::Dumper;

my $params = {};
$params->{idType} = "unigene_convert";
$params->{ids_string} = "SGN-U243120 SGN-U243522";
$params->{db} = CXGN::DB::Connection->new('sgn');

# Testing constructor.
my $bulk = CXGN::Bulk::UnigeneConverter->new($params);

is($bulk->{idType}, "unigene_convert", "idType ok");
is($bulk->{ids_string}, "SGN-U243120 SGN-U243522", "id input string ok");
isa_ok($bulk->{db}, "CXGN::DB::Connection");

# Testing process_parameters method.
my $pp = $bulk->process_parameters();

is($pp, 1, "parameters are ok (process_parameters returned 1)");

my @values = qw/243120 243522/;
my $numbers = \@values;
print Dumper($numbers) . "\n";
is(Dumper($bulk->{ids}), Dumper($numbers), "id list is ok");

# Testing process_ids method.
$bulk->process_ids();

my $result = "SGN-U243522\tSolanum tuberosum - 3\tSolanum tuberosum - 4\tSGN-U268707\n";
is($bulk->{query_result_str}, $result, "result list  is ok");

