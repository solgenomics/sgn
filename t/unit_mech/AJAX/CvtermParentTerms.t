use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;

use JSON;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema();
my $dbh = $schema->storage->dbh;

my $mech = Test::WWW::Mechanize->new;
my $response;

my $url = 'http://localhost:3010';

# parent links (is_a / VARIABLE_OF) of a term, as the term page gets them
#
sub parent_links {
    my $cvterm_id = shift;
    $mech->get_ok("$url/ajax/cvterm/cvterm_relationships?cvterm_id=$cvterm_id");
    my $rels = decode_json($mech->content)->{relationships};
    return grep { $_->{relationship_name} eq 'is_a' || $_->{relationship_name} eq 'VARIABLE_OF' } @$rels;
}

# a term of the editable ontology CO_334 with exactly one parent, and another
# term of the same ontology to use as a second parent
#
my ($cvterm_id) = $dbh->selectrow_array(
    "SELECT cvterm.cvterm_id FROM cvterm
     JOIN dbxref USING (dbxref_id) JOIN db USING (db_id)
     JOIN cvterm_relationship ON (cvterm.cvterm_id = cvterm_relationship.subject_id)
     JOIN cvterm AS type ON (cvterm_relationship.type_id = type.cvterm_id)
     WHERE db.name = 'CO_334' AND cvterm.is_obsolete = 0
     GROUP BY cvterm.cvterm_id
     HAVING count(*) = 1 AND bool_and(type.name IN ('is_a', 'VARIABLE_OF'))
     ORDER BY cvterm.cvterm_id LIMIT 1");
ok($cvterm_id, 'found a CO_334 term with one parent');

my @links = parent_links($cvterm_id);
is(scalar(@links), 1, 'the term has one parent link');
ok($links[0]->{cvterm_relationship_id}, 'the parent link comes with its cvterm_relationship_id');
my $first_link_id = $links[0]->{cvterm_relationship_id};

my ($new_parent_name, $new_parent_accession) = $dbh->selectrow_array(
    "SELECT cvterm.name, dbxref.accession FROM cvterm
     JOIN dbxref USING (dbxref_id) JOIN db USING (db_id)
     WHERE db.name = 'CO_334' AND cvterm.is_obsolete = 0 AND cvterm.is_relationshiptype = 0
     AND cvterm.cvterm_id NOT IN (?, ?)
     ORDER BY cvterm.cvterm_id LIMIT 1",
    undef, $cvterm_id, $links[0]->{object_cvterm_id});
ok($new_parent_name, 'found a second parent term');

# not logged in
#
$mech->post_ok("$url/ajax/cvterm/delete_parent_term", [ cvterm_id => $cvterm_id, cvterm_relationship_id => $first_link_id ]);
$response = decode_json $mech->content;
is($response->{error}, 'You must be logged in to delete parent terms.', 'deleting a parent term needs a login');

# login as a curator
#
$mech->post_ok("$url/brapi/v1/token", [ "username" => "janedoe", "password" => "secretpw", "grant_type" => "password" ], 'login with brapi call');
$response = decode_json $mech->content;
is($response->{'userDisplayName'}, 'Jane Doe', 'check login name');

# the last parent cannot be removed
#
$mech->post_ok("$url/ajax/cvterm/delete_parent_term", [ cvterm_id => $cvterm_id, cvterm_relationship_id => $first_link_id ]);
$response = decode_json $mech->content;
is($response->{error}, "Error deleting parent term: Cannot remove the last parent of a term.\n",
    'rejecting removal of the last parent returns a plain error');
is(scalar(parent_links($cvterm_id)), 1, 'the term still has its parent');

# add a second parent, then remove it again
#
$mech->post_ok("$url/ajax/cvterm/add_parent_terms", [
    cvterm_id => $cvterm_id,
    parent_terms => encode_json([ "$new_parent_name|CO_334:$new_parent_accession" ])
], 'add a second parent');
$response = decode_json $mech->content;
ok(!$response->{error}, 'the second parent was added');

@links = parent_links($cvterm_id);
is(scalar(@links), 2, 'the term has two parent links');
my ($second_link) = grep { $_->{cvterm_relationship_id} != $first_link_id } @links;

# a link of this term cannot be removed through another term
#
$mech->post_ok("$url/ajax/cvterm/delete_parent_term", [ cvterm_id => $links[0]->{object_cvterm_id}, cvterm_relationship_id => $second_link->{cvterm_relationship_id} ]);
$response = decode_json $mech->content;
is($response->{error}, "Error deleting parent term: This relationship is not a parent of this term.\n",
    'rejecting a link of another term returns a plain error');
is(scalar(parent_links($cvterm_id)), 2, 'the term still has two parent links');

$mech->post_ok("$url/ajax/cvterm/delete_parent_term", [ cvterm_id => $cvterm_id, cvterm_relationship_id => $second_link->{cvterm_relationship_id} ]);
$response = decode_json $mech->content;
is($response->{message}, 'Parent term removed.', 'the second parent was removed');

@links = parent_links($cvterm_id);
is(scalar(@links), 1, 'the term has one parent link again');
is($links[0]->{cvterm_relationship_id}, $first_link_id, 'the first parent link is the one that is left');

# a term of an ontology that is not in the allow_trait_edits config key
#
my ($locked_cvterm_id, $locked_link_id) = $dbh->selectrow_array(
    "SELECT cvterm_relationship.subject_id, min(cvterm_relationship_id) FROM cvterm_relationship
     JOIN cvterm AS type ON (cvterm_relationship.type_id = type.cvterm_id)
     JOIN cvterm ON (cvterm_relationship.subject_id = cvterm.cvterm_id)
     JOIN dbxref ON (cvterm.dbxref_id = dbxref.dbxref_id) JOIN db USING (db_id)
     WHERE type.name = 'is_a' AND db.name NOT IN ('EXPERIMENT_TREATMENT', 'COMP_EXP_TREATMENT', 'COMP', 'CO_334')
     GROUP BY cvterm_relationship.subject_id HAVING count(*) > 1
     ORDER BY cvterm_relationship.subject_id LIMIT 1");

SKIP: {
    skip 'no term with two parents outside the editable ontologies in this fixture', 3 unless $locked_cvterm_id;

    $mech->post_ok("$url/ajax/cvterm/delete_parent_term", [ cvterm_id => $locked_cvterm_id, cvterm_relationship_id => $locked_link_id ]);
    $response = decode_json $mech->content;
    like($response->{error}, qr/This ontology is not editable on this server/, 'a term of a non-editable ontology keeps its parents');
    ok($schema->resultset("Cv::CvtermRelationship")->find({ cvterm_relationship_id => $locked_link_id }), 'the link is still in the database');
}

done_testing();
