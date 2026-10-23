
use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;

use Data::Dumper;
use JSON;

use CXGN::Collection;
use CXGN::Collection::Search;
use CXGN::File::Search;

local $Data::Dumper::Indent = 0;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema();
my $dbh = $f->dbh();

my $mech = Test::WWW::Mechanize->new;
my $response;

my $sp_person_id = 41; # janedoe
my $fixture_file_basename = '2017-04-21_21:11:28_cass_phenotypes_updated.xls';

my @created_collections;

my $cobj = CXGN::Collection->new({ bcs_schema => $schema });

# login as janedoe, who creates and owns the collections in this test
#
$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ], 'login with brapi call');

$response = decode_json $mech->content;

is($response->{'userDisplayName'}, 'Jane Doe', 'check login name');

# fixture data: the 'test' breeding program, a trial, and the one file in the fixture
#
my $program_id = $schema->resultset('Project::Project')->find({ name => 'test' })->project_id();
ok($program_id, 'found the test breeding program');

my $trial_id = $schema->resultset('Project::Project')->find({ name => 'test_trial' })->project_id();
ok($trial_id, 'found test_trial');

my ($fixture_file_id) = $dbh->selectrow_array("SELECT file_id FROM metadata.md_files WHERE basename = ?", undef, $fixture_file_basename);
ok($fixture_file_id, 'found the fixture file');

# the fixture has no images and only one file, so add an image and a second file.
# both are removed by clean_up_db at the end (images and metadata tables).
#
my ($image_id) = $dbh->selectrow_array(
    "INSERT INTO metadata.md_image (name, original_filename, file_ext, sp_person_id, obsolete)
     VALUES ('collection test image', 'collection_test_image', '.png', ?, 'f') RETURNING image_id",
    undef, $sp_person_id
);
ok($image_id, 'created a test image');

my ($metadata_id) = $dbh->selectrow_array(
    "INSERT INTO metadata.md_metadata (create_date, create_person_id, obsolete) VALUES (now(), ?, 0) RETURNING metadata_id",
    undef, $sp_person_id
);
my ($second_file_id) = $dbh->selectrow_array(
    "INSERT INTO metadata.md_files (basename, dirname, filetype, metadata_id)
     VALUES ('collection_test_file.csv', '/tmp', 'collection test file', ?) RETURNING file_id",
    undef, $metadata_id
);
ok($second_file_id, 'created a second test file');

# create a standalone image collection
#
my $alpha_id = $cobj->create_collection({
    name            => 'TestCollection Alpha',
    description     => 'alpha image collection',
    sp_person_id    => $sp_person_id,
    collection_type => 'image',
});
push @created_collections, $alpha_id;

ok($alpha_id, 'create standalone collection');

# a duplicate name in the same standalone context (case insensitive) dies
#
my $dupe = eval {
    $cobj->create_collection({ name => 'TESTCOLLECTION ALPHA', collection_type => 'image', sp_person_id => $sp_person_id })
};
push @created_collections, $dupe if defined $dupe;

like($@, qr/already exists/i, 'duplicate name in the same context dies');

# an invalid collection_type dies
#
my $bad = eval {
    $cobj->create_collection({ name => 'TestCollection Video', collection_type => 'video', sp_person_id => $sp_person_id })
};
push @created_collections, $bad if defined $bad;

ok($@, 'invalid collection_type dies');

# read the collection back
#
my $details = $cobj->get_collection($alpha_id);

is($details->{name}, 'TestCollection Alpha', 'get_collection returns the name');
is($details->{collection_type}, 'image', 'get_collection returns the collection_type');
ok(exists $details->{image_count} && exists $details->{file_count}, 'get_collection returns counts');
is_deeply($details->{projects}, [], 'standalone collection has no project scope');

my $by_type = $cobj->get_collections({ collection_type => 'image' });
ok((grep { $_->{collection_id} == $alpha_id } @$by_type), 'type filter includes the collection');

$by_type = $cobj->get_collections({ collection_type => 'file' });
ok(!(grep { $_->{collection_id} == $alpha_id } @$by_type), 'type filter excludes other types');

