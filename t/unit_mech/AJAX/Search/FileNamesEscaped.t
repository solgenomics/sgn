
=head1 NAME

t/unit_mech/AJAX/Search/FileNamesEscaped.t - /ajax/search/files sends stored names as text

=head1 DESCRIPTION

The files table on the collections page shows the cells of /ajax/search/files
as HTML. A file name, comment or type with markup must come back escaped.

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
my ($metadata_id) = $dbh->selectrow_array("INSERT INTO metadata.md_metadata (create_person_id) VALUES (?) RETURNING metadata_id", undef, $owner_id);
my $name = 'filesearchprobe<img id="probe1">.txt';
my ($file_id) = $dbh->selectrow_array("INSERT INTO metadata.md_files (basename, dirname, filetype, comment, metadata_id) VALUES (?, '/tmp', 'filesearchprobe type', ?, ?) RETURNING file_id", undef, $name, 'comment <img id="probe2">', $metadata_id);

my $mech = Test::WWW::Mechanize->new(autocheck => 0);
$mech->post("$server/ajax/user/login", { username => 'janedoe', password => 'secretpw' });
$mech->post("$server/ajax/search/files", { file_name => 'filesearchprobe', draw => 1, start => 0, length => 10, html_select_box => 'files_select' });
is($mech->status, 200, 'file search answers');
my $r = eval { decode_json($mech->content) } || {};
my ($row) = grep { join('', @$_) =~ /filesearchprobe/ } @{ $r->{data} || [] };
ok($row, 'the test file is found') or diag explain $r;
my $cells = join("\n", @{ $row || [] });
unlike($cells, qr/<img id="probe/, 'no stored value is sent as HTML');
like($cells, qr/filesearchprobe&lt;img id=&quot;probe1&quot;&gt;\.txt/, 'the file name is sent as text');
like($cells, qr/comment &lt;img id=&quot;probe2&quot;&gt;/, 'the comment is sent as text');

$dbh->do("DELETE FROM metadata.md_files WHERE file_id = ?", undef, $file_id);
$dbh->do("DELETE FROM metadata.md_metadata WHERE metadata_id = ?", undef, $metadata_id);

done_testing();
