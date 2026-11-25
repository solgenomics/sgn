
=head1 NAME

t/unit_mech/AJAX/BreedersToolbox/RemoveFillerPlots.t - removing filler plots requires trial edit privileges

=head1 DESCRIPTION

/ajax/breeders/trial/<id>/remove_fillers deletes the plots of a trial that
carry the filler_plot stock property. Like the other actions that modify a
trial, it must only work for a curator or a submitter in the trial's
breeding program.

=cut

use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use JSON;
use CXGN::People::Login;
use CXGN::People::Person;
use SGN::Model::Cvterm;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema();
my $people_dbh = $f->people_schema->storage->dbh();

my $trial = $schema->resultset('Project::Project')->find({ name => 'test_trial' });
ok($trial, 'fixture trial test_trial exists');
my $trial_id = $trial->project_id();
my $url = "http://localhost:3010/ajax/breeders/trial/$trial_id/remove_fillers";

my $plot_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id();
my $filler_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'filler_plot', 'stock_property')->cvterm_id();
my $field_layout_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'field_layout', 'experiment_type')->cvterm_id();

my $layout_experiment = $schema->resultset('NaturalDiversity::NdExperiment')->search(
    { 'nd_experiment_projects.project_id' => $trial_id, 'me.type_id' => $field_layout_type_id },
    { join => 'nd_experiment_projects' }
)->first();
ok($layout_experiment, 'trial has a field layout experiment');

my $existing_plot = $schema->resultset('Stock::Stock')->search(
    { 'nd_experiment_stocks.nd_experiment_id' => $layout_experiment->nd_experiment_id(), 'me.type_id' => $plot_type_id },
    { join => 'nd_experiment_stocks', order_by => 'me.stock_id' }
)->first();
ok($existing_plot, 'trial has plots');
my $plot_count_before = plot_count();

# A new plot in the trial, marked as filler. The test removes only this plot,
# so the fixture plots stay as they are.
#
my $filler_plot = $schema->resultset('Stock::Stock')->create({
    organism_id => $existing_plot->organism_id(),
    name => 'remove_fillers_test_plot',
    uniquename => 'remove_fillers_test_plot',
    type_id => $plot_type_id,
});
$filler_plot->create_related('stockprops', { type_id => $filler_type_id, value => 1, rank => 0 });
$filler_plot->create_related('nd_experiment_stocks', {
    nd_experiment_id => $layout_experiment->nd_experiment_id(),
    type_id => $field_layout_type_id,
});
my $filler_plot_id = $filler_plot->stock_id();

sub plot_exists {
    return $schema->resultset('Stock::Stock')->search({ stock_id => $filler_plot_id })->count();
}

sub plot_count {
    return $schema->resultset('Stock::Stock')->search(
        { 'nd_experiment_stocks.nd_experiment_id' => $layout_experiment->nd_experiment_id(), 'me.type_id' => $plot_type_id },
        { join => 'nd_experiment_stocks', distinct => 1 }
    )->count();
}

ok(plot_exists(), 'filler plot is created');

# anonymous request
#
my $mech = Test::WWW::Mechanize->new(autocheck => 0);
$mech->post($url);
my $response = decode_json($mech->content);
like($response->{error}, qr/Login required/, 'anonymous request is refused');
ok(!$response->{success}, 'anonymous request does not report success');
ok(plot_exists(), 'filler plot still exists after the anonymous request');

# a logged-in submitter who is not a curator and not in the trial's breeding program
#
my $password = 'secretpw1';
my $login = CXGN::People::Login->new($people_dbh);
$login->set_username('remove_fillers_submitter');
$login->set_private_email('remove_fillers_submitter@example.com');
$login->store();
$login->update_password($password);
my $person = CXGN::People::Person->new($people_dbh, $login->get_sp_person_id());
$person->set_first_name('Test');
$person->set_last_name('Submitter');
$person->store();
$login->add_role('submitter');
my $submitter_id = $login->get_sp_person_id();

my $submitter_mech = Test::WWW::Mechanize->new(autocheck => 0);
$submitter_mech->post_ok('http://localhost:3010/ajax/user/login', [ username => 'remove_fillers_submitter', password => $password ]);
is(decode_json($submitter_mech->content)->{message}, 'Login successful', 'submitter outside the program logs in');
$submitter_mech->post($url);
$response = decode_json($submitter_mech->content);
like($response->{error}, qr/insufficient privileges/, 'submitter outside the breeding program is refused');
ok(!$response->{success}, 'submitter request does not report success');
ok(plot_exists(), 'filler plot still exists after the submitter request');

# a curator
#
my $curator_mech = Test::WWW::Mechanize->new(autocheck => 0);
$curator_mech->post_ok('http://localhost:3010/ajax/user/login', [ username => 'janedoe', password => 'secretpw' ]);
is(decode_json($curator_mech->content)->{message}, 'Login successful', 'curator logs in');
$curator_mech->post_ok($url, 'curator request');
$response = decode_json($curator_mech->content);
is_deeply($response, { success => 1, deleted => 1 }, 'curator removes the filler plot');
ok(!plot_exists(), 'filler plot is deleted');
is(plot_count(), $plot_count_before, 'the other plots of the trial are kept');

# clean up
#
$schema->resultset('Stock::Stock')->search({ stock_id => $filler_plot_id })->delete();
$people_dbh->do("DELETE FROM sgn_people.sp_token WHERE sp_person_id=?", undef, $submitter_id);
CXGN::People::Person->new($people_dbh, $submitter_id)->hard_delete();

done_testing();
