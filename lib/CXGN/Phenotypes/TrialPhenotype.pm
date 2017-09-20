
package CXGN::Phenotypes::TrialPhenotype;


=head1 NAME

CXGN::Phenotypes::TrialPhenotype - an object to handle retrieving of trial phenotype and field information.

=head1 USAGE

my $phenotypes_heatmap = CXGN::Phenotypes::TrialPhenotype->new(
	bcs_schema=>$schema,
	trial_id=>$trial_id,
	trait_id=>$trait_id
);
my @phenotype = $phenotypes_heatmap->get_trial_phenotypes_heatmap();

=head1 DESCRIPTION


=head1 AUTHORS


=cut



use strict;
use warnings;
use Moose;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Stock::StockLookup;
use CXGN::Phenotypes::SearchFactory;

BEGIN { extends 'Catalyst::Controller'; }

has 'bcs_schema' => (
	isa => 'Bio::Chado::Schema',
	is => 'rw',
	required => 1,
);

has 'trial_id' => (
	isa => 'Int',
	is => 'rw',
    required => 1,
);

has 'trait_id' => (
	isa => 'Int',
	is => 'rw',
    required => 1,
);


sub get_trial_phenotypes_heatmap {
    my $self = shift;
    my $schema = $self->bcs_schema;
    my $trial_id = $self->trial_id;
    my $trait_id = $self->trait_id;
	my $rep_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'replicate', 'stock_property')->cvterm_id();
    my $block_number_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'block', 'stock_property')->cvterm_id();
    my $plot_number_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot number', 'stock_property')->cvterm_id();
    my $row_number_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'row_number', 'stock_property')->cvterm_id();
	my $col_number_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'col_number', 'stock_property')->cvterm_id();
    my $plot_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id();
    my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $numeric_regex = '^[0-9]+([,.][0-9]+)?$';

    my $stock_lookup = CXGN::Stock::StockLookup->new({ schema => $schema} );
	my %columns = (
	  trial_id=> 'project.project_id',
	  trait_id=> 'cvterm.cvterm_id',
      row_number=> 'row_number.value',
      col_number=> 'col_number.value',
      rep=> 'rep.value',
	  plot_number=> 'plot_number.value',
	  block_number=> 'block_number.value',
      phenotype_value=> 'phenotype.value',
      plot_name=> 'plot.uniquename AS plot_name',
      accession_name=> 'accession.uniquename',
      from_clause=> " FROM stock as plot JOIN stock_relationship ON (plot.stock_id=subject_id)
      JOIN cvterm as plot_type ON (plot_type.cvterm_id = plot.type_id)
      JOIN stock as accession ON (object_id=accession.stock_id AND accession.type_id = $accession_type_id)
      LEFT JOIN stockprop AS rep ON (plot.stock_id=rep.stock_id AND rep.type_id = $rep_type_id)
      LEFT JOIN stockprop AS block_number ON (plot.stock_id=block_number.stock_id AND block_number.type_id = $block_number_type_id)
	  LEFT JOIN stockprop AS col_number ON (plot.stock_id=col_number.stock_id AND col_number.type_id = $col_number_type_id)
	  LEFT JOIN stockprop AS row_number ON (plot.stock_id=row_number.stock_id AND row_number.type_id = $row_number_type_id)
      LEFT JOIN stockprop AS plot_number ON (plot.stock_id=plot_number.stock_id AND plot_number.type_id = $plot_number_type_id)
      JOIN nd_experiment_stock ON(nd_experiment_stock.stock_id=plot.stock_id)
      JOIN nd_experiment ON (nd_experiment_stock.nd_experiment_id=nd_experiment.nd_experiment_id)
      LEFT JOIN nd_experiment_phenotype ON (nd_experiment_phenotype.nd_experiment_id=nd_experiment.nd_experiment_id)
      LEFT JOIN phenotype USING(phenotype_id)
      LEFT JOIN cvterm ON (phenotype.cvalue_id=cvterm.cvterm_id)
      JOIN dbxref ON (cvterm.dbxref_id = dbxref.dbxref_id)
      JOIN db USING(db_id)
      JOIN nd_experiment_project ON (nd_experiment_project.nd_experiment_id=nd_experiment.nd_experiment_id)
      JOIN project USING(project_id)",
    );

	my $select_clause = "SELECT  ".$columns{'plot_name'}.", ".$columns{'accession_name'}.", ".$columns{'plot_number'}.", ".$columns{'block_number'}.", ".$columns{'rep'}.", ".$columns{'row_number'}.", ".$columns{'col_number'}.", ".$columns{'phenotype_value'}."";

	my $from_clause = $columns{'from_clause'};

	my $order_clause = " ORDER BY 3";

	my @where_clause;
	
	if ($trial_id && $trait_id){
		push @where_clause, $columns{'trait_id'}." in ($trait_id)";
		push @where_clause, $columns{'trial_id'}." in ($trial_id)";	
	}
    
    my $where_clause = " WHERE " . (join (" AND " , @where_clause));
	my  $q = $select_clause . $from_clause . $where_clause . $order_clause;
	
	my $h = $schema->storage->dbh()->prepare($q);
    $h->execute();
    my $result = [];
	
	while (my ($plot_name, $stock_name, $plot_number, $block_number, $rep, $row_number, $col_number, $value) = $h->fetchrow_array()) {
        push @$result, [ $plot_name, $stock_name, $plot_number, $block_number, $rep, $row_number, $col_number, $value ];
    }

    print STDERR "Search End:".localtime."\n";
	print STDERR Dumper($result);
    return $result;
}


1;