use strict;
use warnings;
use Test::More;
use lib 't/lib';
use SGN::Test::Fixture;
use SGN::Test::WWW::Mechanize skip_cgi => 1;
use JSON qw(decode_json);

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema();

my $trial_rs = $schema->resultset('Project::Project')->find({ name => 'Kasese solgs trial' });
ok($trial_rs, 'fixture provides a trial for selection index testing');
my $trial_id = $trial_rs ? $trial_rs->project_id : undef;

my $mech = SGN::Test::WWW::Mechanize->new;

$mech->post_ok('/brapi/v1/token', [ "username" => "janedoe", "password" => "secretpw", "grant_type" => "password" ], 'login');

$mech->get_ok('/selection/index');
$mech->content_like(qr/Build a Selection Index/, 'selection index page title renders');
$mech->content_like(qr/selection_index_workflow/, 'workflow container present');
$mech->content_like(qr/trial_dual_wrapper/, 'trial selection UI present');
$mech->content_like(qr/calculate_rankings_button/, 'calculate rankings button present');
$mech->content_like(qr/selection_index_error_dialog/, 'error modal present');
$mech->content_like(qr/sin_save_choice_modal/, 'save choice modal present');

if ($trial_id) {
    $mech->get_ok("/ajax/breeders/trial/$trial_id/traits_assayed");
    my $traits_response = decode_json $mech->content;
    ok($traits_response->{traits_assayed} && @{$traits_response->{traits_assayed}->[0]} > 0, 'traits assayed returns results');

    my @trait_ids = map { $_->[0] } @{$traits_response->{traits_assayed}->[0] || []};
    ok(@trait_ids > 0, 'trait ids extracted');

    $mech->post_ok(
        '/ajax/breeder/search/avg_phenotypes',
        [
            'trial_id' => $trial_id,
            'trait_ids[]' => $trait_ids[0],
            'coefficients[]' => 1,
            'controls[]' => '',
            'allow_missing' => 1
        ]
    );
    my $avg_response = decode_json $mech->content;
    ok(!$avg_response->{error}, 'avg phenotype response has no error');
    ok($avg_response->{raw_avg_values}, 'avg phenotype raw values returned');
    ok($avg_response->{weighted_values}, 'avg phenotype weighted values returned');
}

done_testing();
