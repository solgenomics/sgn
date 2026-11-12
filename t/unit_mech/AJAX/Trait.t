
use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;

use Data::Dumper;
use JSON;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema();

my $mech = Test::WWW::Mechanize->new;
my $response;

my $trait_ontology_db_name = "CO_334";
my $new_trait_name = "ajax unit test trait";
my $new_trait_definition = "A fake numeric trait created by the AJAX unit test to check that the trait designer can store new traits.";
my $edited_trait_definition = "An edited definition for the fake numeric trait created by the AJAX unit test.";

# login as a curator, since designing traits is curator only
#
$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ], 'login with brapi call');

$response = decode_json $mech->content;

is($response->{'userDisplayName'}, 'Jane Doe', 'check login name');

sleep(1);

# figure out which cv the trait ontology lives in, so that we can check that the new term is stored in it
#
my $get_trait_cv_id_sql = "SELECT DISTINCT cvterm.cv_id FROM cvterm
JOIN dbxref USING (dbxref_id)
JOIN db USING (db_id)
JOIN cvprop ON (cvterm.cv_id = cvprop.cv_id)
JOIN cvterm AS prop_type ON (cvprop.type_id = prop_type.cvterm_id)
WHERE db.name = ? AND prop_type.name = 'trait_ontology'";

my $h = $schema->storage->dbh->prepare($get_trait_cv_id_sql);
$h->execute($trait_ontology_db_name);

my $trait_cv_id = $h->fetchrow_array();

ok($trait_cv_id, "found the cv of trait ontology $trait_ontology_db_name");

# the root term of this ontology is what a new trait gets chained to when no parent terms are given.
# look it up before storing anything, so that the new trait cannot show up as a root term itself.
#
my $get_root_term_sql = "SELECT cvterm.cvterm_id FROM cvterm
JOIN dbxref USING (dbxref_id)
JOIN db USING (db_id)
LEFT JOIN cvterm_relationship ON (cvterm.cvterm_id = cvterm_relationship.subject_id)
WHERE db.name = ? AND cvterm.cv_id = ? AND cvterm_relationship.subject_id IS NULL
AND cvterm.is_obsolete = 0 AND cvterm.is_relationshiptype = 0";

$h = $schema->storage->dbh->prepare($get_root_term_sql);
$h->execute($trait_ontology_db_name, $trait_cv_id);

my %root_term_ids; # an ontology can have more than one parentless term, any of them is an acceptable parent
while (my $root_term_id = $h->fetchrow_array()) {
    $root_term_ids{$root_term_id} = 1;
}

ok(scalar(keys(%root_term_ids)), "found the root term(s) of trait ontology $trait_ontology_db_name");

my $rel_cv_id = $schema->resultset("Cv::Cv")->find({ name => 'relationship' })->cv_id();
my $variable_of_id = $schema->resultset("Cv::Cvterm")->find({ name => 'VARIABLE_OF', cv_id => $rel_cv_id })->cvterm_id();

# an ontology that is not in the allow_trait_edits config key cannot be added to,
# even when every other parameter is valid
#
$mech->post_ok('http://localhost:3010/ajax/trait/create', [
    name => $new_trait_name,
    definition => $new_trait_definition,
    format => "numeric",
    minimum => 0,
    maximum => 100,
    repeat_type => "single",
    ontology_db_name => "INVALID",
    parent_dbs => $trait_ontology_db_name
], 'try to create a trait in a non-editable ontology');

$response = decode_json $mech->content;

is($response->{error}, "Ontology INVALID is not editable on this server - contact a system administrator.\n", 'creating a trait in a non-editable ontology is rejected');

is($schema->resultset("Cv::Cvterm")->search({ name => $new_trait_name })->count(), 0, 'the rejected trait was not stored');

# now create the same trait in an editable ontology
#
$mech->post_ok('http://localhost:3010/ajax/trait/create', [
    name => $new_trait_name,
    definition => $new_trait_definition,
    format => "numeric",
    minimum => 0,
    maximum => 100,
    repeat_type => "single",
    ontology_db_name => $trait_ontology_db_name,
    parent_dbs => $trait_ontology_db_name
], 'create a new trait');

$response = decode_json $mech->content;

is($response->{success}, 1, 'the new trait was created');

# the new term must be in the cv of the ontology that was selected
#
my $new_trait = $schema->resultset("Cv::Cvterm")->search({
    name => $new_trait_name,
    cv_id => $trait_cv_id
})->single();

ok($new_trait, "the new trait was stored in the cv of $trait_ontology_db_name");

my $new_trait_id = $new_trait->cvterm_id();

is($new_trait->definition(), $new_trait_definition, 'the new trait has the definition that was submitted');

is($new_trait->dbxref->db->name(), $trait_ontology_db_name, "the new trait has a dbxref in $trait_ontology_db_name");

# no parent terms were given, so the new trait should hang off the root term of the selected ontology
#
my $parent_relationship = $schema->resultset("Cv::CvtermRelationship")->search({
    subject_id => $new_trait_id,
    type_id => $variable_of_id
})->single();

ok($parent_relationship, 'the new trait was chained to a parent term');

my $parent_term_id = $parent_relationship->object_id();

ok($root_term_ids{$parent_term_id}, "the new trait is a variable of a root term of $trait_ontology_db_name");

is($schema->resultset("Cv::Cvterm")->find({
    cvterm_id => $parent_term_id
})->cv_id(), $trait_cv_id, "the parent term of the new trait is in the cv of $trait_ontology_db_name");

# edit the definition of the new trait
#
$mech->post_ok('http://localhost:3010/ajax/trait/edit', [
    cvterm_id => $new_trait_id,
    new_definition => $edited_trait_definition
], 'edit the definition of the new trait');

$response = decode_json $mech->content;

is($response->{success}, 1, 'the trait was edited');

$new_trait->discard_changes();

is($new_trait->definition(), $edited_trait_definition, 'the definition of the trait was updated');

is($new_trait->name(), $new_trait_name, 'the name of the trait was left alone');

# an edit without a cvterm_id should not be accepted
#
$mech->post_ok('http://localhost:3010/ajax/trait/edit', [
    new_definition => "Another definition that should never be stored anywhere."
], 'try to edit a trait without a cvterm id');

$response = decode_json $mech->content;

is($response->{error}, "Cvterm ID missing.\n", 'editing a trait without a cvterm id is rejected');

# delete the new trait
#
$mech->post_ok('http://localhost:3010/ajax/trait/delete', [
    cvterm_id => $new_trait_id
], 'delete the new trait');

$response = decode_json $mech->content;

is($response->{success}, 1, 'the trait was deleted');

is($schema->resultset("Cv::Cvterm")->search({ cvterm_id => $new_trait_id })->count(), 0, 'the trait is gone from the database');

is($schema->resultset("Cv::CvtermRelationship")->search({ subject_id => $new_trait_id })->count(), 0, 'the relationship to the root term is gone as well');

done_testing();
