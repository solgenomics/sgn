use strict;
use warnings;

use lib 't/lib';

use JSON qw(decode_json encode_json);
use SGN::Controller::AJAX::DecisionMeeting;
use SGN::Model::Cvterm;
use SGN::Test::Fixture;
use Test::More;

## no critic (Modules::RequireFilenameMatchesPackage)
{
    package Local::DecisionMeetingStage::Person;
    sub new { return bless {}, $_[0]; }
    sub get_sp_person_id { return 41; }

    package Local::DecisionMeetingStage::User;
    sub new { return bless { person => $_[1] }, $_[0]; }
    sub get_object { return $_[0]->{person}; }
    sub roles { return ('curator'); }

    package Local::DecisionMeetingStage::Request;
    sub new { return bless { data => $_[1] }, $_[0]; }
    sub data { return $_[0]->{data}; }

    package Local::DecisionMeetingStage::Database;
    sub new { return bless { dbh => $_[1] }, $_[0]; }
    sub dbh { return $_[0]->{dbh}; }

    package Local::DecisionMeetingStage::Context;
    sub new { my ($class, %args) = @_; return bless \%args, $class; }
    sub user { return $_[0]->{user}; }
    sub req { return $_[0]->{request}; }
    sub config { return $_[0]->{config}; }
    sub dbc { return $_[0]->{database}; }
    sub dbic_schema { return $_[0]->{schema}; }
    sub stash {
        my ($self, %values) = @_;
        $self->{stash} = { %{ $self->{stash} || {} }, %values };
        return $self->{stash};
    }
}
## use critic

my $fixture = SGN::Test::Fixture->new();
my $schema  = $fixture->bcs_schema;

my $controller = SGN::Controller::AJAX::DecisionMeeting->new();

is(
    $controller->_breeding_stage_property_name(
        'SuBR',
        'BTI|BTI_Stage,Cornell|Cornell_Stage',
    ),
    'SuBR_Stage',
    'an unmapped breeding program falls back to its conventional stage property',
);
is(
    $controller->_breeding_stage_property_name(
        'BTI',
        'BTI|custom_bti_stage,Cornell|Cornell_Stage',
    ),
    'custom_bti_stage',
    'a configured breeding-program stage property takes precedence',
);

my $stage_cvterm = SGN::Model::Cvterm->get_cvterm_row(
    $schema,
    'SuBR_Stage',
    'stock_property',
);
$stage_cvterm ||= $schema->resultset('Cv::Cvterm')->create_with({
    name => 'SuBR_Stage',
    cv   => 'stock_property',
});

my $accession_type = SGN::Model::Cvterm->get_cvterm_row(
    $schema,
    'accession',
    'stock_type',
);
my $organism = $schema->resultset('Organism::Organism')->first;

my $stock_suffix = join('_', time, $$);
my $existing_stock = $schema->resultset('Stock::Stock')->create({
    organism_id => $organism->organism_id,
    name        => 'decision_stage_existing_' . $stock_suffix,
    uniquename  => 'decision_stage_existing_' . $stock_suffix,
    type_id     => $accession_type->cvterm_id,
});
my $existing_prop = $schema->resultset('Stock::Stockprop')->create({
    stock_id => $existing_stock->stock_id,
    type_id  => $stage_cvterm->cvterm_id,
    value    => 'ON-25-Y5',
    rank     => 0,
});

$controller->_update_breeding_stage_stockprop(
    schema           => $schema,
    stock_id         => $existing_stock->stock_id,
    breeding_program => 'SuBR',
    new_stage        => 'ON-26-PRECOMMERCIAL',
);
$existing_prop->discard_changes;

is(
    $existing_prop->value,
    'ON-26-PRECOMMERCIAL',
    'saving a decision updates the existing breeding-stage stock property',
);

my $drop_transition = $controller->_compute_stage_transition_data(
    current_stage   => 'ON-25-Y2',
    decision        => 'drop',
    year            => '25',
    meeting_date    => '2026-08-04',
    stock_id        => $existing_stock->stock_id,
    decision_format => 'state,year yy,stage',
    breeding_stages => 'Y1,Y2,Y3,Y4,Y5',
    schema          => $schema,
);
is(
    $drop_transition->{new_stage},
    'DROP-26-Y2',
    'DROP uses the selected meeting year instead of the previous stage year',
);

my $meeting_json_type = SGN::Model::Cvterm->get_cvterm_row(
    $schema,
    'meeting_json',
    'project_property',
);
$meeting_json_type ||= $schema->resultset('Cv::Cvterm')->create_with({
    name => 'meeting_json',
    cv   => 'project_property',
});
my $meeting = $schema->resultset('Project::Project')->create({
    name        => 'decision_stage_meeting_' . $stock_suffix,
    description => 'Decision meeting breeding-stage save test',
});
my $meeting_prop = $schema->resultset('Project::Projectprop')->create({
    project_id => $meeting->project_id,
    type_id    => $meeting_json_type->cvterm_id,
    value      => encode_json({
        meeting_name           => $meeting->name,
        date                   => '2026-08-04',
        breeding_program_names => ['test'],
    }),
    rank       => 0,
});

