
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
use List::MoreUtils ':all';
use CXGN::Trial;

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

	my %columns = (
	  stock_id => 'plot.stock_id',
	  trial_id=> 'project.project_id',
	  trait_id=> 'cvterm.cvterm_id',
      row_number=> 'row_number.value::int',
      col_number=> 'col_number.value::int',
      rep=> 'rep.value',
	  plot_number=> 'plot_number.value::INT',
	  block_number=> 'block_number.value',
      phenotype_value=> 'phenotype.value',
	  phenotype_id=> 'phenotype.phenotype_id',
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
      LEFT JOIN dbxref ON (cvterm.dbxref_id = dbxref.dbxref_id)
      LEFT JOIN db USING(db_id)
      JOIN nd_experiment_project ON (nd_experiment_project.nd_experiment_id=nd_experiment.nd_experiment_id)
      JOIN project USING(project_id)",
    );

	my $select_clause = "SELECT  DISTINCT ".$columns{'stock_id'}.", ".$columns{'plot_name'}.", ".$columns{'accession_name'}.", ".$columns{'plot_number'}.", ".$columns{'block_number'}.", ".$columns{'rep'}.", ".$columns{'row_number'}.", ".$columns{'col_number'}.", ".$columns{'phenotype_value'}.", ".$columns{'phenotype_id'}."";

	my $from_clause = $columns{'from_clause'};

	my $order_clause = " ORDER BY 7, 8, 4 ASC";
	my $numeric_regex = '^-?[0-9]+([,.][0-9]+)?$';
	my $numeric_regex_2 = '/^\s*$/';

	my @where_clause;
	
	if ($trial_id && $trait_id){
		push @where_clause, " (". $columns{'trait_id'}." in ($trait_id) OR ". $columns{'trait_id'}." is NULL )";
		#push @where_clause, $columns{'trait_id'}." in ($trait_id)";	
		push @where_clause, "plot.type_id in ($plot_type_id)";
		push @where_clause, $columns{'trial_id'}." in ($trial_id)";	
		#push @where_clause, " (". $columns{'phenotype_value'}." ~\'$numeric_regex\' OR ". $columns{'phenotype_value'}." is NULL )";	
		push @where_clause, $columns{'phenotype_value'}." ~\'$numeric_regex\' ";	
	}
    
    my $where_clause = " WHERE " . (join (" AND " , @where_clause));
	my  $q = $select_clause . $from_clause . $where_clause . $order_clause;
	
	my $h = $schema->storage->dbh()->prepare($q);
    $h->execute();
    my $result = [];
	my (@col_No, @row_No, @pheno_val, @plot_Name, @stock_Name, @plot_No, @block_No, @rep_No, @msg, %results, @phenoID);
	
	while (my ($id, $plot_name, $stock_name, $plot_number, $block_number, $rep, $row_number, $col_number, $value, $pheno_id) = $h->fetchrow_array()) {
		if (!$row_number && !$col_number){
			if ($block_number){
				$row_number = $block_number;
			}elsif ($rep && !$block_number ){
				$row_number = $rep;
			}
		}
		my $plot_popUp = $plot_name."\nplot_No:".$plot_number."\nblock_No:".$block_number."\nrep_No:".$rep."\nstock:".$stock_name."\nvalue:".$value;
        push @$result,  {plotname => $plot_name, stock => $stock_name, plotn => $plot_number, blkn=>$block_number, rep=>$rep, row=>$row_number, col=>$col_number, pheno=>$value, plot_msg=>$plot_popUp, pheno_id=>$pheno_id} ;
		push @col_No, $col_number;
		push @row_No, $row_number;
		push @pheno_val, $value;
		push @plot_Name, $plot_name;
		push @stock_Name, $stock_name;
		push @plot_No, $plot_number;
		push @block_No, $block_number;
		push @rep_No, $rep;
        push @phenoID, $pheno_id; 
		push @msg, "plot_No:".$plot_number."\nblock_No:".$block_number."\nrep_No:".$rep."\nstock:".$stock_name."\nvalue:".$value;
    }
	
	# my ($min_col, $max_col) = minmax @col_No;
	# my ($min_row, $max_row) = minmax @row_No;
	# my (@unique_col,@unique_row);
	# for my $x (1..$max_col){
	# 	push @unique_col, $x;
	# }
	# for my $y (1..$max_row){
	# 	push @unique_row, $y;
	# }
	
    my $false_coord;
	if ($col_No[0] == ""){
        @col_No = ();
        $false_coord = 'false_coord';
		my @row_instances = uniq @row_No;
		my %unique_row_counts;
		$unique_row_counts{$_}++ for @row_No;        
        my @col_number2;
        for my $key (keys %unique_row_counts){
            push @col_number2, (1..$unique_row_counts{$key});
        }
        for (my $i=0; $i < scalar(@$result); $i++){               
            @$result[$i]->{'col'} = $col_number2[$i];
            push @col_No, $col_number2[$i];
        }		
	}
    
    my ($min_col, $max_col) = minmax @col_No;
	my ($min_row, $max_row) = minmax @row_No;
	my (@unique_col,@unique_row);
	for my $x (1..$max_col){
		push @unique_col, $x;
	}
	for my $y (1..$max_row){
		push @unique_row, $y;
	}
    
    my $trial = CXGN::Trial->new({
		bcs_schema => $schema,
		trial_id => $trial_id
	});
	my $data = $trial->get_controls();

	#print STDERR Dumper($data);

	my @control_name;
	foreach my $cntrl (@{$data}) {
		push @control_name, $cntrl->{'accession_name'};
	}
	#print STDERR Dumper(\@$result);
	#print STDERR Dumper(\@plot_No);

	%results = (
	col => \@col_No,
	row => \@row_No,
	pheno => \@pheno_val,
	plotName => \@plot_Name,
	stock => \@stock_Name,
	plot => \@plot_No,
	block => \@block_No,
	rep => \@rep_No,
	result => $result,
	plot_msg => \@msg,
	col_max => $max_col,
	row_max => $max_row,
	unique_col => \@unique_col,
	unique_row => \@unique_row,
    false_coord => $false_coord,
    phenoID => \@phenoID,
    controls => \@control_name
	);
    print STDERR "Search End:".localtime."\n";
	#print STDERR Dumper($result);
    return \%results;
}

1;