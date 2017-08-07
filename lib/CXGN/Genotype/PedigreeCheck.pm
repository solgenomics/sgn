package CXGN::Genotype::PedigreeCheck;

use strict;
use warnings;

use Moose;
use Moose::Util::TypeConstraints;
use CXGN::Genotype;
use CXGN::Genotype::Search;
use CXGN::Stock::StockLookup;
use Bio::GeneticRelationships::Pedigree;

has 'schema' => (
		 is       => 'rw',
		 isa      => 'DBIx::Class::Schema',
		 predicate => 'has_schema',
		 required => 1,
	   );
has 'accession_name' => (
		is			 => 'rw',
		isa			 => 'Str',
		required => 1,
		);
has 'mother_id' => (
		is			 => 'rw',
		isa			 => 'Int',
		required => 1,
		);
has 'father_id' => (
		is		    => 'rw',
		isa 			=> 'Int',
		required  => 1,
		);
has 'protocol_id' => (
		is				=> 'rw',
		isa				=> 'Int',
		required  => 1,
		);

sub pedigree_check{
  my $self = shift;
	my $accession_name =$self->accession_name();
	my $mother_id = $self->mother_id();
	my $father_id = $self->father_id();
	my $protocol_id = $self->protocol_id();

	print STDERR "protocol id is";
	my $schema = $self->schema();

	print STDERR "father id is $father_id\n";
	print STDERR "mother id is $mother_id\n";

	my $stock_lookup = CXGN::Stock::StockLookup->new(schema => $schema);
	$stock_lookup->set_stock_name($accession_name);
	my $stock_lookup_result = $stock_lookup->get_stock_exact();
	my $stock_id = $stock_lookup_result->stock_id();
	my $stock = CXGN::Stock->new(schema => $schema, stock_id => $stock_id);

  if ($mother_id && $father_id) {
	  my $gts = CXGN::Genotype::Search->new( {
	      bcs_schema => $schema,
	      accession_list => [$stock_id],
	      protocol_id => $protocol_id,
	      });
		my @self_gts = $gts->get_genotype_info_as_genotype_objects();
	  if (!@self_gts) {
				return {error => "Genotype of accession $accession_name not available. Skipping...\n"};
		}
		print STDERR "found self gts\n";
		my $mom_gts = CXGN::Genotype::Search->new( {
	    bcs_schema => $schema,
	    accession_list => [$mother_id],
	    protocol_id => $protocol_id,
	  	});
	  my @mom_gts = $mom_gts->get_genotype_info_as_genotype_objects();
	  if (!@mom_gts) {
	    return {error => "Genotype of female parent $mother_id missing. Skipping.\n"};
	  }
		print STDERR "found mom gts\n";
		my $dad_gts;

	  if ($mother_id == $father_id){
	     $dad_gts = $mom_gts;
	  }
	  else{
	    $dad_gts = CXGN::Genotype::Search->new( {
	       bcs_schema => $schema,
	       accession_list => [$father_id],
	       protocol_id => $protocol_id,
	    });
	  }
		my @dad_gts = $dad_gts->get_genotype_info_as_genotype_objects();

	  if (!@dad_gts) {
	    return {error => "Genotype of male parent $father_id missing. Skipping.\n"};
		}
		print STDERR "found dad gts\n";
	  my $s = shift @self_gts;
	  my $m = shift @mom_gts;
	  my $d = shift @dad_gts;
	  my ($concordant, $discordant, $non_informative) = $s->compare_parental_genotypes($m, $d);
	  my $score = ($concordant / ($concordant + $discordant));
		$score = (1 - $score);
		$score = (100 * $score);
		$score = sprintf("%.2f", $score);
		print STDERR "scores are $score\n";
		return {score => $score};
		}
		else{
			return {error => "No parents were found for this accession $accession_name. Skipping\n"};
		}
	print STDERR "Done.\n";
}
1;
#return error as hash to prevent errors
# check for error in controller
