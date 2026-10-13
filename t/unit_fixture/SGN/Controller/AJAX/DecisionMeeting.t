use strict;
use warnings;

use lib 't/lib';

use JSON qw(decode_json);
use SGN::Controller::AJAX::DecisionMeeting;
use SGN::Model::Cvterm;
use SGN::Test::Fixture;
use Test::More;

## no critic (Modules::RequireFilenameMatchesPackage)
{
    package Local::DecisionMeetingCreate::Person;

    sub new { return bless {}, $_[0]; }
    sub get_sp_person_id { return 41; }
    sub get_username     { return 'janedoe'; }

    package Local::DecisionMeetingCreate::User;

    sub new {
        my ($class, $person) = @_;
        return bless { person => $person }, $class;
    }

    sub get_object { return $_[0]->{person}; }
    sub roles      { return ('curator'); }

    package Local::DecisionMeetingCreate::Request;

    sub new {
        my ($class, $params) = @_;
        return bless { params => $params }, $class;
    }

    sub params    { return $_[0]->{params}; }
    sub body_data { return {}; }

    package Local::DecisionMeetingCreate::Response;

    sub new { return bless {}, $_[0]; }

    sub content_type {
        my ($self, $value) = @_;
        $self->{content_type} = $value if @_ > 1;
        return $self->{content_type};
    }

    sub body {
        my ($self, $value) = @_;
        $self->{body} = $value if @_ > 1;
        return $self->{body};
    }

    sub status {
        my ($self, $value) = @_;
        $self->{status} = $value if @_ > 1;
        return $self->{status};
    }

    package Local::DecisionMeetingCreate::Database;

    sub new {
        my ($class, $dbh) = @_;
        return bless { dbh => $dbh }, $class;
    }

    sub dbh { return $_[0]->{dbh}; }

    package Local::DecisionMeetingCreate::Log;

    sub new { return bless { errors => [] }, $_[0]; }
    sub error { push @{$_[0]->{errors}}, $_[1]; }

    package Local::DecisionMeetingCreate::Context;

    sub new {
        my ($class, %args) = @_;
        return bless \%args, $class;
    }

    sub user        { return $_[0]->{user}; }
    sub req         { return $_[0]->{request}; }
    sub res         { return $_[0]->{response}; }
    sub config      { return $_[0]->{config}; }
    sub dbc         { return $_[0]->{database}; }
    sub log         { return $_[0]->{log}; }
    sub dbic_schema { return $_[0]->{schema}; }
}
## use critic

my $fixture = SGN::Test::Fixture->new();
my $schema  = $fixture->bcs_schema;
my $dbh     = $fixture->dbh;

# The base fixture can predate db patch 00204. Keep this test runnable both
# before and after that patch by provisioning its required terms when needed.
my $meeting_cv = $schema->resultset('Cv::Cv')->find({ name => 'experiment_meeting' });
my $created_meeting_cv = !$meeting_cv;
$meeting_cv ||= $schema->resultset('Cv::Cv')->create({ name => 'experiment_meeting' });

my $meeting_project_type = $schema->resultset('Cv::Cvterm')->find({
    name  => 'meeting_project',
    cv_id => $meeting_cv->cv_id,
});
$meeting_project_type ||= $schema->resultset('Cv::Cvterm')->create_with({
    name => 'meeting_project',
    cv   => 'experiment_meeting',
});

my $project_property_cv = $schema->resultset('Cv::Cv')->find({ name => 'project_property' });
my $meeting_json_fixture_type = $schema->resultset('Cv::Cvterm')->find({
    name  => 'meeting_json',
    cv_id => $project_property_cv->cv_id,
});
$meeting_json_fixture_type ||= $schema->resultset('Cv::Cvterm')->create_with({
    name => 'meeting_json',
    cv   => 'project_property',
});

my $program = $schema->resultset('Project::Project')->find({ name => 'test' });
ok($program, 'fixture breeding program exists');

my $location = $schema->resultset('NaturalDiversity::NdGeolocation')->find({
    description => 'test_location',
});
ok($location, 'fixture meeting location exists');

