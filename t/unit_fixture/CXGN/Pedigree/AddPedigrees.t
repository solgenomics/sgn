## A test for adding pedigrees
## Jeremy D. Edwards (jde22@cornell.edu) 2013
## adapted for fixture, Lukas Mueller, Nov 2, 2014

use strict;
use warnings;

use lib 't/lib';

use SGN::Test::Fixture;

use Test::More;
#use SGN::Test::WWW::Mechanize;

BEGIN {use_ok('CXGN::Pedigree::AddPedigrees');}
BEGIN {use_ok('CXGN::DB::Connection');}
BEGIN {use_ok('Bio::GeneticRelationships::Pedigree');}
BEGIN {use_ok('Bio::GeneticRelationships::Individual');}
BEGIN {require_ok('Moose');}

my $test = SGN::Test::Fixture->new();
my $schema = $test->bcs_schema();
ok(my $pedigree = Bio::GeneticRelationships::Pedigree->new(name => "test_accession1", cross_type => "biparental"),"Create pedigree object");
ok(my $female_parent = Bio::GeneticRelationships::Individual->new(name => 'test_accession2'),"Create individual for pedigree");
ok(my $male_parent = Bio::GeneticRelationships::Individual->new(name => 'test_accession3'),"Create individual for pedigree");
ok($pedigree->set_female_parent($female_parent), "Set a female parent for a pedigree");
ok($pedigree->set_male_parent($male_parent), "Set a male parent for a pedigree");
my @pedigrees;
push (@pedigrees, $pedigree);
ok(my $add_pedigrees = CXGN::Pedigree::AddPedigrees->new(schema => $schema, pedigrees => \@pedigrees),"Create object to add pedigrees");
ok(my $validate_pedigrees = $add_pedigrees->validate_pedigrees(), "Can do validation of pedigrees"); #won't work unless accessions are in the database

done_testing();
