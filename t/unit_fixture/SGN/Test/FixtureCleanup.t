# Regression test for SGN::Test::Fixture::clean_up_db() called while the test
# has AutoCommit turned off on $f->dbh, as Uploading/Phenotype.t does. The
# cleanup must commit its deletes without touching the caller's transaction.
# It used to delete through $f->dbh; once db patch 00158 (AddCascadeDeletes)
# is applied, the experiment file links removed by that cascade stayed locked,
# and the next delete on the phenome connection waited forever.

use strict;
use warnings;
use lib 't/lib';

use Test::More;
use Config::Any;
use DBI;
use SGN::Test::Fixture;

# Seed a tagged image before Fixture captures its baseline, so preservation
# is exercised even when the original fixture has no tagged images.
my $config = Config::Any->load_files({files => ['sgn_fixture.conf'], use_ext => 1})
    ->[0]->{'sgn_fixture.conf'};
my $dsn = 'dbi:Pg:database='.$config->{dbname}.';host='.$config->{dbhost}.';port=5432';
my $setup_dbh = DBI->connect($dsn, $config->{dbuser}, $config->{dbpass},
    {AutoCommit => 1, RaiseError => 1, PrintError => 0});
my ($baseline_image_id) = $setup_dbh->selectrow_array('SELECT coalesce(max(image_id), 0) + 1 FROM metadata.md_image');
my ($baseline_tag_id) = $setup_dbh->selectrow_array('SELECT coalesce(max(tag_id), 0) + 1 FROM metadata.md_tag');
my ($baseline_tag_link_id) = $setup_dbh->selectrow_array('SELECT coalesce(max(tag_image_id), 0) + 1 FROM metadata.md_tag_image');
$setup_dbh->do('INSERT INTO metadata.md_image (image_id, name) VALUES (?, ?)',
    undef, $baseline_image_id, 'Fixture cleanup baseline image');
$setup_dbh->do('INSERT INTO metadata.md_tag (tag_id, name) VALUES (?, ?)',
    undef, $baseline_tag_id, 'Fixture cleanup baseline tag');
$setup_dbh->do('INSERT INTO metadata.md_tag_image (tag_image_id, image_id, tag_id) VALUES (?, ?, ?)',
    undef, $baseline_tag_link_id, $baseline_image_id, $baseline_tag_id);

my $f = SGN::Test::Fixture->new();
my $caller_dbh = $f->dbh();
my $metadata_dbh = $f->metadata_schema()->storage->dbh();
my $phenome_dbh = $f->phenome_schema()->storage->dbh();
my $observer_dbh = $f->bcs_schema()->storage->dbh();

ok($metadata_dbh->{AutoCommit}, 'metadata cleanup has a committed schema connection');
ok($phenome_dbh->{AutoCommit}, 'experiment links have a committed schema connection');

# The checks below hold with or without patch 00158; report whether the
# cascade that used to cause the hang is present in this database.
my ($file_link_delete_rule) = $observer_dbh->selectrow_array(q{
    SELECT confdeltype FROM pg_constraint
    WHERE conrelid = 'phenome.nd_experiment_md_files'::regclass
      AND conname = 'nd_experiment_md_files_file_id_fkey'
});
note('archived-file links cascade on file deletion: '
    .(defined $file_link_delete_rule && $file_link_delete_rule eq 'c' ? 'yes' : 'no'));

my %tables = (
    'metadata.md_metadata' => 'metadata_id',
    'metadata.md_files' => 'file_id',
    'phenome.nd_experiment_md_files' => 'nd_experiment_md_files_id',
    'metadata.md_image' => 'image_id',
    'metadata.md_tag_image' => 'tag_image_id',
);
my $snapshot = sub {
    return { map {
        $_ => $observer_dbh->selectall_arrayref("SELECT * FROM $_ ORDER BY $tables{$_}")
    } keys %tables };
};
my $baseline = $snapshot->();
my $tags_before = $observer_dbh->selectall_arrayref('SELECT * FROM metadata.md_tag ORDER BY tag_id');
my ($experiment_id) = $observer_dbh->selectrow_array('SELECT min(nd_experiment_id) FROM public.nd_experiment');
my $experiment_before = $observer_dbh->selectall_arrayref(
    'SELECT * FROM public.nd_experiment WHERE nd_experiment_id = ?', undef, $experiment_id,
);

