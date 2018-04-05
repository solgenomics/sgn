package CXGN::Phenotypes::Search::MetaData;

=head1 NAME

CXGN::Phenotypes::Search::Native - an object to handle searching phenotypes across database. called from factory CXGN::Phenotypes::SearchFactory. Processes phenotype search against cxgn schema.

=head1 USAGE

my $phenotypes_search = CXGN::Phenotypes::SearchFactory->instantiate(
    'Native',    #can be either 'MaterializedView', or 'Native'
    {
        bcs_schema=>$schema,
        data_level=>$data_level,
        trait_list=>$trait_list,
        trial_list=>$trial_list,
        year_list=>$year_list,
        location_list=>$location_list,
        accession_list=>$accession_list,
        plot_list=>$plot_list,
        plant_list=>$plant_list,
        subplot_list=>$subplot_list,
        exclude_phenotype_outlier=>0,
        include_timestamp=>$include_timestamp,
        include_row_and_column_numbers=>0,
        trait_contains=>$trait_contains,
        phenotype_min_value=>$phenotype_min_value,
        phenotype_max_value=>$phenotype_max_value,
        limit=>$limit,
        offset=>$offset
    }
);
my @data = $phenotypes_search->search();

=head1 DESCRIPTION


=head1 AUTHORS


=cut

use strict;
use warnings;
use Moose;
use Try::Tiny;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Stock::StockLookup;
use CXGN::Trial::TrialLayout;
use CXGN::Calendar;
use CXGN::Trial;
use CXGN::Trial::TrialLayout;

has 'bcs_schema' => ( isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1,
);

has 'data_level' => (
    isa => 'Str|Undef',
    is => 'ro',
);

has 'trial_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);


sub search {
    my $self = shift;
    my $schema = $self->bcs_schema();
    print STDERR "Search Start:".localtime."\n";
    my $year_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project year', 'project_property')->cvterm_id();
    my $design_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'design', 'project_property')->cvterm_id();
    my $planting_date_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project_planting_date', 'project_property')->cvterm_id();
    my $havest_date_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project_harvest_date', 'project_property')->cvterm_id();
    my $breeding_program_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'breeding_program', 'project_property')->cvterm_id();
    my $project_location_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project location', 'project_property')->cvterm_id();

    #For performance reasons the number of joins to stock can be reduced if a trial is given. If trial(s) given, use the cached layout from TrialLayout instead.

    my %columns = (
      trial_id=> 'project.project_id',
      location_id=> 'location.value',
      year_id=> 'year.value',
      trial_name=> 'project.name',
      location_name=> 'location.value',
      trial_design=> 'design.value',
      planting_date => 'plantingDate.value',
      harvest_date => 'harvestDate.value',
      breeding_program => 'breeding_program.name',
      from_clause=> " FROM project
      JOIN project_relationship ON (project.project_id=project_relationship.subject_project_id )
      JOIN project as breeding_program on (breeding_program.project_id=project_relationship.object_project_id)
      LEFT JOIN projectprop as year ON (project.project_id=year.project_id AND year.type_id = $year_type_id)
      LEFT JOIN projectprop as design ON (project.project_id=design.project_id AND design.type_id = $design_type_id)
      LEFT JOIN projectprop as location ON (project.project_id=location.project_id AND location.type_id = $project_location_type_id)
      LEFT JOIN projectprop as plantingDate ON (project.project_id=plantingDate.project_id AND plantingDate.type_id = $planting_date_type_id)
      LEFT JOIN projectprop as harvestDate ON (project.project_id=harvestDate.project_id AND harvestDate.type_id = $havest_date_type_id)
      LEFT JOIN projectprop as breeding_program_check ON (breeding_program.project_id=breeding_program_check.project_id AND breeding_program_check.type_id = $breeding_program_type_id)",
    );

    my $select_clause = "SELECT ".$columns{'year_id'}.", ".$columns{'trial_name'}.", ".$columns{'location_name'}.", ".$columns{'trial_id'}.", ".$columns{'location_id'}.", ".$columns{'trial_design'}.", ".$columns{'planting_date'}.", ".$columns{'harvest_date'}.", ".$columns{'breeding_program'};
    my $from_clause = $columns{'from_clause'};

    #my $order_clause = " ORDER BY 2,7,16 DESC";

    my @where_clause;

    if ($self->trial_list && scalar(@{$self->trial_list})>0) {
        my $trial_sql = _sql_from_arrayref($self->trial_list);
        push @where_clause, $columns{'trial_id'}." in ($trial_sql)";
    }

    my $where_clause = " WHERE " . (join (" AND " , @where_clause));

    my  $q = $select_clause . $from_clause . $where_clause ;

    print STDERR "QUERY: $q\n\n";
    
    my $location_rs = $schema->resultset('NaturalDiversity::NdGeolocation')->search();
    my %location_id_lookup;
    while( my $r = $location_rs->next()){
        $location_id_lookup{$r->nd_geolocation_id} = $r->description;
    }

    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute();
    my $result = [];

    while (my ($year, $project_name, $location, $trial_id, $location_id, $design, $planting_date, $harvest_date, $breeding_program) = $h->fetchrow_array()) {        
        
        my $trial = CXGN::Trial->new( { bcs_schema => $schema, trial_id => $trial_id });
        my $trial_desc = $trial->get_description();
        my $trial_type_data = $trial->get_project_type();
        my $trial_type = $trial_type_data->[1];
        
        my $layout = CXGN::Trial::TrialLayout->new({schema => $schema, trial_id => $trial_id, experiment_type=>'field_layout'});
        
        my $plot_dimensions = $layout->get_plot_dimensions();
        
        my $plot_length = '';
        if ($plot_dimensions->[0]) {
    	$plot_length = $plot_dimensions->[0];
        }

        my $plot_width = '';
        if ($plot_dimensions->[1]){
    	$plot_width = $plot_dimensions->[1];
        }

        my $plants_per_plot = '';
        if ($plot_dimensions->[2]){
    	$plants_per_plot = $plot_dimensions->[2];
        }

        my $block_numbers = $layout->get_block_numbers();
        my $number_of_blocks = '';
        if ($block_numbers) {
          $number_of_blocks = scalar(@{$block_numbers});
        }

        my $replicate_numbers = $layout->get_replicate_numbers();
        my $number_of_replicates = '';
        if ($replicate_numbers) {
          $number_of_replicates = scalar(@{$replicate_numbers});
        }        

        my $location_name = $location_id ? $location_id_lookup{$location_id} : '';
        my $calendar_funcs = CXGN::Calendar->new({});
        my $harvest_date_value = $calendar_funcs->display_start_date($harvest_date);
        my $planting_date_value = $calendar_funcs->display_start_date($planting_date);
        push @$result, [ $year, $project_name, $location_name, $design, $breeding_program, $trial_desc, $trial_type, $plot_length, $plot_width, $plants_per_plot, $number_of_blocks, $number_of_replicates, $planting_date_value, $harvest_date_value ];

    }
    print STDERR "Search End:".localtime."\n";
    return $result;
}

sub _sql_from_arrayref {
    my $arrayref = shift;
    my $sql = join ("," , @$arrayref);
    return $sql;
}


1;
