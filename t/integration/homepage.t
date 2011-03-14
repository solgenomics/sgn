#!/usr/bin/perl
use strict;
use warnings;

use Test::More;
use lib 't/lib';

use SGN::Test::WWW::Mechanize;
my $mech = SGN::Test::WWW::Mechanize->new;

$mech->get( '/' );
$mech->html_lint_ok;
$mech->dbh_leak_ok;

done_testing;
