## A test for adding pedigrees
## Jeremy D. Edwards (jde22@cornell.edu) 2013
## adapted for fixture, Lukas Mueller, Nov 2, 2014

use strict;
use warnings;

use lib 't/lib';

use SGN::Test::Fixture;

use Test::More;
use Data::Dumper;
#use SGN::Test::WWW::Mechanize;

BEGIN {use_ok('CXGN::Pedigree::AddPedigrees');}
BEGIN {use_ok('CXGN::DB::Connection');}
BEGIN {use_ok('Bio::GeneticRelationships::Pedigree');}
BEGIN {use_ok('Bio::GeneticRelationships::Individual');}
BEGIN {require_ok('Moose');}

my $test = SGN::Test::Fixture->new();
my $schema = $test->bcs_schema();

# biparental pedigree
#
ok(my $pedigree = Bio::GeneticRelationships::Pedigree->new(name => "test_accession1", cross_type => "biparental"),"Create pedigree object");
ok(my $female_parent = Bio::GeneticRelationships::Individual->new(name => 'test_accession3'),"Create individual for pedigree");
ok(my $male_parent = Bio::GeneticRelationships::Individual->new(name => 'test_accession4'),"Create individual for pedigree");
ok($pedigree->set_female_parent($female_parent), "Set a female parent for a pedigree");
ok($pedigree->set_male_parent($male_parent), "Set a male parent for a pedigree");

# self
#
ok(my $pedigree2 = Bio::GeneticRelationships::Pedigree->new(name => "test_accession4", cross_type => "self"),"Create pedigree object");
ok(my $female_parent2 = Bio::GeneticRelationships::Individual->new(name => 'test_accession3'),"Create individual for pedigree");
ok(my $male_parent2 = Bio::GeneticRelationships::Individual->new(name => 'test_accession3'),"Create individual for pedigree");
ok($pedigree2->set_female_parent($female_parent2), "Set a female parent for a pedigree");
ok($pedigree2->set_male_parent($male_parent2), "Set a male parent for a pedigree");

# unknown male parent
#
ok(my $pedigree3 = Bio::GeneticRelationships::Pedigree->new(name => "test_accession1", cross_type => "open"),"Create pedigree object");
ok(my $female_parent3 = Bio::GeneticRelationships::Individual->new(name => 'test_accession2'),"Create individual for pedigree");
ok(my $male_parent3 = Bio::GeneticRelationships::Individual->new(name => 'test_accession3'),"Create individual for pedigree");
ok($pedigree3->set_female_parent($female_parent3), "Set a female parent for a pedigree");
###ok($pedigree3->set_male_parent(''), "Set an empty male parent for a pedigree");

my @pedigrees;
for my $p ($pedigree, $pedigree2, $pedigree3) { 
    push (@pedigrees, $p);
}

ok(my $add_pedigrees = CXGN::Pedigree::AddPedigrees->new(schema => $schema, pedigrees => \@pedigrees),"Create object to add pedigrees");
ok(my $validate_pedigrees = $add_pedigrees->validate_pedigrees(), "Can do validation of pedigrees"); #won't work unless accessions are in the database
ok(!exists($validate_pedigrees->{error}));
ok(my $add_return = $add_pedigrees->add_pedigrees(), "Can save pedigrees");
ok(!exists($add_return->{error}));

print STDERR "Now trying a population as a parent... \n";

my $population_type_id = $test->bcs_schema()->resultset("Cv::Cvterm")->find( { name => 'population' })->cvterm_id();

my $population_row = $test->bcs_schema()->resultset("Stock::Stock")->create( 
    { 
	name => 'test_population',
	uniquename => 'test_population',
	type_id => $population_type_id,
    });

#my $open_parent = Bio::GeneticRelationships::Population->new(name => 'test_population');
#my @members = ( 'test_accession3', 'test_accession4');
#$open_parent->set_members(\@members);
ok(my $open_parent = Bio::GeneticRelationships::Individual->new(name => 'test_population'),"Create individual for pop");

my $open_pedigree = Bio::GeneticRelationships::Pedigree->new(name => 'test_accession5', cross_type => 'open');
$open_pedigree->set_female_parent($female_parent3);
$open_pedigree->set_male_parent($open_parent);
my $add_open_pedigree = CXGN::Pedigree::AddPedigrees->new(schema=>$schema, pedigrees => [ $open_pedigree ]);
my $validate_return = $add_open_pedigree->validate_pedigrees();
print STDERR Dumper $validate_return;
ok($validate_return);
ok(!exists($validate_return->{error}));
my $add_return = $add_open_pedigree->add_pedigrees();
print STDERR Dumper $add_return;
ok($add_return);
ok(!exists($add_return->{error}));

done_testing();
