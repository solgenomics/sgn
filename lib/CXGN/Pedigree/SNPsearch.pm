package CXGN::Genotype::SNPSearch

use strict;
use warnings;

use CXGN::Genotype;
use CXGN::Genotype::Search;
use CXGN::Stock::StockLookup;
use Bio__GeneticRelationships::Pedigree;

has 'schema' => (
		 is       => 'rw',
		 isa      => 'DBIx::Class::Schema',
		 predicate => 'has_schema',
		 required => 1,
		);
has 'pedigrees' => (isa =>'ArrayRef[Bio::GeneticRelationships::Pedigree]', is => 'rw', predicate => 'has_pedigrees');

sub pedigree_snptest{
  my $self = shift;
	my $pedigree = shift;
	my $schema = $self->get_schema();
	my @scores;
	my $protocol_id = 1;

	my $acc_name = $pedigree->get_name();
	print STDERR "Working on accession $acc_name... \n";

	my $stock_lookup = CXGN::Stock::StockLookup->new(schema => $schema);
	$stock_lookup->set_stock_name($acc_name);
	my $stock_lookup_result = $stock_lookup->get_stock_exact();
	my $stock_id = $stock_lookup_result->stock_id();

	my $mother = $pedigree->get_female_parent();
	my $mother_name = $mother->get_name();
	my $mother_lookup = CXGN::Stock::StockLookup->new(schema => $schema);
	$mother_lookup->set_stock_name($mother_name);
	my $mother_lookup_result = $mother_lookup->get_stock_exact();
	my $mother_id = $mother_lookup_result->stock_id();

	my $father = $pedigree->get_male_parent();
	my $father_name = $father->get_name();
	my $father_lookup = CXGN::Stock::StockLookup->new(schema => $schema);
	$father_lookup->set_stock_name($father_name);
	my $father_lookup_result = $father_lookup->get_stock_exact();
	my $father_id = $father_lookup_result->stock_id();

  if ($mother_name && $father_name) {
  my $gts = CXGN::Genotype::Search->new( {
      bcs_schema => $schema,
      accession_list => [$stock_id],
      protocol_id => $protocol_id,
      });

	my @self_gts = $gts->get_genotype_info_as_genotype_objects();
  if (!@self_gts) {
			return "Genotype of accession $acc_name not available. Skipping...\n";
	}

	my $mom_gts = CXGN::Genotype::Search->new( {
    bcs_schema => $schema,
    accession_list => [$mother_id],
    protocol_id => $protocol_id,
  });
  my @mom_gts = $mom_gts->get_genotype_info_as_genotype_objects();
  if (!@mom_gts) {
    return "Genotype of female parent $mother_name missing. Skipping.\n";
  }

	my $dad_gts;
	my @dad_gts;

  if ($mother_id == $father_id){
     $dad_gts = $mom_gts;
  }
  else{
     	$dad_gts = CXGN::Genotype::Search->new( {
       bcs_schema => $schema,
       accession_list => [$father_id],
       protocol_id => $protocol_id,
    });
    @dad_gts = $dad_gts->get_genotype_info_as_genotype_objects();
  }
  if (!@dad_gts) {
    return "Genotype of male parent $father_name missing. Skipping.\n";
	}

  my $s = shift @self_gts;
  my $m = shift @mom_gts;
  my $d = shift @dad_gts;
  my ($concordant, $discordant, $non_informative) = $s->compare_parental_genotypes($m, $d);
  my $score = $concordant / ($concordant + $discordant);

	return $score;
	}
}
