
=head1 NAME

t/unit_mech/Controller/FieldBookDeleteFile.t - only the owner or a curator can delete a Field Book file

=head1 DESCRIPTION

/fieldbook/delete_file/<id> deletes a file's rows in metadata.md_files and
phenome.nd_experiment_md_files. An anonymous request or a user who does not
own the file must delete nothing, and other kinds of files are never deleted
there. The owner and a curator can delete a Field Book file.

=cut

use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use CXGN::People::Person;
use JSON;

my $f = SGN::Test::Fixture->new();
my $dbh = $f->dbh();
my $server = 'http://localhost:3010';

my $owner_id = CXGN::People::Person->get_person_by_username($dbh, 'johndoe');
ok($owner_id, 'fixture user johndoe exists');
my ($experiment_id) = $dbh->selectrow_array("SELECT min(nd_experiment_id) FROM nd_experiment");

sub new_file {
    my $filetype = shift;
    my ($metadata_id) = $dbh->selectrow_array("INSERT INTO metadata.md_metadata (create_person_id) VALUES (?) RETURNING metadata_id", undef, $owner_id);
    my ($file_id) = $dbh->selectrow_array("INSERT INTO metadata.md_files (basename, dirname, filetype, metadata_id) VALUES ('fieldbook_delete_test.xls', '/tmp', ?, ?) RETURNING file_id", undef, $filetype, $metadata_id);
    $dbh->do("INSERT INTO phenome.nd_experiment_md_files (nd_experiment_id, file_id) VALUES (?, ?)", undef, $experiment_id, $file_id);
    return $file_id;
}

sub rows_left {
    my $file_id = shift;
    my ($files) = $dbh->selectrow_array("SELECT count(*) FROM metadata.md_files WHERE file_id = ?", undef, $file_id);
    my ($links) = $dbh->selectrow_array("SELECT count(*) FROM phenome.nd_experiment_md_files WHERE file_id = ?", undef, $file_id);
    return $files + $links;
}

sub browser {
    my $username = shift;
    my $password = $username && $username eq 'freddy' ? 'atgc' : 'secretpw'; # fixture passwords
    my $mech = Test::WWW::Mechanize->new(autocheck => 0);
    if ($username) {
        $mech->post("$server/ajax/user/login", { username => $username, password => $password });
        my $r = eval { decode_json($mech->content) } || {};
        is($r->{message} || '', 'Login successful', "$username signs in");
    }
    return $mech;
}

my $layout_file = new_file('tablet field layout xls');
my $other_file = new_file('spreadsheet phenotype file');
is(rows_left($layout_file), 2, 'test layout file and its experiment link exist');

browser()->get("$server/fieldbook/delete_file/$layout_file");
is(rows_left($layout_file), 2, 'anonymous request deletes nothing');

browser('freddy')->get("$server/fieldbook/delete_file/$layout_file");
is(rows_left($layout_file), 2, 'a user who does not own the file deletes nothing');

my $johndoe = browser('johndoe');
$johndoe->get("$server/fieldbook/delete_file/$other_file");
is(rows_left($other_file), 2, 'a file that is not a Field Book file is not deleted, even by its owner');

$johndoe->get("$server/fieldbook/delete_file/$layout_file");
is(rows_left($layout_file), 0, 'the owner deletes the file and its experiment link');

my $trait_file = new_file('tablet trait file');
browser('janedoe')->get("$server/fieldbook/delete_file/$trait_file");
is(rows_left($trait_file), 0, 'a curator deletes a Field Book trait file');

$dbh->do("DELETE FROM phenome.nd_experiment_md_files WHERE file_id = ?", undef, $other_file);
$dbh->do("DELETE FROM metadata.md_files WHERE file_id = ?", undef, $other_file);

done_testing();
