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
my $result = $trial_search->search();

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
    isa => 'ArrayRef[Int]|Undef',
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

has 'trial_name_is_exact' => (
    isa => 'Bool|Undef',
    is => 'rw',
    default => 0
);

has 'accession_list' => (
    isa => 'ArrayRef[Int]|Undef',
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

has 'sort_by' => (
    isa => 'Str|Undef',
    is => 'rw'
);

has 'order_by' => (
    isa => 'Str|Undef',
    is => 'rw'
);


sub search {
    my $self = shift;
    my $schema = $self->bcs_schema();
    my %program_list;
    if ($self->program_list){
        %program_list = map { $_ => 1} @{$self->program_list};
    }
	my %program_id_list;
    if ($self->program_id_list){
        %program_id_list = map { $_ => 1} @{$self->program_id_list};
    }
    my %location_list;
    if ($self->location_list){
        %location_list = map { $_ => 1} @{$self->location_list};
    }
	my %location_id_list;
    if ($self->location_id_list){
        %location_id_list = map { $_ => 1} @{$self->location_id_list};
    }
    my %year_list;
    if ($self->year_list){
        %year_list = map { $_ => 1} @{$self->year_list};
    }
    my %trial_type_list;
    if ($self->trial_type_list){
        %trial_type_list = map { $_ => 1} @{$self->trial_type_list};
    }
    my %trial_id_list;
    if ($self->trial_id_list){
        %trial_id_list = map { $_ => 1} @{$self->trial_id_list};
    }
    my %trial_name_list;
    my $trial_name_string;
    if ($self->trial_name_list){
        %trial_name_list = map { $_ => 1} @{$self->trial_name_list};
        foreach (@{$self->trial_name_list}){
            $trial_name_string .= $_;
        }
    }
    my %trial_design_list;
    if ($self->trial_design_list){
        %trial_design_list = map { $_ => 1} @{$self->trial_design_list};
    }
    my $trial_name_is_exact = $self->trial_name_is_exact;
    my $accession_list = $self->accession_list;
    my $trait_list = $self->trait_list;
    my $sort_by = $self->sort_by;
    my $order_by = $self->order_by;

    # pre-fetch some information; more efficient
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

    my %breeding_programs;
    my $breeding_program_rs = $schema->resultset("Project::Project")->search(
        {},
        {
            join =>
              { 'project_relationship_object_projects' => 'subject_project' },
            where => { type_id => $breeding_program_trial_relationship_id },
            select => [ 'me.name', 'me.project_id', 'subject_project.project_id' ],
            as     => [ 'breeding_program', 'breeding_program_id', 'trial_id' ]
        }
    );
    while ( my $row = $breeding_program_rs->next() ) {
        $breeding_programs{ $row->get_column('trial_id') } = [$row->get_column('breeding_program_id'), $row->get_column('breeding_program')];
    }

    my %folders;
    my $folder_rs = $schema->resultset("Project::Project")->search(
        {},
        {
            join =>
              { 'project_relationship_object_projects' => 'subject_project' },
            where => { type_id => $trial_folder_cvterm_id },
            select => [ 'me.name', 'me.project_id', 'subject_project.project_id' ],
            as     => [ 'folder', 'folder_id','trial_id' ]
        }
    );
    while ( my $row = $folder_rs->next() ) {
        $folders{ $row->get_column('trial_id') } = [$row->get_column('folder_id'), $row->get_column('folder')];
    }

    my %locations;
    my $location_rs = $schema->resultset("NaturalDiversity::NdGeolocation")->search( {} );
    while ( my $row = $location_rs->next() ) {
        $locations{ $row->nd_geolocation_id() } = $row->description();
    }

    my %project_where;
    if ($self->trial_has_tissue_samples){
        $project_where{'projectprops.type_id'} = $project_has_tissue_sample_entries;
    }

    my $trial_rs = $schema->resultset("Project::Project")->search(
        \%project_where,
        {
            join      => 'projectprops',
            '+select' => [ 'projectprops.type_id', 'projectprops.value' ],
            '+as'     => [ 'projectprop_type_id', 'projectprop_value' ]
        }
    );

    my @result;
    my %trials = ();

    while ( my $t = $trial_rs->next() ) {
        my $trial_id = $t->project_id();
        if ( $not_trials{$trial_id} ) {
            next;
        }
        my $trial_name = $t->name();

        $trials{$trial_name}->{trial_id} = $t->project_id();
        $trials{$trial_name}->{trial_description} = $t->description();

        my $type_id = $t->get_column('projectprop_type_id');
        my $value   = $t->get_column('projectprop_value');

        #print STDERR "READ: $trial_name, $type_id, $value\n";

        if ($type_id){
            if ( $type_id == $location_cvterm_id ) {
                $trials{$trial_name}->{location} = [$value, $locations{$value}];
            }
            if ( $type_id == $year_cvterm_id ) {
                $trials{$trial_name}->{year} = $value;
            }
            if ( $type_id == $design_cvterm_id ) {
                $trials{$trial_name}->{design} = $value;
            }
            if ( $type_id == $planting_cvterm_id ) {
                $trials{$trial_name}->{project_planting_date} = $calendar_funcs->display_start_date($value);
            }
            if ( $type_id == $harvest_cvterm_id ) {
                $trials{$trial_name}->{project_harvest_date} = $calendar_funcs->display_start_date($value);
            }

            if (exists($trial_types{$type_id})){
                $trials{$trial_name}->{trial_type} = $trial_types{$type_id};
            }
        }

        $trials{$trial_name}->{breeding_program} = $breeding_programs{$trial_id};
        $trials{$trial_name}->{folder} = $folders{$trial_id};
    }

    #print STDERR Dumper \%trials;

    foreach my $t ( sort( keys(%trials) ) ) {
		no warnings 'uninitialized';

        if (scalar(keys %location_list)>0){
            next
                unless ( exists( $location_list{$trials{$t}->{location}->[1]} ) );
        }
		if (scalar(keys %location_id_list)>0){
            next
                unless ( exists( $location_id_list{$trials{$t}->{location}->[0]} ) );
        }
        if (scalar(keys %program_list)>0){
            next
                unless ( exists( $program_list{$trials{$t}->{breeding_program}->[1]} ) );
        }
		if (scalar(keys %program_id_list)>0){
            next
                unless ( exists( $program_id_list{$trials{$t}->{breeding_program}->[0]} ) );
        }
        if (scalar(keys %year_list)>0){
            next
                unless ( exists( $year_list{$trials{$t}->{year}} ) );
        }
        if (scalar(keys %trial_type_list)>0){
            next
                unless ( exists( $trial_type_list{$trials{$t}->{trial_type}} ) );
        }
        if (scalar(keys %trial_id_list)>0){
            next
                unless ( exists( $trial_id_list{$trials{$t}->{trial_id}} ) );
        }
        if (scalar(keys %trial_name_list)>0){
            if ($self->trial_name_is_exact){
                next
                    unless ( exists( $trial_name_list{$t} ) );
            } else {
                next
                    unless ( index($trial_name_string, $t) != -1 );
            }
        }
        if (scalar(keys %trial_design_list)>0){
            next
                unless ( exists( $trial_design_list{$trials{$t}->{design}} ) );
        }

        if ($trials{$t}->{design} eq 'treatment'){
            next();
        }

        push @result, {
            trial_id => $trials{$t}->{trial_id},
            trial_name => $t,
            folder_id => $trials{$t}->{folder}->[0],
            folder_name => $trials{$t}->{folder}->[1],
            trial_type => $trials{$t}->{trial_type},
            year => $trials{$t}->{year},
            location_id => $trials{$t}->{location}->[0],
            location_name => $trials{$t}->{location}->[1],
            breeding_program_id => $trials{$t}->{breeding_program}->[0],
            breeding_program_name => $trials{$t}->{breeding_program}->[1],
            project_harvest_date => $trials{$t}->{project_harvest_date},
            project_planting_date => $trials{$t}->{project_planting_date},
            description => $trials{$t}->{trial_description},
            design => $trials{$t}->{design}
        };
    }

    return \@result;
}

1;
