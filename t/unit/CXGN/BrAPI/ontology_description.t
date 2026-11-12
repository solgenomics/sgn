use strict;
use warnings;

package main;  # the mock classes below are declared inside this test
use Test::More;
use JSON qw(encode_json);
use CXGN::BrAPI::v1::ObservationVariables;
use CXGN::BrAPI::v2::ObservationVariables;

# The /ontologies handlers read the root dbxref.description, which is free
# text in Chado. It must not be treated as trusted JSON: plain text, a JSON
# array, scalar or null, or malformed JSON must all give empty metadata
# instead of dying.

{
    package Fake::Cvterm;
    sub cvterm_id { 123 }
    package Fake::Schema;
    sub storage { bless {description => $_[0]->{description}}, 'Fake::Storage' }
    package Fake::Storage;
    sub dbh { bless {description => $_[0]->{description}}, 'Fake::DBH' }
    package Fake::DBH;
    sub prepare {
        my ($self, $query) = @_;
        return bless {description => $self->{description}, namespace => scalar($query =~ /SELECT distinct\(db\.name\)/i)}, 'Fake::Statement';
    }
    package Fake::Statement;
    sub execute { $_[0]->{returned} = 0; 1 }
    sub fetchrow_array {
        my $self = shift;
        return if $self->{returned}++;
        return ('TEST') if $self->{namespace};
        return (1, 'Test trait ontology', 'Root definition', 'TEST', 4242,
                '0000000', '2026', $self->{description},
                10, 'test_cv', 'Test CV');
    }
}

my @cases = (
    ['plain text',      'An ordinary description', ''],
    ['JSON object',     encode_json({authors=>'Team', copyright=>'ACME', licence=>'CC0'}), 'Team'],
    ['JSON array',      '["not","an object"]', ''],
    ['JSON scalar',     '42', ''],
    ['JSON null',       'null', ''],
    ['malformed JSON',  '{broken', ''],
    ['empty string',    '', ''],
    ['undef',           undef, ''],
);

for my $version ('v1', 'v2') {
    for my $case (@cases) {
        subtest "$version: $case->[0]" => sub {
            no warnings 'redefine';
            local *SGN::Model::Cvterm::get_cvterm_row = sub { bless {}, 'Fake::Cvterm' };
            my $api = bless {
                bcs_schema => bless({description=>$case->[1]}, 'Fake::Schema'),
                page_size => 25, page => 0, status => [],
            }, "CXGN::BrAPI::${version}::ObservationVariables";
            my $result = eval { $api->observation_variable_ontologies({
                name_spaces => $version eq 'v1' ? [] : ['TEST'],
                cvprop_type_names => ['trait_ontology'],
            }) };
            ok(!$@, 'handler returns without dying') or diag($@);
            return unless $result;
            my $rows = $result->{result}->{data};
            is(ref($rows), 'ARRAY', 'response has a data array');
            is(scalar(@$rows), 1, 'the ontology row is returned');
            is($rows->[0]->{ontologyDbId}, '4242', 'ontology identity is kept');
            is($rows->[0]->{authors}, $case->[2], 'authors metadata has the expected value');
            if ($case->[0] eq 'JSON object') {
                is($rows->[0]->{copyright}, 'ACME', 'copyright is read from the JSON object');
                is($rows->[0]->{licence}, 'CC0', 'licence is read from the JSON object');
            }
        };
    }
}

done_testing();
