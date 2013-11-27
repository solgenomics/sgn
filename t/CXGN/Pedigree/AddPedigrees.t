## A test for adding pedigrees
## Jeremy D. Edwards (jde22@cornell.edu) 2013

use strict;
use warnings;

use lib 't/lib';
use Test::More tests=>7;
use SGN::Test::WWW::Mechanize;

BEGIN {use_ok('CXGN::Pedigree::AddPedigrees');}
BEGIN {use_ok('CXGN::DB::Connection');}
BEGIN {use_ok('Bio::GeneticRelationships::Pedigree');}
BEGIN {use_ok('Bio::GeneticRelationships::Individual');}
BEGIN {require_ok('Moose');}

my $test = SGN::Test::WWW::Mechanize->new();
my $schema = $test->context->dbic_schema('Bio::Chado::Schema');

ok(my $pedigree = Bio::GeneticRelationships::Pedigree->new(name => "xyzAccession1234", cross_type => "biparental"),"Create pedigree object");
my @pedigrees;
push (@pedigrees, $pedigree);
ok(my $add_pedigrees = CXGN::Pedigree::AddPedigrees->new(schema => $schema, pedigrees => \@pedigrees),"Create object to add pedigrees");



