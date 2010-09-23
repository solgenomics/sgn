#!/usr/bin/env perl

use lib 't/lib';
use Test::More;

use_ok('SGN::Test::Data',qw/create_test_organism create_test_dbxref create_test_feature create_test_cvterm/);

done_testing;
