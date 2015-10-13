## A test for adding crosses
## Jeremy D. Edwards (jde22@cornell.edu) 2013

use strict;
use warnings;

use lib 't/lib';
use Test::More tests=>10;
use SGN::Test::WWW::Mechanize;

BEGIN {use_ok('CXGN::Pedigree::AddCrosses');}
BEGIN {use_ok('CXGN::DB::Connection');}
BEGIN {use_ok('Bio::GeneticRelationships::Pedigree');}
BEGIN {use_ok('Bio::GeneticRelationships::Individual');}
BEGIN {require_ok('Moose');}

my $test = SGN::Test::WWW::Mechanize->new();
my $schema = $test->context->dbic_schema('Bio::Chado::Schema');
ok(my $cross = Bio::GeneticRelationships::Pedigree->new(name => "xyzAccession1234", cross_type => "biparental"),"Create pedigree object");
ok(my $female_parent = Bio::GeneticRelationships::Individual->new(name => 'zyxFemale1234'),"Create individual for pedigree");
ok(my $male_parent = Bio::GeneticRelationships::Individual->new(name => 'zyxMale1234'),"Create individual for pedigree");
ok($cross->set_female_parent($female_parent), "Set a female parent for a pedigree");
ok($cross->set_male_parent($male_parent), "Set a male parent for a pedigree");
my @crosses;
push (@crosses, $cross);


