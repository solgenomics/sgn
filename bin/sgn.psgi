#!/usr/bin/env perl
use strict;
use warnings;
use SGN;

SGN->setup_engine('PSGI');
my $app = sub { SGN->run(@_) };

