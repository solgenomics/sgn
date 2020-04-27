package CXGN::Phenotypes::Search::MetaData;

=head1 NAME

CXGN::Phenotypes::Search::MetaData - an object to handle searching meta-data across database. called from factory CXGN::Phenotypes::SearchFactory. Processes meta-data search against cxgn schema.

=head1 USAGE

my $metadata_search = CXGN::Phenotypes::SearchFactory->instantiate(
    'MetaData',
    {
        bcs_schema=>$self->bcs_schema, 
        data_level=>$self->data_level,
        trial_list=>$self->trial_list,
    }
);
my @data = $metadata_search->search();

=head1 DESCRIPTION


=head1 AUTHORS

Alex Ogbonna <aco46@cornell.edu>

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
use JSON;

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
    my $project_location_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project location', 'project_property')->cvterm_id();
    my $breeding_program_rel_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'breeding_program_trial_relationship', 'project_relationship')->cvterm_id();
    my $plot_width_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot_width', 'project_property')->cvterm_id();
    my $plot_length_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot_length', 'project_property')->cvterm_id();
    my $plants_per_plot_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project_has_plant_entries', 'project_property')->cvterm_id();
    my $field_size_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'field_size', 'project_property')->cvterm_id();
    my $field_trial_is_planned_to_be_genotyped_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'field_trial_is_planned_to_be_genotyped', 'project_property')->cvterm_id();
    my $field_trial_is_planned_to_cross_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'field_trial_is_planned_to_cross', 'project_property')->cvterm_id();
    my $treatment_rel_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'trial_treatment_relationship', 'project_relationship')->cvterm_id();
    my $folder_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'trial_folder', 'project_property')->cvterm_id();

    #For performance reasons the number of joins to stock can be reduced if a trial is given. If trial(s) given, use the cached layout from TrialLayout instead.

    my $from_clause = " FROM project
      JOIN project_relationship ON (project.project_id=project_relationship.subject_project_id AND project_relationship.type_id = $breeding_program_rel_type_id)
      JOIN project as breeding_program on (breeding_program.project_id=project_relationship.object_project_id)
      LEFT JOIN projectprop as year ON (project.project_id=year.project_id AND year.type_id = $year_type_id)
      LEFT JOIN projectprop as design ON (project.project_id=design.project_id AND design.type_id = $design_type_id)
      LEFT JOIN projectprop as location ON (project.project_id=location.project_id AND location.type_id = $project_location_type_id)
      LEFT JOIN projectprop as planting_date ON (project.project_id=planting_date.project_id AND planting_date.type_id = $planting_date_type_id)
      LEFT JOIN projectprop as harvest_date ON (project.project_id=harvest_date.project_id AND harvest_date.type_id = $havest_date_type_id)
      LEFT JOIN projectprop as plot_width ON (project.project_id=plot_width.project_id AND plot_width.type_id = $plot_width_type_id)
      LEFT JOIN projectprop as plot_length ON (project.project_id=plot_length.project_id AND plot_length.type_id = $plot_length_type_id)
      LEFT JOIN projectprop as plants_per_plot ON (project.project_id=plants_per_plot.project_id AND plants_per_plot.type_id = $plants_per_plot_type_id)
      LEFT JOIN projectprop as field_size ON (project.project_id=field_size.project_id AND field_size.type_id = $field_size_type_id)
      LEFT JOIN projectprop as field_trial_is_planned_to_be_genotyped ON (project.project_id=field_trial_is_planned_to_be_genotyped.project_id AND field_trial_is_planned_to_be_genotyped.type_id = $field_trial_is_planned_to_be_genotyped_type_id)
      LEFT JOIN projectprop as field_trial_is_planned_to_cross ON (project.project_id=field_trial_is_planned_to_cross.project_id AND field_trial_is_planned_to_cross.type_id = $field_trial_is_planned_to_cross_type_id)
      LEFT JOIN project_relationship AS treatment_rel ON (project.project_id=treatment_rel.object_project_id AND treatment_rel.type_id = $treatment_rel_type_id)
      LEFT JOIN project AS treatment ON (treatment.project_id=treatment_rel.subject_project_id)
      LEFT JOIN project_relationship AS folder_rel ON (project.project_id=folder_rel.subject_project_id AND folder_rel.type_id = $folder_type_id)
      LEFT JOIN project AS folder ON (folder.project_id=folder_rel.object_project_id)";

    my $select_clause = "SELECT project.project_id, project.name, project.description, breeding_program.project_id, breeding_program.name, breeding_program.description, year.value, design.value, location.value, planting_date.value, harvest_date.value, plot_width.value, plot_length.value, plants_per_plot.value, field_size.value, field_trial_is_planned_to_be_genotyped.value, field_trial_is_planned_to_cross.value, folder.project_id, folder.name, folder.description, jsonb_object_agg(coalesce(
    case
        when (treatment.name) IS NULL then null
        else (treatment.name)
    end,
    'No ManagementFactor'), treatment.description)";

    my $group_by = " GROUP BY (project.project_id, project.name, project.description, breeding_program.project_id, breeding_program.name, breeding_program.description, year.value, design.value, location.value, planting_date.value, harvest_date.value, plot_width.value, plot_length.value, plants_per_plot.value, field_size.value, field_trial_is_planned_to_be_genotyped.value, field_trial_is_planned_to_cross.value, folder.project_id, folder.name, folder.description) ";

    my $order_clause = " ORDER BY 2";

    my @where_clause;

    if ($self->trial_list && scalar(@{$self->trial_list})>0) {
        my $trial_sql = _sql_from_arrayref($self->trial_list);
        push @where_clause, "project.project_id in ($trial_sql)";
    }

    my $where_clause = " WHERE " . (join (" AND " , @where_clause));

    my  $q = $select_clause . $from_clause . $where_clause . $group_by . $order_clause;

    print STDERR "QUERY: $q\n\n";
    
    my $location_rs = $schema->resultset('NaturalDiversity::NdGeolocation')->search();
    my %location_id_lookup;
    while( my $r = $location_rs->next()){
        $location_id_lookup{$r->nd_geolocation_id} = $r->description;
    }

    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute();
    my @result;

    my $calendar_funcs = CXGN::Calendar->new({});

    while (my ($project_id, $project_name, $project_description, $breeding_program_id, $breeding_program_name, $breeding_program_description, $year, $design, $location_id, $planting_date, $harvest_date, $plot_width, $plot_length, $plants_per_plot, $field_size, $field_trial_is_planned_to_be_genotyped, $field_trial_is_planned_to_cross, $folder_id, $folder_name, $folder_description, $treatments) = $h->fetchrow_array()) {        

        my $trial = CXGN::Trial->new( { bcs_schema => $schema, trial_id => $project_id });
        my $trial_type_data = $trial->get_project_type();
        my $trial_type = $trial_type_data->[1];

        my $layout = CXGN::Trial::TrialLayout->new({schema => $schema, trial_id => $project_id, experiment_type=>'field_layout'});

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
        my $harvest_date_value = $calendar_funcs->display_start_date($harvest_date);
        my $planting_date_value = $calendar_funcs->display_start_date($planting_date);

        my $treatments = decode_json $treatments;
        push @result, [ $project_id, $project_name, $project_description, $trial_type, $breeding_program_id, $breeding_program_name, $breeding_program_description, $year, $design, $location_id, $location_name, $planting_date_value, $harvest_date_value, $plot_width, $plot_length, $plants_per_plot, $number_of_blocks, $number_of_replicates, $field_size, $field_trial_is_planned_to_be_genotyped, $field_trial_is_planned_to_cross, $folder_id, $folder_name, $folder_description, $treatments ];

    }
    print STDERR "Search End:".localtime."\n";
    return \@result;
}

sub _sql_from_arrayref {
    my $arrayref = shift;
    my $sql = join ("," , @$arrayref);
    return $sql;
}


1;
