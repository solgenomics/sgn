use strict;
use warnings;
use utf8;

use Test::More;
use SGN::Controller::AJAX::DecisionMeeting;

my $controller = SGN::Controller::AJAX::DecisionMeeting->new;

is(
    $controller->_normalize_meeting_date('2026-08-04'),
    '2026-08-04',
    'ISO meeting dates remain unchanged',
);
is(
    $controller->_normalize_meeting_date('2026/08/04'),
    '2026-08-04',
    'legacy slash-separated meeting dates are displayed in ISO format',
);
is(
    $controller->_normalize_meeting_date('2026-02-30'),
    '',
    'invalid calendar dates are rejected',
);

is_deeply(
    $controller->_configured_meeting_roles(
        [' curator, submitter ', 'CURATOR, breeder']
    ),
    ['curator', 'submitter', 'breeder'],
    'configured meeting attendee roles are trimmed and deduplicated',
);
is_deeply(
    $controller->_configured_meeting_roles(undef),
    [],
    'no meeting attendee roles are returned without configuration',
);

is_deeply(
    $controller->_meeting_program_names(
        { breeding_programs => ['101', '202', '101'] },
        { 101 => 'Program One', 202 => 'Program Two' },
    ),
    ['Program One', 'Program Two'],
    'all meeting programs are translated and deduplicated without truncation',
);
ok(
    !$controller->_is_meeting_saved({ saved => 'false' }),
    'a string false flag does not make an unsaved meeting immutable',
);
ok(
    $controller->_is_meeting_saved({ saved_status => 'successfully' }),
    'the persisted successful status identifies a saved meeting',
);

{
    package Local::DecisionMeeting::LocationRow;
    sub new { bless { description => $_[1] }, $_[0] }
    sub description { $_[0]->{description} }

    package Local::DecisionMeeting::LocationResultSet;
    sub new { bless { locations => $_[1] }, $_[0] }
    sub find {
        my ($self, $query) = @_;
        my $description = $query->{description};
        return unless defined($description) && exists($self->{locations}->{$description});
        return Local::DecisionMeeting::LocationRow->new($description);
    }
    sub search {
        my ($self, $query) = @_;
        my $description = $query->{description};
        my $row = defined($description) && exists($self->{locations}->{$description})
            ? Local::DecisionMeeting::LocationRow->new($description)
            : undef;
        return bless { row => $row }, 'Local::DecisionMeeting::LocationSearch';
    }

    package Local::DecisionMeeting::LocationSearch;
    sub first { return $_[0]->{row}; }

    package Local::DecisionMeeting::LocationSchema;
    sub new { bless { locations => $_[1] }, $_[0] }
    sub resultset {
        my ($self, $name) = @_;
        die "Unknown resultset $name" unless $name eq 'NaturalDiversity::NdGeolocation';
        return Local::DecisionMeeting::LocationResultSet->new($self->{locations});
    }
}

my $location_schema = Local::DecisionMeeting::LocationSchema->new({ BTI => 1 });
is(
    SGN::Controller::AJAX::DecisionMeeting::_resolve_location_name($location_schema, 'BTI'),
    'BTI',
    'configured meeting location resolves when it exists in the location table',
);
is(
    SGN::Controller::AJAX::DecisionMeeting::_resolve_location_name($location_schema, 'Not in database'),
    undef,
    'configured meeting location is rejected when it does not exist in the location table',
);

my $unicode_json = '{"date":"2026-08-04","attendees":["André Luis Hartmann Caranhato"]}';
my ($unicode_data, $unicode_error) = $controller->_decode_meeting_json($unicode_json);
is($unicode_error, '', 'meeting JSON accepts an already-decoded Unicode string');
is(
    $unicode_data->{attendees}->[0],
    'André Luis Hartmann Caranhato',
    'accented attendee names survive character-string JSON decoding',
);

my $utf8_json_bytes = $unicode_json;
utf8::encode($utf8_json_bytes);
my ($byte_data, $byte_error) = $controller->_decode_meeting_json($utf8_json_bytes);
is($byte_error, '', 'meeting JSON accepts UTF-8 bytes');
is(
    $byte_data->{attendees}->[0],
    'André Luis Hartmann Caranhato',
    'accented attendee names survive byte-string JSON decoding',
);