my $fixture_program = $schema->resultset('Project::Project')->find({ name => 'test' });
ok($fixture_program, 'fixture breeding program exists');

my $fixture_stage_cvterm = SGN::Model::Cvterm->get_cvterm_row(
    $schema,
    'test_Stage',
    'stock_property',
);
$fixture_stage_cvterm ||= $schema->resultset('Cv::Cvterm')->create_with({
    name => 'test_Stage',
    cv   => 'stock_property',
});
$schema->resultset('Stock::Stockprop')->create({
    stock_id => $existing_stock->stock_id,
    type_id  => $fixture_stage_cvterm->cvterm_id,
    value    => 'ON-25-Y5',
    rank     => 0,
});
my $state_cvterm = SGN::Model::Cvterm->get_cvterm_row(
    $schema,
    'state',
    'stock_property',
);
$state_cvterm ||= $schema->resultset('Cv::Cvterm')->create_with({
    name => 'state',
    cv   => 'stock_property',
});
$schema->resultset('Stock::Stockprop')->create({
    stock_id => $existing_stock->stock_id,
    type_id  => $state_cvterm->cvterm_id,
    value    => 'ON',
    rank     => 0,
});

my $accessions_list_type = SGN::Model::Cvterm->get_cvterm_row(
    $schema,
    'accessions',
    'list_types',
);
my ($list_id) = $schema->storage->dbh->selectrow_array(
    q{
        INSERT INTO sgn_people.list (name, description, owner, type_id)
        VALUES (?, ?, ?, ?)
        RETURNING list_id
    },
    undef,
    'decision_stage_list_' . $stock_suffix,
    'Decision meeting save validation list',
    41,
    $accessions_list_type->cvterm_id,
);
$schema->storage->dbh->do(
    'INSERT INTO sgn_people.list_item (content, list_id) VALUES (?, ?)',
    undef,
    $existing_stock->uniquename,
    $list_id,
);

my $save_payload = {
    meeting_id => $meeting->project_id,
    list_id    => $list_id,
    accessions => [{
        stock_id         => 999999,
        accession        => $existing_stock->uniquename,
        breeding_program => 'test',
        previous_stage   => 'ON-25-Y5',
        decision         => 'hold',
        new_stage        => 'ON-26-Y5',
    }],
};
my $save_context = Local::DecisionMeetingStage::Context->new(
    user    => Local::DecisionMeetingStage::User->new(
        Local::DecisionMeetingStage::Person->new(),
    ),
    request => Local::DecisionMeetingStage::Request->new($save_payload),
    database => Local::DecisionMeetingStage::Database->new($schema->storage->dbh),
    config  => {
        decision_role       => 'curator',
        decision_format     => 'state,year yy,stage',
        breeding_stages     => 'Y1,Y2,Y3,Y4,Y5',
        saved_program_stage => 'BTI|BTI_Stage,Cornell|Cornell_Stage',
    },
    schema  => $schema,
);

$controller->save_all_decisions_POST($save_context);
$existing_prop->discard_changes;
$meeting_prop->discard_changes;

is(
    $schema->resultset('Stock::Stockprop')->search({
        stock_id => $existing_stock->stock_id,
        type_id  => $fixture_stage_cvterm->cvterm_id,
    })->first->value,
    'ON-26-Y5',
    'the save-all-decisions action updates the program breeding stage',
);
is(
    decode_json($meeting_prop->value)->{accessions}->[0]->{new_stage},
    'ON-26-Y5',
    'the decision payload is saved with the stock-property update',
);
is(
    decode_json($meeting_prop->value)->{accessions}->[0]->{stock_id},
    $existing_stock->stock_id,
    'the server replaces a forged stock ID with the accession list stock ID',
);
ok(
    $save_context->{stash}->{json_data}->{success},
    'the save-all-decisions action reports success',
);

my $new_stock = $schema->resultset('Stock::Stock')->create({
    organism_id => $organism->organism_id,
    name        => 'decision_stage_new_' . $stock_suffix,
    uniquename  => 'decision_stage_new_' . $stock_suffix,
    type_id     => $accession_type->cvterm_id,
});

my $new_prop = $controller->_update_breeding_stage_stockprop(
    schema           => $schema,
    stock_id         => $new_stock->stock_id,
    breeding_program => 'SuBR',
    new_stage        => 'DROP-26-Y5',
);

is(
    $new_prop->value,
    'DROP-26-Y5',
    'saving a decision creates the breeding-stage stock property when absent',
);
is(
    $schema->resultset('Stock::Stockprop')->search({
        stock_id => $new_stock->stock_id,
        type_id  => $stage_cvterm->cvterm_id,
    })->count,
    1,
    'only one breeding-stage stock property is created',
);

$fixture->clean_up_db();

done_testing();