my $mine = $cobj->get_collections({ standalone_only => 1, sp_person_id => $sp_person_id });
ok((grep { $_->{collection_id} == $alpha_id } @$mine), 'standalone and mine filter includes the collection');

# a collection scoped to the test breeding program
#
my $program_collection_id = $cobj->create_collection({
    name                => 'TestCollection ProgramA',
    sp_person_id        => $sp_person_id,
    collection_type     => 'image',
    breeding_program_id => $program_id,
});
push @created_collections, $program_collection_id;

ok($program_collection_id, 'create collection with breeding_program_id');

my $projects = $cobj->get_projects($program_collection_id);
is(scalar(@$projects), 1, 'program row is in project_md_collection');
is($projects->[0]{project_id}, $program_id, 'program project_id matches');

# the same name in a different (standalone) context is allowed
#
my $standalone_same_name_id = $cobj->create_collection({
    name            => 'TestCollection ProgramA',
    sp_person_id    => $sp_person_id,
    collection_type => 'image',
});
push @created_collections, $standalone_same_name_id;

ok($standalone_same_name_id, 'same name allowed in the standalone context');

# attaching it to the program would put two collections with the same name in that program
#
eval { $cobj->attach_to_project($standalone_same_name_id, $program_id) };
like($@, qr/already exists/i, 'attach_to_project dies when the name is taken in the program');
is_deeply($cobj->get_projects($standalone_same_name_id), [], 'the rejected attach did not associate a program');

# a standalone collection with a unique name can be attached and detached
#
my $attachable_id = $cobj->create_collection({
    name            => 'TestCollection Attachable',
    sp_person_id    => $sp_person_id,
    collection_type => 'image',
});
push @created_collections, $attachable_id;

$cobj->attach_to_project($attachable_id, $program_id);
is(scalar(@{ $cobj->get_projects($attachable_id) }), 1, 'attach_to_project adds program scope');

$cobj->detach_from_project($attachable_id, $program_id);
is_deeply($cobj->get_projects($attachable_id), [], 'detach_from_project removes it');

# the same name within the same program context is not allowed
#
my $collide = eval {
    $cobj->create_collection({ name => 'TestCollection ProgramA', sp_person_id => $sp_person_id, collection_type => 'image', breeding_program_id => $program_id })
};
push @created_collections, $collide if defined $collide;

ok($@, 'duplicate name within the same program scope dies');

# image membership: add, re-add, remove
#
my $res = $cobj->add_images($alpha_id, [ $image_id ]);
is_deeply($res->{added_ids}, [ $image_id ], 'add_images adds the image');

$res = $cobj->add_images($alpha_id, [ $image_id ]);
is_deeply($res->{added_ids}, [], 're-adding an image is a no-op');
is_deeply($res->{duplicate_ids}, [ $image_id ], 're-adding reports duplicate ids');

my $contents = $cobj->get_contents($alpha_id);
ok((grep { $_->{item_type} eq 'image' && $_->{item_id} == $image_id } @$contents), 'get_contents lists the image');

is($cobj->remove_images($alpha_id, [ $image_id ]), 1, 'remove_images removes the row');

# non numeric ids are filtered out
#
$res = $cobj->add_images($alpha_id, [ 'abc', undef, $image_id ]);
is(scalar(@{ $res->{added_ids} }), 1, 'non numeric ids are filtered');

$cobj->remove_images($alpha_id, [ $image_id ]);

# file membership and ordering
#
$cobj->add_files($alpha_id, [ $fixture_file_id ]);
is_deeply($cobj->get_file_ids($alpha_id), [ $fixture_file_id ], 'get_file_ids returns the file');

$contents = $cobj->get_contents($alpha_id);
ok((grep { $_->{item_type} eq 'file' && $_->{item_id} == $fixture_file_id } @$contents), 'get_contents lists the file');

$cobj->add_files($alpha_id, [ $second_file_id ]);
is($cobj->set_order($alpha_id, 'file', [ $second_file_id, $fixture_file_id ]), 2, 'set_order sets both ranks');
is_deeply($cobj->get_file_ids($alpha_id), [ $second_file_id, $fixture_file_id ], 'file order respects set_order');

$cobj->remove_files($alpha_id, [ $fixture_file_id, $second_file_id ]);