is_deeply(
    $controller->_meeting_tracker_metadata(
        'SuBR_2025-26_Y5',
        {
            meeting_name           => 'SuBR_2025-26_Y5',
            breeding_programs      => ['326'],
            breeding_program_names => ['SuBR'],
            date                   => '2026-08-04',
            year                   => '2026',
            location               => 'Uberlandia',
            location_raw           => '616',
            attendees              => [
                'Charles Hobi Zimmer',
                'André Luis Hartmann Caranhato',
            ],
        },
    ),
    {
        meeting_name      => 'SuBR_2025-26_Y5',
        meeting_programs  => 'SuBR',
        meeting_date      => '2026-08-04',
        meeting_year      => '2026',
        meeting_location  => 'Uberlandia',
        meeting_attendees => 'Charles Hobi Zimmer, André Luis Hartmann Caranhato',
    },
    'tracker metadata is populated directly from the saved meeting record',
);

is_deeply(
    $controller->_configured_meeting_locations(
        'test_location|Cornell Biotech|Santa Helena de Goias, GO'
    ),
    ['test_location', 'Cornell Biotech', 'Santa Helena de Goias, GO'],
    'meeting locations are read from a pipe-separated configuration value without splitting commas in names',
);
is_deeply(
    $controller->_configured_meeting_locations(
        'Santa Helena de Goias, GO|Chapeco'
    ),
    ['Santa Helena de Goias, GO', 'Chapeco'],
    'a comma in a location name is preserved before the next pipe-separated location',
);
is_deeply(
    $controller->_configured_meeting_locations(
        ['test_location|Cornell Biotech', 'Santa Helena de Goias, GO|TEST_LOCATION']
    ),
    ['test_location', 'Cornell Biotech', 'Santa Helena de Goias, GO'],
    'array configuration values are flattened and duplicate locations are removed',
);

my $meeting_data = {
    attendees              => ['Alice', 'Bob'],
    breeding_programs      => ['program-1', 'program-2'],
    breeding_program_names => ['Program One', 'Program Two'],
    date                   => '2026-08-04',
    location               => 'Field Station',
    meeting_status         => 'planned',
    year                   => '2026',
};

my $accessions = [
    {
        accession => 'ACC-1',
        decision  => 'advance',
        new_stage => 'T2',
    },
];

my $decision_data = {
    meeting_id    => 42,
    meeting_name  => 'August decisions',
    date          => 'different date from the client',
    attendees     => 'different attendees from the client',
    list_id       => 17,
    meeting_notes => 'Reviewed by the team',
    accessions    => $accessions,
};

my $merged = $controller->_merge_decisions_into_meeting(
    $meeting_data,
    $decision_data,
    'Tue Aug  4 12:00:00 2026',
);

is_deeply(
    $merged->{breeding_programs},
    $meeting_data->{breeding_programs},
    'saving decisions preserves breeding programs',
);
is_deeply(
    $merged->{breeding_program_names},
    $meeting_data->{breeding_program_names},
    'saving decisions preserves breeding program names',
);
is($merged->{date}, $meeting_data->{date}, 'saving decisions preserves the meeting date');
is($merged->{location}, $meeting_data->{location}, 'saving decisions preserves the location');
is($merged->{year}, $meeting_data->{year}, 'saving decisions preserves the year');
is_deeply(
    $merged->{attendees},
    $meeting_data->{attendees},
    'saving decisions preserves attendees and their representation',
);
is(
    $merged->{meeting_status},
    $meeting_data->{meeting_status},
    'saving decisions preserves meeting status',
);
is_deeply($merged->{accessions}, $accessions, 'decisions are added to the meeting');
is($merged->{list_id}, 17, 'the decision list is added to the meeting');
is($merged->{meeting_notes}, 'Reviewed by the team', 'decision meeting notes are added');
is($merged->{meeting_id}, 42, 'new non-conflicting report fields are retained');
ok($merged->{saved}, 'meeting is marked as saved');
is($merged->{saved_status}, 'successfully', 'successful save status is recorded');
is($merged->{saved_at}, 'Tue Aug  4 12:00:00 2026', 'save time is recorded');

done_testing();
