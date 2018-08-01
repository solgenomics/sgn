package CXGN::Trial::Search;

=head1 NAME

CXGN::Trial::Search - an object to handle searching for trials given criteria

=head1 USAGE

my $trial_search = CXGN::Trial::Search->new({
    bcs_schema=>$schema,
    location_list=>\@locations,
    program_list=>\@breeding_program_names,
    program_id_list=>\@breeding_programs_ids,
    year_list=>\@years,
    trial_type_list=>\@trial_types,
    trial_id_list=>\@trial_ids,
    trial_name_list=>\@trial_names,
    trial_name_is_exact=>1
});
my ($result, $total_count) = $trial_search->search();

=head1 DESCRIPTION


=head1 AUTHORS

 With code adapted from SGN::Controller::AJAX::Search::Trial

=cut

use strict;
use warnings;
use Moose;
use Try::Tiny;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Calendar;

has 'bcs_schema' => ( isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1,
);

has 'program_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw',
);

has 'program_id_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'location_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw',
);

has 'location_id_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'year_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw',
);

has 'trial_type_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw',
);

has 'trial_id_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'trial_name_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw',
);

has 'folder_id_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'folder_name_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw',
);

has 'trial_name_is_exact' => (
    isa => 'Bool|Undef',
    is => 'rw',
    default => 0
);

has 'accession_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'accession_name_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw',
);

has 'trial_design_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw',
);

has 'trait_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'trial_has_tissue_samples' => (
    isa => 'Bool|Undef',
    is => 'rw',
    default => 0
);

has 'field_trials_only' => (
    isa => 'Bool|Undef',
    is => 'rw',
    default => 0
);

has 'sort_by' => (
    isa => 'Str|Undef',
    is => 'rw'
);

has 'order_by' => (
    isa => 'Str|Undef',
    is => 'rw'
);

has 'limit' => (
    isa => 'Int|Undef',
    is => 'rw'
);

has 'offset' => (
    isa => 'Int|Undef',
    is => 'rw'
);