# CXGN::Collection::Search filters
#
my ($result, $total) = CXGN::Collection::Search->new({
    bcs_schema => $schema,
    name_list  => ['TestCollection Alpha'],
})->search();

my $row = (grep { $_->{collection_id} == $alpha_id } @$result)[0];
ok($row, 'name search finds the collection');
is($row->{collection_type}, 'image', 'search returns collection_type');
is($row->{username}, 'janedoe', 'search returns the creator username');

($result, $total) = CXGN::Collection::Search->new({
    bcs_schema           => $schema,
    collection_type_list => ['file'],
})->search();

ok(!(grep { $_->{collection_id} == $alpha_id } @$result), 'type filter excludes image collections');

# CXGN::File::Search filters
#
my ($files, $files_total) = CXGN::File::Search->new({ bcs_schema => $schema })->search();

my $file_row = (grep { $_->{file_id} == $fixture_file_id } @$files)[0];
ok($file_row, 'file search finds the fixture file');
is($file_row->{basename}, $fixture_file_basename, 'file search returns the basename');
is($file_row->{username}, 'johndoe', 'file search returns the uploader');

($files, $files_total) = CXGN::File::Search->new({
    bcs_schema    => $schema,
    basename_list => [ $fixture_file_basename ],
})->search();

ok((grep { $_->{file_id} == $fixture_file_id } @$files), 'basename filter matches');

($files, $files_total) = CXGN::File::Search->new({
    bcs_schema             => $schema,
    uploader_username_list => [ 'johndoe' ],
})->search();

ok((grep { $_->{file_id} == $fixture_file_id } @$files), 'uploader username filter matches');

($files, $files_total) = CXGN::File::Search->new({
    bcs_schema    => $schema,
    filetype_list => [ 'spreadsheet phenotype file' ],
})->search();

ok((grep { $_->{file_id} == $fixture_file_id } @$files), 'filetype filter matches');

# collection membership restricts the file search to members
#
my $file_collection_id = $cobj->create_collection({ name => 'TestCollection FileSearch', collection_type => 'file', sp_person_id => $sp_person_id });
push @created_collections, $file_collection_id;

$cobj->add_files($file_collection_id, [ $fixture_file_id ]);

($files, $files_total) = CXGN::File::Search->new({
    bcs_schema         => $schema,
    collection_id_list => [ $file_collection_id ],
})->search();

is_deeply([ map { $_->{file_id} } @$files ], [ $fixture_file_id ], 'collection_id_list restricts to members');

# combined filters: the loosely matched groups are added to the sql after the other clauses, so their bind values must line up with their placeholders

($files, $files_total) = CXGN::File::Search->new({
    bcs_schema    => $schema,
    basename_list => [ 'cass_phenotypes' ],
    comment_list  => [ 'cass_phenotypes' ],
    filetype_list => [ 'spreadsheet' ],
})->search();

is_deeply([ map { $_->{file_id} } @$files ], [ $fixture_file_id ], 'basename or comment combined with filetype matches');

($files, $files_total) = CXGN::File::Search->new({
    bcs_schema             => $schema,
    basename_list          => [ 'cass_phenotypes' ],
    filetype_list          => [ 'spreadsheet' ],
    uploader_username_list => [ 'johndoe' ],
    collection_id_list     => [ $file_collection_id ],
})->search();

is_deeply([ map { $_->{file_id} } @$files ], [ $fixture_file_id ], 'basename, filetype, uploader and collection combined match');

($files, $files_total) = CXGN::File::Search->new({
    bcs_schema         => $schema,
    filetype_list      => [ 'collection test' ],
    collection_id_list => [ $file_collection_id ],
})->search();

is_deeply($files, [], 'filetype combined with collection excludes non members');

# search_grouped_by_program tree structure
#
my (undef, $groups) = CXGN::Collection::Search->new({ bcs_schema => $schema })->search_grouped_by_program();

is(ref($groups->{programs}), 'ARRAY', 'programs is an array');
is(ref($groups->{no_program}), 'ARRAY', 'no_program is an array');
is(ref($groups->{standalone}), 'ARRAY', 'standalone is an array');

