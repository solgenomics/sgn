use strict;
use warnings;

use lib 't/lib';
use Test::More tests=>3;
use SGN::Test::WWW::Mechanize;

BEGIN {use_ok('CXGN::BreedersToolbox::AccessionsFuzzySearch');}
BEGIN {use_ok('CXGN::DB::Connection');}
BEGIN {require_ok('Moose');}

my $test = SGN::Test::WWW::Mechanize->new();
my $schema = $test->context->dbic_schema('Bio::Chado::Schema');