sub search {
    my $self = shift;
    my $schema = $self->bcs_schema();
    my $program_list = $self->program_list;
    my $program_id_list = $self->program_id_list;
    my $location_list = $self->location_list;
    my $location_id_list = $self->location_id_list;
    my $year_list = $self->year_list;
    my $trial_type_list = $self->trial_type_list;
    my $trial_id_list = $self->trial_id_list;
    my $trial_name_list = $self->trial_name_list;
    my $folder_id_list = $self->folder_id_list;
    my $folder_name_list = $self->folder_name_list;
    my $trial_design_list = $self->trial_design_list;
    my $trial_name_is_exact = $self->trial_name_is_exact;
    my $accession_list = $self->accession_list;
    my $accession_name_list = $self->accession_name_list;
    my $trial_has_tissue_samples = $self->trial_has_tissue_samples;
    my $trait_list = $self->trait_list;
    my $sort_by = $self->sort_by;
    my $order_by = $self->order_by;

    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $phenotyping_experiment_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'phenotyping_experiment', 'experiment_type')->cvterm_id();
    my $breeding_program_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'breeding_program', 'project_property')->cvterm_id();
    my $breeding_program_trial_relationship_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'breeding_program_trial_relationship', 'project_relationship')->cvterm_id();
    my $trial_folder_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'trial_folder', 'project_property')->cvterm_id();
    my $cross_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'cross', 'stock_type')->cvterm_id();
    my $location_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project location', 'project_property')->cvterm_id();
    my $year_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project year', 'project_property')->cvterm_id();
    my $design_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'design', 'project_property')->cvterm_id();
    my $harvest_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project_harvest_date', 'project_property')->cvterm_id();
    my $planting_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project_planting_date', 'project_property')->cvterm_id();
    my $project_has_tissue_sample_entries = SGN::Model::Cvterm->get_cvterm_row($schema, 'project_has_tissue_sample_entries', 'project_property')->cvterm_id();
    my $calendar_funcs = CXGN::Calendar->new({});

    my $project_type_cv_id = $schema->resultset("Cv::Cv")->find( { name => "project_type" } )->cv_id();
    my $project_type_rs = $schema->resultset("Cv::Cvterm")->search( { cv_id => $project_type_cv_id } );
    my %trial_types;
    while ( my $row = $project_type_rs->next() ) {
        $trial_types{ $row->cvterm_id } = $row->name();
    }
    my $trial_types_sql = join ("," , keys %trial_types);

    my $not_trials_rs = $schema->resultset("Project::Projectprop")->search(
        [
            { type_id => $breeding_program_cvterm_id },
            { type_id => $trial_folder_cvterm_id },
            { type_id => $cross_cvterm_id }
        ]
    );
    my %not_trials;
    while ( my $row = $not_trials_rs->next() ) {
        $not_trials{ $row->project_id() } = 1;
    }

    my %locations;
    my $location_rs = $schema->resultset("NaturalDiversity::NdGeolocation")->search( {} );
    while ( my $row = $location_rs->next() ) {
        $locations{ $row->nd_geolocation_id() } = $row->description();
    }

    my @where_clause;

    if ($trial_has_tissue_samples){
        push @where_clause, "trial_has_tissue_samples.value IS NOT NULL";
    }

    if ($program_id_list && scalar(@$program_id_list)>0) {
        my $sql = join ("," , @$program_id_list);
        push @where_clause, "breeding_program.project_id in ($sql)";
    }
    if ($program_list && scalar(@$program_list)>0) {
        my $sql = join ("," , @$program_list);
        push @where_clause, "breeding_program.name in ($sql)";
    }
    if ($year_list && scalar(@$year_list)>0) {
        my $sql = join ("','" , @$year_list);
        my $year_sql = "'" . $sql . "'";
        push @where_clause, "year.value in ($year_sql)";
    }
    if ($trial_type_list && scalar(@$trial_type_list)>0) {
        my $sql = join ("," , @$trial_type_list);
        push @where_clause, "trial_type_name.name in ($sql)";
    }
    if ($trial_id_list && scalar(@$trial_id_list)>0) {
        my $sql = join ("," , @$trial_id_list);
        push @where_clause, "study.project_id in ($sql)";
    }
    if ($trial_name_is_exact){
        if ($trial_name_list && scalar(@$trial_name_list)>0) {
            my $sql = join ("," , @$trial_name_list);
            push @where_clause, "study.name in ($sql)";
        }
    } else {
        if ($trial_name_list && scalar(@$trial_name_list)>0) {
            my @or_clause;
            foreach (@$trial_name_list){
                push @or_clause, "study.name LIKE '%".$_."%'";
            }
            my $sql = join (" OR " , @or_clause);
            push @where_clause, "($sql)";
        }
    }
    if ($folder_id_list && scalar(@$folder_id_list)>0) {
        my $sql = join ("," , @$folder_id_list);
        push @where_clause, "folder.project_id in ($sql)";
    }
    if ($folder_name_list && scalar(@$folder_name_list)>0) {
        my $sql = join ("," , @$folder_name_list);
        push @where_clause, "folder.name in ($sql)";
    }
    if ($trial_design_list && scalar(@$trial_design_list)>0) {
        my $sql = join ("','" , @$trial_design_list);
        my $design_sql = "'" . $sql . "'";
        push @where_clause, "design.value in ($design_sql)";
    }
    if ($location_id_list && scalar(@$location_id_list)>0) {
        my $sql = join ("','" , @$location_id_list);
        my $location_sql = "'" . $sql . "'";
        push @where_clause, "location.value in ($location_sql)";
    }
    my $accession_join = '';
    if ( ($accession_list && scalar(@$accession_list)>0) || ($accession_name_list && scalar(@$accession_name_list)>0) ) {
        $accession_join = " JOIN nd_experiment_project ON(study.project_id=nd_experiment_project.project_id) JOIN nd_experiment USING(nd_experiment_id) JOIN nd_experiment_stock USING(nd_experiment_id) JOIN stock AS obs_unit ON(nd_experiment_stock.stock_id=obs_unit.stock_id) JOIN stock_relationship ON(stock_relationship.subject_id=obs_unit.stock_id) JOIN stock AS accession ON(stock_relationship.object_id=accession.stock_id AND accession.type_id=$accession_cvterm_id) ";
    }
    if ($accession_list && scalar(@$accession_list)>0) {
        my $sql = join ("," , @$accession_list);
        push @where_clause, "accession.stock_id in ($sql)";
    }
    if ($accession_name_list && scalar(@$accession_name_list)>0) {
        my $sql = join ("," , @$accession_name_list);
        push @where_clause, "accession.uniquename in ($sql)";
    }

    my $trait_join = '';
    if ($trait_list && scalar(@$trait_list)>0) {
        my $sql = join ("," , @$trait_list);
        push @where_clause, "phenotype.cvalue_id in ($sql)";
        $trait_join = " JOIN nd_experiment_project ON(study.project_id=nd_experiment_project.project_id) JOIN nd_experiment AS trial_experiment ON(trial_experiment.nd_experiment_id=nd_experiment_project.nd_experiment_id) JOIN nd_experiment_stock ON(trial_experiment.nd_experiment_id=nd_experiment_stock.nd_experiment_id) JOIN stock AS obs_unit ON(nd_experiment_stock.stock_id=obs_unit.stock_id) JOIN nd_experiment_stock ON(nd_experiment_stock.stock_id=obs_unit.stock_id) JOIN nd_experiment AS phenotype_experiment ON(nd_experiment_stock.nd_experiment_id=phenotype_experiment.nd_experiment_id AND phenotype_experiment.type_id=$phenotyping_experiment_cvterm_id) JOIN nd_experiment_phenotype ON(nd_experiment_phenotype.nd_experiment_id=phenotype_experiment.nd_experiment_id) JOIN phenotype USING(phenotype_id) ";
    }

    my $where_clause = scalar(@where_clause)>0 ? " WHERE " . (join (" AND " , @where_clause)) : '';

    my $offset_clause = '';
    my $limit_clause = '';
    if ($self->limit){
        $limit_clause = " LIMIT ".$self->limit;
    }
    if ($self->offset){
        $offset_clause = " OFFSET ".$self->offset;
    }

    my $q = "SELECT study.name, study.project_id, study.description, folder.name, folder.project_id, folder.description, trial_type_name.cvterm_id, trial_type_name.name, year.value, location.value, breeding_program.name, breeding_program.project_id, breeding_program.description, harvest_date.value, planting_date.value, design.value, count(study.project_id) OVER() AS full_count
        FROM project AS study
        JOIN project_relationship AS bp_rel ON(study.project_id=bp_rel.subject_project_id AND bp_rel.type_id=$breeding_program_trial_relationship_id)
        JOIN project AS breeding_program ON(bp_rel.object_project_id=breeding_program.project_id)
        LEFT JOIN project_relationship AS folder_rel ON(study.project_id=folder_rel.subject_project_id AND folder_rel.type_id=$trial_folder_cvterm_id)
        LEFT JOIN project AS folder ON(folder_rel.object_project_id=folder.project_id)
        LEFT JOIN projectprop ON(study.project_id=projectprop.project_id AND projectprop.type_id IN ($trial_types_sql))
        LEFT JOIN cvterm AS trial_type_name ON(projectprop.type_id=trial_type_name.cvterm_id)
        LEFT JOIN cv AS project_type ON(trial_type_name.cv_id=project_type.cv_id AND project_type.name='project_type')
        LEFT JOIN projectprop AS year ON(study.project_id=year.project_id AND year.type_id=$year_cvterm_id)
        LEFT JOIN projectprop AS location ON(study.project_id=location.project_id AND location.type_id=$location_cvterm_id)
        LEFT JOIN projectprop AS harvest_date ON(study.project_id=harvest_date.project_id AND harvest_date.type_id=$harvest_cvterm_id)
        LEFT JOIN projectprop AS planting_date ON(study.project_id=planting_date.project_id AND planting_date.type_id=$planting_cvterm_id)
        LEFT JOIN projectprop AS design ON(study.project_id=design.project_id AND design.type_id=$design_cvterm_id)
        LEFT JOIN projectprop AS trial_has_tissue_samples ON(study.project_id=trial_has_tissue_samples.project_id AND trial_has_tissue_samples.type_id=$project_has_tissue_sample_entries)
        $accession_join
        $trait_join
        $where_clause
        GROUP BY(study.name, study.project_id, study.description, folder.name, folder.project_id, folder.description, trial_type_name.cvterm_id, trial_type_name.name, year.value, location.value, breeding_program.name, breeding_program.project_id, breeding_program.description, harvest_date.value, planting_date.value, design.value)
        ORDER BY study.name
        $limit_clause
        $offset_clause;";

    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute();

    my @result;
    my $total_count = 0;
    my $subtract_count = 0;
    while (my ($study_name, $study_id, $study_description, $folder_name, $folder_id, $folder_description, $trial_type_id, $trial_type_name, $year, $location_id, $breeding_program_name, $breeding_program_id, $breeding_program_description, $harvest_date, $planting_date, $design, $full_count) = $h->fetchrow_array()) {
        my $location_name = $locations{$location_id};
        my $project_harvest_date = $calendar_funcs->display_start_date($harvest_date);
        my $project_planting_date = $calendar_funcs->display_start_date($planting_date);

        #In the future a 'project_class' would make this more clean by differentiating different project classes explicitly
        if ( $not_trials{$study_id} ) {
            $subtract_count++;
            next;
        }
        if ($self->field_trials_only){
            if ($design eq 'genotype_data_project' || $design eq 'genotyping_plate' || $trial_type_name eq 'crossing_trial'){
                $subtract_count++;
                next();
            }
        }
        if ($design eq 'treatment'){
            $subtract_count++;
            next();
        }

        push @result, {
            trial_id => $study_id,
            trial_name => $study_name,
            description => $study_description,
            folder_id => $folder_id,
            folder_name => $folder_name,
            folder_description => $folder_description,
            trial_type => $trial_type_name,
            year => $year,
            location_id => $location_id,
            location_name => $location_name,
            breeding_program_id => $breeding_program_id,
            breeding_program_name => $breeding_program_name,
            breeding_program_description => $breeding_program_description,
            project_harvest_date => $project_harvest_date,
            project_planting_date => $project_planting_date,
            design => $design
        };
        $total_count = $full_count;
    }
    $total_count = $total_count-$subtract_count;
    print STDERR Dumper \@result;

    return (\@result, $total_count);
}

1;
