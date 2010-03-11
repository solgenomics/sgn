#!/usr/bin/perl
use strict;
use warnings;

# Test script for UnigeneConverter module.
# Matthew Crumb and Alexander Naydich
# July 9th 2007

# Bulk.pm and UnigeneConverter.pm need modification for test to run properly.

use Test::More;
use File::Temp;
use Data::Dumper;

use Module::Find;
useall 'CXGN::Bulk';

$SIG{__DIE__} = \&Carp::confess;

my $tempdir = File::Temp->newdir;
my $params = {};
$params->{idType} = "unigene_convert";
$params->{ids_string} = "SGN-U243120 SGN-U243522";
$params->{dbc} = CXGN::DB::Connection->new;
$params->{tempdir} = "$tempdir";

# Testing constructor.
my $bulk = CXGN::Bulk::UnigeneConverter->new($params);

is($bulk->{idType}, "unigene_convert", "idType ok");
is($bulk->{ids_string}, "SGN-U243120 SGN-U243522", "id input string ok");
isa_ok($bulk->{db}, "CXGN::DB::Connection");

# Testing process_parameters method.
my $pp = $bulk->process_parameters();

is($pp, 1, "parameters are ok (process_parameters returned 1)");

is_deeply( $bulk->{ids}, [243120, 243522], "id list is ok" );

# Testing process_ids method.
$bulk->process_ids();

$params->{dbc}->disconnect;

done_testing;