ok((grep { $_->{collection_id} == $alpha_id } @{ $groups->{standalone} }), 'standalone collection lands in standalone');

my $program_group = (grep { $_->{program_id} == $program_id } @{ $groups->{programs} })[0];
ok($program_group, 'test program node exists');

my %program_collection_ids = map { $_->{collection_id} => 1 } (
    @{ $program_group->{collections} },
    map { @{ $_->{collections} } } @{ $program_group->{projects} },
);
ok($program_collection_ids{$program_collection_id}, 'program scoped collection appears under its program');

my (undef, $file_groups) = CXGN::Collection::Search->new({
    bcs_schema           => $schema,
    collection_type_list => ['file'],
})->search_grouped_by_program();

ok(!(grep { $_->{collection_id} == $alpha_id } @{ $file_groups->{standalone} }), 'collection_type filter respected by tree search');

# AJAX create and list
#
$mech->post_ok('http://localhost:3010/ajax/collection/create', [ name => 'TestCollection viaAjax', collection_type => 'image' ], 'create a collection via ajax');

$response = decode_json $mech->content;

ok(!$response->{error}, 'create via ajax has no error') or diag Dumper $response;
is($response->{items_added}, 0, 'no items added');

my $ajax_id = $response->{collection_id};
push @created_collections, $ajax_id;

ok($ajax_id, 'collection_id returned');

$mech->get_ok('http://localhost:3010/ajax/collection/list?collection_type=image');

$response = decode_json $mech->content;
$row = (grep { $_->{collection_id} == $ajax_id } @{ $response->{collections} })[0];

ok($row, 'list contains the created collection');
is($row->{user_can_modify}, 1, 'creator can modify');

$mech->get_ok('http://localhost:3010/ajax/collection/list?collection_type=image&mine_only=1');

$response = decode_json $mech->content;

ok((grep { $_->{collection_id} == $ajax_id } @{ $response->{collections} }), 'mine_only includes own collection');

# AJAX add, for_item and remove for images
#
$mech->post_ok('http://localhost:3010/ajax/collection/add_items', [
    collection_id => $ajax_id, item_type => 'image', item_ids_json => encode_json([$image_id]),
], 'add an image via ajax');

$response = decode_json $mech->content;

ok(!$response->{error}, 'add_items has no error') or diag Dumper $response;
is($response->{items_added}, 1, 'one item added');

$mech->post_ok('http://localhost:3010/ajax/collection/add_items', [
    collection_id => $ajax_id, item_type => 'image', item_ids_json => encode_json([$image_id]),
], 're-add the image via ajax');

$response = decode_json $mech->content;

is($response->{items_added}, 0, 're-add adds nothing');
is_deeply($response->{duplicate_ids}, [$image_id], 'duplicate reported');

$mech->get_ok("http://localhost:3010/ajax/collection/for_item?item_type=image&item_id=$image_id");

$response = decode_json $mech->content;

ok((grep { $_->{collection_id} == $ajax_id } @{ $response->{collections} }), 'for_item finds the membership');

$mech->post_ok('http://localhost:3010/ajax/collection/remove_items', [
    collection_id => $ajax_id, item_type => 'image', item_ids_json => encode_json([$image_id]),
], 'remove the image via ajax');

$response = decode_json $mech->content;

is($response->{items_removed}, 1, 'remove_items removes one');

$mech->get_ok("http://localhost:3010/ajax/collection/for_item?item_type=image&item_id=$image_id");

$response = decode_json $mech->content;

ok(!(grep { $_->{collection_id} == $ajax_id } @{ $response->{collections} }), 'membership gone after remove');

# AJAX add and remove for files
#
$mech->post_ok('http://localhost:3010/ajax/collection/add_items', [
    collection_id => $ajax_id, item_type => 'file', item_ids_json => encode_json([$fixture_file_id]),
], 'add a file via ajax');

$response = decode_json $mech->content;

ok(!$response->{error}, 'file add via ajax has no error') or diag Dumper $response;
is($response->{file_count}, 1, 'file_count returned');

$mech->post_ok('http://localhost:3010/ajax/collection/remove_items', [
    collection_id => $ajax_id, item_type => 'file', item_ids_json => encode_json([$fixture_file_id]),
], 'remove the file via ajax');

