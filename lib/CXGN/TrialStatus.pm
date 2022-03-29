package CXGN::TrialStatus;


=head1 NAME

CXGN::TrialStatus - a class to record trial status

=head1 DESCRIPTION

The projectprop of type "trial_status_json" is stored as JSON.

=head1 EXAMPLE

my $trial_status = CXGN::TrialStatus->new( { schema => $schema});

=head1 AUTHOR

Titima Tantikanjana <tt15@cornell.edu>

=cut


use Moose;

extends 'CXGN::JSONProp';

use JSON::Any;
use Data::Dumper;
use SGN::Model::Cvterm;

has 'trial_activities' => (isa => 'Str', is => 'rw');

has 'activity_list' => (isa => 'ArrayRef', is => 'rw');


sub BUILD {
    my $self = shift;
    my $args = shift;

    $self->prop_table('projectprop');
    $self->prop_namespace('Project::Projectprop');
    $self->prop_primary_key('projectprop_id');
    $self->prop_type('trial_status_json');
    $self->cv_name('project_property');
    $self->allowed_fields([ qw | trial_activities | ]);
    $self->parent_table('project');
    $self->parent_primary_key('project_id');

    $self->load();
}

sub get_trial_activities {
    my $self = shift;
    my $schema = $self->bcs_schema();
    my $people_schema = $self->people_schema();
    my $project_id = $self->parent_id();
    my $type = $self->prop_type();
    my $type_id = $self->_prop_type_id();
    my $activity_list = $self->activity_list();
    my @activities = @$activity_list;
    my $key_ref = $self->allowed_fields();
    my @fields = @$key_ref;

    my $trial_activities_rs = $schema->resultset("Project::Projectprop")->find({ project_id => $project_id, type_id => $type_id });
    my @all_trial_activities;
    if ($trial_activities_rs) {
        my $user_id;
        my $activity_date;
        my $person;
        my $person_name;
        my $activities_json = $trial_activities_rs->value();
        my $activities_hash = JSON::Any->jsonToObj($activities_json);
        my $all_activities_json = $activities_hash->{'trial_activities'};
        my $all_activities = JSON::Any->jsonToObj($all_activities_json);
        my %activities_hash = %{$all_activities};
        if ($activities_hash{'Trial Created'}) {
            $user_id = $activities_hash{'Trial Created'}{'user_id'};
            $activity_date = $activities_hash{'Trial Created'}{'activity_date'};
            $person = $people_schema->resultset("SpPerson")->find( { sp_person_id => $user_id } );
            $person_name = $person->first_name." ".$person->last_name();
            push @all_trial_activities, ['Trial Created', $activity_date, $person_name];
        } elsif ($activities_hash{'Trial Uploaded'}) {
            $user_id = $activities_hash{'Trial Uploaded'}{'user_id'};
            $activity_date = $activities_hash{'Trial Uploaded'}{'activity_date'};
            $person = $people_schema->resultset("SpPerson")->find( { sp_person_id => $user_id } );
            $person_name = $person->first_name." ".$person->last_name();
            push @all_trial_activities, ['Trial Uploaded', $activity_date, $person_name];
        }

        foreach my $activity_type (@activities) {
            if ($activities_hash{$activity_type}) {
                $user_id = $activities_hash{$activity_type}{'user_id'};
                $activity_date = $activities_hash{$activity_type}{'activity_date'};
                $person = $people_schema->resultset("SpPerson")->find( { sp_person_id => $user_id } );
                $person_name = $person->first_name." ".$person->last_name();
                push @all_trial_activities, [$activity_type, $activity_date, $person_name];
            } else {
                push @all_trial_activities, [$activity_type, 'NA', 'NA']
            }
        }
    }

    return \@all_trial_activities;
}


sub get_latest_activity {

    my $self = shift;
    my $schema = $self->bcs_schema();
    my $project_id = $self->parent_id();
    my $type = $self->prop_type();
    my $type_id = $self->_prop_type_id();

    my $row = $self->bcs_schema->resultset('Project::Projectprop')->find({
        project_id => $project_id,
        type_id => $type_id,
    });

    my $activity_list = $self->activity_list();
    my @activity_array = @$activity_list;
    my @reverse_activities = reverse@activity_array;
    push @reverse_activities, ("Trial Created", "Trial Uploaded");
    my $latest_trial_activity;

    if ($row) {
        my $trial_activity_json = $row->value();
        my $activity_hash_ref =  JSON::Any->jsonToObj($trial_activity_json);
        my %activity_hash = %{$activity_hash_ref};
        my $activity_json =  $activity_hash{'trial_activities'};
        my $activity_ref = JSON::Any->jsonToObj($activity_json);
        my %activities_hash = %{$activity_ref};

        foreach my $activity_type (@reverse_activities) {
            if ($activities_hash{$activity_type}) {
                my $activity_date = $activities_hash{$activity_type}{'activity_date'};
                $latest_trial_activity = $activity_type." : ".$activity_date;
                last;
            }
        }
    }

    return $latest_trial_activity
}


1;
