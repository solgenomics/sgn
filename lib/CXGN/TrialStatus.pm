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
use JSON;
use Data::Dumper;
use SGN::Model::Cvterm;


has 'latest_trial_activity' => (isa => 'Str', is => 'rw');

has 'trial_activities' => (isa => 'Str', is => 'rw');

sub BUILD {
    my $self = shift;
    my $args = shift;

    $self->prop_table('projectprop');
    $self->prop_namespace('Project::Projectprop');
    $self->prop_primary_key('projectprop_id');
    $self->prop_type('trial_status_json');
    $self->cv_name('project_property');
    $self->allowed_fields([ qw | latest_trial_activity trial_activities | ]);
    $self->parent_table('project');
    $self->parent_primary_key('project_id');

    $self->load();
}

sub get_trial_activities {
    my $self = shift;
    my $schema = $self->bcs_schema();
    my $project_id = $self->parent_id();
    my $type = $self->prop_type();
    my $type_id = $self->_prop_type_id();
    my $key_ref = $self->allowed_fields();
    my @fields = @$key_ref;

    my $trial_activities_rs = $schema->resultset("Project::Projectprop")->find({ project_id => $project_id, type_id => $type_id });

    my @all_trial_activities;
    if ($trial_activities_rs) {
        my $activities_json = $trial_activities_rs->value();
        my $activities_hash = JSON::Any->jsonToObj($activities_json);
        my $all_activities_json = $activities_hash->{'trial_activities'};
        my $all_activities = decode_json $all_activities_json;
        my %activities_hash = %{$all_activities};
        foreach my $activity (keys %activities_hash) {
            my $user_id = $activities_hash{$activity}{'user_id'};
            my $timestamp = $activities_hash{$activity}{'timestamp'};
            push @all_trial_activities, [$activity, $timestamp, $user_id];
        }
    }

    return \@all_trial_activities;
}



1;
