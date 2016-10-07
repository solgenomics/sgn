package CXGN::Phenotypes::Search;

=head1 NAME

CXGN::Phenotypes::Download - an object to handle searching phenotypes for trials or stocks

=head1 USAGE

my $download_phenotypes = CXGN::Phenotypes::Search->new(
    bcs_schema=>$schema,
    stock_list=>$plots,
    trait_list=>$traits,
    has_timestamps=>$timestamp_included,
);

=head1 DESCRIPTION


=head1 AUTHORS

 Nicolas Morales (nm529@cornell.edu)

=cut

use strict;
use warnings;
use Moose;
use Try::Tiny;
use Data::Dumper;
use SGN::Model::Cvterm;

has 'bcs_schema' => ( isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1,
);

#Not specifying data_level will given phenotypes for all data levels (plots, plants, etc)
has 'data_level' => (
    isa => 'Str|Undef',
    is => 'ro',
);

has 'trial_list' => (
    isa => 'ArrayRef|Undef',
    is => 'rw',
);

has 'trait_list' => (
    isa => 'ArrayRef|Undef',
    is => 'rw',
);

has 'stock_list' => (
    isa => 'ArrayRef|Undef',
    is => 'rw',
);

has 'include_timestamp' => (
    isa => 'Bool|Undef',
    is => 'ro',
    default => 0
);

has 'trait_contains' => (
    isa => 'ArrayRef|Undef',
    is => 'rw'
);

has 'phenotype_min_value' => (
    isa => 'Int|Undef',
    is => 'rw'
);

has 'phenotype_max_value' => (
    isa => 'Int|Undef',
    is => 'rw'
);

sub download_trial_phenotypes {
    my $self = shift;
    my $schema = $self->bcs_schema();

    my $rep_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'replicate', 'stock_property')->cvterm_id();
    my $block_number_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'block', 'stock_property')->cvterm_id();
    my $year_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project year', 'project_property')->cvterm_id();
    my $plot_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id();
    my $plant_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant', 'stock_type')->cvterm_id();
    my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();

    my @where_clause;
    if ($self->stock_list) {
        my $accession_sql = _sql_from_arrayref($self->stock_list);
        push @where_clause, "stock.stock_id in ($accession_sql)";
    }
    if ($self->trial_list) {
        my $trial_sql = _sql_from_arrayref($self->trial_list);
        push @where_clause, "project.project_id in ($trial_sql)";
    }
    if ($self->trait_list) {
        my $trait_sql = _sql_from_arrayref($self->trait_list);
        push @where_clause, "cvterm.cvterm_id in ($trait_sql)";
    }
    if ($self->trait_contains) {
        foreach (@{$self->trait_contains}) {
            push @where_clause, "cvterm.name like '%".$_."%'";
        }
    }
    if ($self->phenotype_min_value) {
        push @where_clause, "phenotype.value > ".$self->phenotype_min_value;
    }
    if ($self->phenotype_max_value) {
        push @where_clause, "phenotype.value < ".$self->phenotype_max_value;
    }

    my $where_clause = "";

    if (@where_clause>0) {
        $where_clause .= $rep_type_id ? "WHERE (stockprop.type_id = $rep_type_id OR stockprop.type_id IS NULL) " : "WHERE stockprop.type_id IS NULL";
        if ($data_level) {
            my $stock_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, $data_level, 'stock_type')->cvterm_id();
            $where_clause .= "AND (plot.type_id = $stock_type_id) AND stock.type_id = $accession_type_id";
        } else {
            $where_clause .= "AND (plot.type_id = $plot_type_id OR plot.type_id = $plant_type_id) AND stock.type_id = $accession_type_id";
        }
        $where_clause .= $block_number_type_id  ? " AND (block_number.type_id = $block_number_type_id OR block_number.type_id IS NULL)" : " AND block_number.type_id IS NULL";
        $where_clause .= $year_type_id ? " AND projectprop.type_id = $year_type_id" :"" ;
        $where_clause .= " AND " . (join (" AND " , @where_clause));

	#$where_clause = "where (stockprop.type_id=$rep_type_id or stockprop.type_id IS NULL) AND (block_number.type_id=$block_number_type_id or block_number.type_id IS NULL) AND  ".(join (" and ", @where_clause));
    }
    print STDERR $where_clause."\n";

    my $order_clause = " order by project.name, string_to_array(plot_number.value, '.')::int[]";
    my $q = "SELECT projectprop.value, project.name, stock.uniquename, nd_geolocation.description, cvterm.name, phenotype.value, plot.uniquename, db.name, db.name ||  ':' || dbxref.accession AS accession, stockprop.value, block_number.value, cvterm.cvterm_id, project.project_id, nd_geolocation.nd_geolocation_id, stock.stock_id, plot.stock_id, phenotype.uniquename
             FROM stock as plot JOIN stock_relationship ON (plot.stock_id=subject_id)
             JOIN stock ON (object_id=stock.stock_id)
             LEFT JOIN stockprop ON (plot.stock_id=stockprop.stock_id)
             LEFT JOIN stockprop AS block_number ON (plot.stock_id=block_number.stock_id)
             LEFT JOIN stockprop AS plot_number ON (plot.stock_id=plot_number.stock_id) AND plot_number.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plot number')
             JOIN nd_experiment_stock ON(nd_experiment_stock.stock_id=plot.stock_id)
             JOIN nd_experiment ON (nd_experiment_stock.nd_experiment_id=nd_experiment.nd_experiment_id)
             JOIN nd_geolocation USING(nd_geolocation_id)
             JOIN nd_experiment_phenotype ON (nd_experiment_phenotype.nd_experiment_id=nd_experiment.nd_experiment_id)
             JOIN phenotype USING(phenotype_id) JOIN cvterm ON (phenotype.cvalue_id=cvterm.cvterm_id)
             JOIN cv USING(cv_id)
             JOIN dbxref ON (cvterm.dbxref_id = dbxref.dbxref_id)
             JOIN db USING(db_id)
             JOIN nd_experiment_project ON (nd_experiment_project.nd_experiment_id=nd_experiment.nd_experiment_id)
             JOIN project USING(project_id)
  JOIN projectprop USING(project_id)
             $where_clause
             $order_clause";

    #print STDERR "QUERY: $q\n\n";
    my $h = $self->dbh()->prepare($q);
    $h->execute();

    my $result = [];
    while (my ($year, $project_name, $stock_name, $location, $trait, $value, $plot_name, $cv_name, $cvterm_accession, $rep, $block_number, $trait_id, $project_id, $location_id, $stock_id, $plot_id, $phenotype_uniquename) = $h->fetchrow_array()) {
        push @$result, [ $year, $project_name, $stock_name, $location, $trait, $value, $plot_name, $cv_name, $cvterm_accession, $rep, $block_number, $trait_id, $project_id, $location_id, $stock_id, $plot_id, $phenotype_uniquename ];
    }
}

sub _sql_from_arrayref {
    my $arrayref = shift;
    my $sql;
    my $count = 1;
    foreach (@$arrayref) {
        if ($count < scalar(@$arrayref)) {
            $sql .= "$_,";
        } else {
            $sql .= $_;
        }
        $count++;
    }
    return $sql;
}

1;