$response = decode_json $mech->content;

is($response->{items_removed}, 1, 'file removed via ajax');

# an invalid item_type is rejected
#
$mech->post('http://localhost:3010/ajax/collection/add_items', [
    collection_id => $ajax_id, item_type => 'video', item_ids_json => encode_json([1]),
]);

$response = decode_json $mech->content;

like($response->{error}, qr/item_type/, 'invalid item_type rejected');

# for_trial: an invalid trial_id errors, a real trial returns an array
#
$mech->get('http://localhost:3010/ajax/collection/for_trial?trial_id=abc');

$response = decode_json $mech->content;

like($response->{error}, qr/valid trial_id/i, 'invalid trial_id rejected');

$mech->get_ok("http://localhost:3010/ajax/collection/for_trial?trial_id=$trial_id");

$response = decode_json $mech->content;

ok(!$response->{error}, 'for_trial has no error for a real trial') or diag Dumper $response;
is(ref($response->{collections}), 'ARRAY', 'for_trial returns a collections array');

# AJAX create with a breeding program
#
$mech->post_ok('http://localhost:3010/ajax/collection/create', [
    name => 'TestCollection viaAjaxProgrammed', collection_type => 'image', breeding_program_id => $program_id,
], 'create a program collection via ajax');

$response = decode_json $mech->content;

ok(!$response->{error}, 'create with breeding_program_id has no error') or diag Dumper $response;
push @created_collections, $response->{collection_id};

$mech->get_ok('http://localhost:3010/ajax/collection/list?collection_type=image');

$response = decode_json $mech->content;

ok((grep { $_->{name} eq 'TestCollection viaAjaxProgrammed' } @{ $response->{collections} }), 'program collection present in list');

# AJAX rename and delete
#
$mech->post_ok('http://localhost:3010/ajax/collection/create', [ name => 'TestCollection RenameMe', collection_type => 'image' ], 'create a collection to rename');

$response = decode_json $mech->content;

my $rename_id = $response->{collection_id};
ok($rename_id, 'collection to rename created');

$mech->post_ok('http://localhost:3010/ajax/collection/rename', [ collection_id => $rename_id, name => 'TestCollection Renamed' ], 'rename via ajax');

$response = decode_json $mech->content;

ok(!$response->{error}, 'rename has no error') or diag Dumper $response;
is($cobj->get_collection($rename_id)->{name}, 'TestCollection Renamed', 'name changed');

$mech->post_ok('http://localhost:3010/ajax/collection/delete', [ collection_id => $rename_id ], 'delete via ajax');

$response = decode_json $mech->content;

ok(!$response->{error}, 'delete has no error') or diag Dumper $response;
ok(!$cobj->get_collection($rename_id), 'collection gone after delete');

# AJAX file search
#
$mech->post_ok('http://localhost:3010/ajax/search/files', [ draw => 1, length => 100, start => 0 ], 'file search via ajax');

$response = decode_json $mech->content;

ok($response->{recordsTotal} >= 2, 'fixture and test files are counted');

# without html_select_box the first cell is the basename link
#
$row = (grep { $_->[0] =~ /\Q$fixture_file_basename\E/ } @{ $response->{data} })[0];
ok($row, 'fixture file row present');
like($row->[0], qr/<\/a>/, 'basename rendered as link');

$mech->post_ok('http://localhost:3010/ajax/search/files', [ draw => 2, length => 100, start => 0, file_name => 'cass_phenotypes' ], 'file search with file_name');

$response = decode_json $mech->content;

ok((grep { $_->[0] =~ /cass_phenotypes/ } @{ $response->{data} }), 'file_name filter matches');
ok(!(grep { $_->[0] =~ /collection_test_file/ } @{ $response->{data} }), 'file_name filter excludes other files');

$mech->post_ok('http://localhost:3010/ajax/search/files', [ draw => 3, length => 100, start => 0, file_name => 'cass_phenotypes', file_type => 'spreadsheet' ], 'file search with file_name and file_type');

$response = decode_json $mech->content;