# Explicit ids above the fixture maxima avoid changing sequences that other
# fixture tests rely on while exercising clean_up_db's id-based sweep.
my $metadata_id = $f->dbstats_start()->{metadata} + 1;
my $file_id = $f->dbstats_start()->{metadata_files} + 1;
my $link_id = $f->dbstats_start()->{experiment_files} + 1;
my $image_id = $baseline_image_id + 1;
my $tag_id = $baseline_tag_id + 1;
my $tag_link_id = $baseline_tag_link_id + 1;
my %new_ids = (
    'metadata.md_metadata' => $metadata_id,
    'metadata.md_files' => $file_id,
    'phenome.nd_experiment_md_files' => $link_id,
    'metadata.md_image' => $image_id,
    'metadata.md_tag_image' => $tag_link_id,
);
$f->metadata_schema()->resultset('MdMetadata')->create({
    metadata_id => $metadata_id, create_person_id => $f->sp_person_id(),
});
$f->metadata_schema()->resultset('MdFiles')->create({
    file_id => $file_id, metadata_id => $metadata_id,
    basename => 'fixture-cleanup.txt', dirname => '/tmp', filetype => 'test',
});
$f->phenome_schema()->resultset('NdExperimentMdFiles')->create({
    nd_experiment_md_files_id => $link_id,
    nd_experiment_id => $experiment_id, file_id => $file_id,
});
is($observer_dbh->selectrow_array(
    'SELECT count(*) FROM phenome.nd_experiment_md_files WHERE nd_experiment_md_files_id = ?', undef, $link_id,
), 1, 'archived-file link is committed and visible from another connection');

$metadata_dbh->do('INSERT INTO metadata.md_image (image_id, name) VALUES (?, ?)',
    undef, $image_id, 'Fixture cleanup new image');
$metadata_dbh->do('INSERT INTO metadata.md_tag (tag_id, name) VALUES (?, ?)',
    undef, $tag_id, 'Fixture cleanup new tag');
$metadata_dbh->do('INSERT INTO metadata.md_tag_image (tag_image_id, image_id, tag_id) VALUES (?, ?, ?)',
    undef, $tag_link_id, $image_id, $tag_id);
is($observer_dbh->selectrow_array(
    'SELECT count(*) FROM metadata.md_tag_image WHERE tag_image_id = ?', undef, $tag_link_id,
), 1, 'new image-tag link is committed and visible from another connection');

$caller_dbh->{AutoCommit} = 0;
$caller_dbh->{RaiseError} = 1;
my ($caller_transaction_id) = $caller_dbh->selectrow_array('SELECT txid_current()');
$phenome_dbh->do("SET lock_timeout = '2s'");
$phenome_dbh->do("SET statement_timeout = '5s'");

my $cleanup_ok = eval { $f->clean_up_db(); 1 };
ok($cleanup_ok, 'cleanup finishes without waiting on its caller transaction') or diag($@);
for my $table (sort keys %tables) {
    my $id = $new_ids{$table};
    is($observer_dbh->selectrow_array(
        "SELECT count(*) FROM $table WHERE $tables{$table} = ?", undef, $id,
    ), 0, "cleanup removal from $table is committed");
}
is_deeply($snapshot->(), $baseline, 'original metadata, images and links remain unchanged');
is_deeply($observer_dbh->selectall_arrayref(
    'SELECT * FROM metadata.md_tag WHERE tag_id <> ? ORDER BY tag_id', undef, $tag_id,
), $tags_before, 'original tags remain unchanged');
is($observer_dbh->selectrow_array('SELECT count(*) FROM metadata.md_tag WHERE tag_id = ?', undef, $tag_id),
    1, 'cleanup preserves the tag attached to a removed image');
is_deeply($observer_dbh->selectall_arrayref(
    'SELECT * FROM public.nd_experiment WHERE nd_experiment_id = ?', undef, $experiment_id,
), $experiment_before, 'original experiment remains unchanged');
ok(!$caller_dbh->{AutoCommit}, 'cleanup preserves caller AutoCommit');
# eval: a failed cleanup statement may have aborted the caller transaction.
my ($caller_transaction_after) = eval { $caller_dbh->selectrow_array('SELECT txid_current()') };
is($caller_transaction_after, $caller_transaction_id,
    'cleanup neither commits nor rolls back the caller transaction');
$caller_dbh->rollback();

# Release only this test's rows, including when checking a broken negative control.
$observer_dbh->do('DELETE FROM metadata.md_tag_image WHERE tag_image_id IN (?, ?)',
    undef, $tag_link_id, $baseline_tag_link_id);
$observer_dbh->do('DELETE FROM metadata.md_image WHERE image_id IN (?, ?)',
    undef, $image_id, $baseline_image_id);
$observer_dbh->do('DELETE FROM metadata.md_tag WHERE tag_id IN (?, ?)', undef, $tag_id, $baseline_tag_id);
$observer_dbh->do('DELETE FROM phenome.nd_experiment_md_files WHERE nd_experiment_md_files_id = ?', undef, $link_id);
$observer_dbh->do('DELETE FROM metadata.md_files WHERE file_id = ?', undef, $file_id);
$observer_dbh->do('DELETE FROM metadata.md_metadata WHERE metadata_id = ?', undef, $metadata_id);

$setup_dbh->disconnect();

done_testing();