my $meeting_name = join('_', 'decision_meeting_create_test', time, $$);
my $response = Local::DecisionMeetingCreate::Response->new();
my $context = Local::DecisionMeetingCreate::Context->new(
    user     => Local::DecisionMeetingCreate::User->new(
        Local::DecisionMeetingCreate::Person->new(),
    ),
    request  => Local::DecisionMeetingCreate::Request->new({
        meeting_name     => $meeting_name,
        breeding_program => $program->project_id,
        location         => $location->description,
        year             => '2026',
        date             => '2026-08-04',
        data             => 'Decision meeting creation unit test',
        attendees        => 'Jane Doe,John Example',
    }),
    response => $response,
    config   => { decision_role => 'curator' },
    database => Local::DecisionMeetingCreate::Database->new($dbh),
    schema   => $schema,
    log      => Local::DecisionMeetingCreate::Log->new(),
);

my $controller = SGN::Controller::AJAX::DecisionMeeting->new();
$controller->create($context);

my $created = decode_json($response->body || '{}');
ok($created->{ok}, 'decision meeting create action succeeds');
ok($created->{project_id}, 'create action returns the meeting project ID');

my $project = $schema->resultset('Project::Project')->find({
    project_id => $created->{project_id},
});
ok($project, 'decision meeting project was created');
is($project->name, $meeting_name, 'decision meeting project has the requested name');

my $design_type = SGN::Model::Cvterm->get_cvterm_row(
    $schema,
    'design',
    'project_property',
);
my $design_prop = $project->search_related('projectprops', {
    type_id => $design_type->cvterm_id,
})->first;
is($design_prop->value, 'Meeting', 'project is marked as a Meeting design');

my $meeting_json_type = SGN::Model::Cvterm->get_cvterm_row(
    $schema,
    'meeting_json',
    'project_property',
);
my $meeting_prop = $project->search_related('projectprops', {
    type_id => $meeting_json_type->cvterm_id,
})->first;
ok($meeting_prop, 'meeting JSON metadata was created');

my $meeting_data = decode_json($meeting_prop->value);
is($meeting_data->{meeting_name}, $meeting_name, 'meeting name is stored in its metadata');
is(
    $meeting_data->{meeting_notes},
    'Decision meeting creation unit test',
    'meeting description is retained as meeting notes',
);
is($meeting_data->{date}, '2026-08-04', 'meeting date is stored in ISO format');
is($meeting_data->{year}, '2026', 'meeting year is stored');
is($meeting_data->{location}, 'test_location', 'meeting location is stored');
is_deeply(
    $meeting_data->{breeding_programs},
    ["" . $program->project_id],
    'meeting breeding program IDs are stored canonically',
);
is_deeply(
    $meeting_data->{breeding_program_names},
    ['test'],
    'meeting breeding program metadata is stored',
);
is_deeply(
    $meeting_data->{attendees},
    ['Jane Doe', 'John Example'],
    'meeting attendees are stored',
);

my $program_relationship_type = SGN::Model::Cvterm->get_cvterm_row(
    $schema,
    'breeding_program_trial_relationship',
    'project_relationship',
);
my $program_relationship = $schema->resultset('Project::ProjectRelationship')->find({
    subject_project_id => $project->project_id,
    type_id            => $program_relationship_type->cvterm_id,
});
ok($program_relationship, 'meeting is linked to its breeding program');
is(
    $program_relationship->object_project_id,
    $program->project_id,
    'meeting links to the selected breeding program',
);

my @experiment_ids = $schema->resultset('NaturalDiversity::NdExperimentProject')
    ->search({ project_id => $project->project_id })
    ->get_column('nd_experiment_id')
    ->all;
is(scalar(@experiment_ids), 1, 'meeting has one project-level experiment');

my $experiment = $schema->resultset('NaturalDiversity::NdExperiment')->find({
    nd_experiment_id => $experiment_ids[0],
});
is(
    $experiment->nd_geolocation_id,
    $location->nd_geolocation_id,
    'meeting experiment uses the selected database location',
);

my $experiment_stock_count = $schema
    ->resultset('NaturalDiversity::NdExperimentStock')
    ->search({ nd_experiment_id => { -in => \@experiment_ids } })
    ->count;
is($experiment_stock_count, 0, 'meeting is created without plots or accessions');

$fixture->clean_up_db();
$meeting_cv->delete() if $created_meeting_cv;

done_testing();
