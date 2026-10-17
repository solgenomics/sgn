=head1 NAME

t/unit_mech/AJAX/Search/Treatment.t - treatment search without a selected ontology

=head1 DESCRIPTION

With no ontology ticked on the treatment search page, /ajax/search/treatments
must search the treatment ontologies only, and not list trait variables.

=cut

use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use JSON;
use CXGN::Trait::Treatment;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;

# create a treatment here, then delete it at end of test
my $treatment = CXGN::Trait::Treatment->new({
    bcs_schema => $schema,
    name => 'treatment search test treatment',
    definition => 'A dummy treatment object to test the treatment search.',
    format => 'numeric'
});
$treatment->store(encode_json(['Experimental treatment ontology|EXPERIMENT_TREATMENT:0000000']));
my $treatment_id = $treatment->cvterm_id();

my $mech = Test::WWW::Mechanize->new;

$mech->post_ok('http://localhost:3010/ajax/search/treatments?length=10000&start=0');
my $response = decode_json $mech->content;
my @rows = @{$response->{data}};

ok((grep { $_->[3] =~ m{/cvterm/$treatment_id/view} } @rows), 'the new treatment is found');

my @not_treatments = grep { $_ !~ /^(?:EXPERIMENT_TREATMENT|COMP_EXP_TREATMENT):/ } map { $_->[7] } @rows;
is_deeply(\@not_treatments, [], 'only treatment ontology terms are listed when no ontology is selected');

$f->clean_up_db();

done_testing();