is($response->{recordsTotal}, 1, 'file_name and file_type together find only the fixture file');
like($response->{data}[0][0], qr/\Q$fixture_file_basename\E/, 'file_name and file_type together return the fixture file');

# AJAX collection search
#
$mech->post_ok('http://localhost:3010/ajax/search/collections', [ draw => 1, length => 100, start => 0 ], 'collection search via ajax');

$response = decode_json $mech->content;

ok($response->{recordsTotal} >= 1, 'collection search returns rows');

$mech->post_ok('http://localhost:3010/ajax/search/collections', [ draw => 2, length => 100, start => 0, name => 'TestCollection viaAjax' ], 'collection search with name');

$response = decode_json $mech->content;

ok((grep { $_->{name} eq 'TestCollection viaAjax' } @{ $response->{data} }), 'name filter works');

$mech->post_ok('http://localhost:3010/ajax/search/collections', [ draw => 3, length => 100, start => 0, collection_type => 'file' ], 'collection search with collection_type');

$response = decode_json $mech->content;

ok(!(grep { ($_->{collection_type} // '') eq 'image' } @{ $response->{data} }), 'collection_type=file excludes image collections');

# AJAX tree endpoint
#
$mech->get_ok('http://localhost:3010/ajax/search/collections/tree');

$response = decode_json $mech->content;

is(ref($response->{programs}), 'ARRAY', 'tree programs array');
is(ref($response->{standalone}), 'ARRAY', 'tree standalone array');
ok((grep { $_->{collection_id} == $alpha_id } @{ $response->{standalone} }), 'standalone collection in tree');

$mech->get_ok('http://localhost:3010/ajax/search/collections/tree?collection_type=file');

$response = decode_json $mech->content;

ok(!(grep { $_->{collection_id} == $alpha_id } @{ $response->{standalone} }), 'tree honors collection_type filter');

# access control: anonymous users cannot create, and johndoe (not the creator, not a curator) cannot modify
#
my $owner_lock_id = $cobj->create_collection({ name => 'TestCollection OwnerLock', collection_type => 'image', sp_person_id => $sp_person_id });
push @created_collections, $owner_lock_id;

my $anon = Test::WWW::Mechanize->new;
$anon->post('http://localhost:3010/ajax/collection/create', [ name => 'TestCollection Anon' ]);

$response = decode_json $anon->content;

is($response->{error}, 'You must be logged in to do this.', 'anonymous create rejected');

my $john = Test::WWW::Mechanize->new;
$john->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "johndoe", "password"=> "secretpw", "grant_type"=> "password" ], 'login as johndoe');

$response = decode_json $john->content;

is($response->{'userDisplayName'}, 'John Doe', 'check johndoe login name');

$john->post('http://localhost:3010/ajax/collection/add_items', [
    collection_id => $owner_lock_id, item_type => 'image', item_ids_json => encode_json([$image_id]),
]);

$response = decode_json $john->content;

like($response->{error}, qr/creator or a curator/i, 'non owner add_items rejected');

$john->post('http://localhost:3010/ajax/collection/rename', [ collection_id => $owner_lock_id, name => 'TestCollection Stolen' ]);

$response = decode_json $john->content;

like($response->{error}, qr/creator or a curator/i, 'non owner rename rejected');

$mech->post_ok('http://localhost:3010/ajax/collection/rename', [ collection_id => $owner_lock_id, name => 'TestCollection OwnerLock 2' ], 'owner renames');

$response = decode_json $mech->content;

ok(!$response->{error}, 'owner can rename') or diag Dumper $response;

# clean up: collections are not covered by clean_up_db, so remove them before
# clean_up_db removes the test image and file they could reference
#
foreach my $cid (grep { defined } @created_collections) {
    $dbh->do("DELETE FROM phenome.project_md_collection WHERE collection_id = ?", undef, $cid);
    $dbh->do("DELETE FROM metadata.md_collection_image WHERE collection_id = ?", undef, $cid);
    $dbh->do("DELETE FROM metadata.md_collection_file WHERE collection_id = ?", undef, $cid);
    $dbh->do("DELETE FROM metadata.md_collection WHERE collection_id = ?", undef, $cid);
}

$f->clean_up_db();

done_testing();
