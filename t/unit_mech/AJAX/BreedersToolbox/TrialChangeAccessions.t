# Tests the ways to change the accession of plots in a trial, through the web
# server: Replace Accession (replace_stock), one plot (replace_plot_accessions),
# the Change Accessions upload (a file of what was planted, also of plots that
# were not planted), Substitute (substitute_stock), genotyping plate wells
# (replace_well_accessions) and BrAPI PUT /observationunits.
# CXGN::Trial::AccessionChange, which they all use, is tested in
# t/unit_fixture/CXGN/Trial/AccessionChange.t.
#
# Every scenario changes test_trial and puts it back as it was.

use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use LWP::UserAgent;
use JSON::XS;
use File::Temp qw(tempfile);
use URI::Escape qw(uri_escape);
use Text::CSV;
use SGN::Model::Cvterm;
use CXGN::Trial::TrialLayout;
use CXGN::Trial::AccessionChange;
use CXGN::BreedersToolbox::Projects;
use CXGN::Phenotypes::StorePhenotypes;
use CXGN::Stock::Seedlot::Transaction;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;
my $base = 'http://localhost:3010';

my $mech = Test::WWW::Mechanize->new;
$mech->post_ok("$base/brapi/v1/token", [ username => 'janedoe', password => 'secretpw', grant_type => 'password' ], 'login');
my $access_token = decode_json($mech->content)->{access_token};

my $trial_id = $schema->resultset('Project::Project')->find({ name => 'test_trial' })->project_id();
my %t = map { $_->[0] => SGN::Model::Cvterm->get_cvterm_row($schema, $_->[1], $_->[2])->cvterm_id() } (
    [ plot_of => 'plot_of', 'stock_relationship' ],
    [ replicate => 'replicate', 'stock_property' ],
    [ design_replicate => 'design_replicate', 'stock_property' ],
    [ occurrence_version => 'accession_occurrence_version', 'project_property' ],
    [ block => 'block', 'stock_property' ],
    [ not_planted => 'not_planted', 'stock_property' ],
    [ rejected => 'rejected', 'stock_property' ],
    [ reject_reason => 'reject_reason', 'stock_property' ],
    [ row_number => 'row_number', 'stock_property' ],
    [ col_number => 'col_number', 'stock_property' ],
    [ accession => 'accession', 'stock_type' ],
    [ seedlot => 'seedlot', 'stock_type' ],
    [ collection_of => 'collection_of', 'stock_relationship' ],
    [ seed_transaction => 'seed transaction', 'stock_relationship' ],
    [ design => 'design', 'project_property' ],
);
my %acc = map { $_ => $schema->resultset('Stock::Stock')->find({ uniquename => "test_accession$_" })->stock_id } 1 .. 5;
my %plot = map { $_ => $schema->resultset('Stock::Stock')->find({ uniquename => "test_trial2$_" })->stock_id } 1 .. 15;
my $organism_id = $schema->resultset('Stock::Stock')->find({ stock_id => $acc{1} })->organism_id;

sub plot_state {
    my $plot_id = shift;
    my $plot = $schema->resultset('Stock::Stock')->find({ stock_id => $plot_id });
    my $accession = $schema->resultset('Stock::StockRelationship')->find({ subject_id => $plot_id, type_id => $t{plot_of} })->object;
    my $rep = $schema->resultset('Stock::Stockprop')->find({ stock_id => $plot_id, type_id => $t{replicate} });
    my $design_rep = $schema->resultset('Stock::Stockprop')->find({stock_id=>$plot_id,type_id=>$t{design_replicate}});
    my $block = $schema->resultset('Stock::Stockprop')->find({ stock_id => $plot_id, type_id => $t{block} });
    my $not_planted = $schema->resultset('Stock::Stockprop')->find({ stock_id => $plot_id, type_id => $t{not_planted} });
    my $rejected = $schema->resultset('Stock::Stockprop')->find({ stock_id => $plot_id, type_id => $t{rejected} });
    my $reject_reason = $schema->resultset('Stock::Stockprop')->find({ stock_id => $plot_id, type_id => $t{reject_reason} });
    return { name => $plot->uniquename, accession => $accession->uniquename, accession_id => $accession->stock_id, rep => $rep ? $rep->value : undef, design_rep => $design_rep ? $design_rep->value : undef, block => $block ? $block->value : undef, not_planted => $not_planted ? $not_planted->value : undef, rejected => $rejected ? $rejected->value : undef, reject_reason => $reject_reason ? $reject_reason->value : undef };
}
sub trial_state { return { map { $_ => plot_state($plot{$_}) } keys %plot }; }
sub replication_state {
    my ($service)=@_;
    my @plots=keys %{$service->load_units};
    my $children=$service->_children(\@plots);
    my %ids=map {$_=>1} @plots;
    for my $parent (keys %$children) {$ids{$_->{stock_id}}=1 for @{$children->{$parent}{in_trial} || []}}
    return {ids=>[keys %ids],trial=>$service->trial_id,
        rows=>$schema->storage->dbh->selectall_arrayref('SELECT stock_id,type_id,value,rank FROM stockprop WHERE stock_id=ANY(?) AND type_id=ANY(?) ORDER BY stock_id,type_id,rank',undef,[keys %ids],[@t{qw(replicate design_replicate)}]),
        versions=>$schema->storage->dbh->selectall_arrayref('SELECT value,rank FROM projectprop WHERE project_id=? AND type_id=? ORDER BY rank',undef,$service->trial_id,$t{occurrence_version})};
}
sub restore_replication_state {
    my ($saved)=@_;
    $schema->txn_do(sub {
        my $dbh=$schema->storage->dbh;
        $dbh->do('DELETE FROM stockprop WHERE stock_id=ANY(?) AND type_id=ANY(?)',undef,$saved->{ids},[@t{qw(replicate design_replicate)}]);
        $dbh->do('INSERT INTO stockprop(stock_id,type_id,value,rank) VALUES(?,?,?,?)',undef,@$_) for @{$saved->{rows}};
        $dbh->do('DELETE FROM projectprop WHERE project_id=? AND type_id=?',undef,$saved->{trial},$t{occurrence_version});
        $dbh->do('INSERT INTO projectprop(project_id,type_id,value,rank) VALUES(?,?,?,?)',undef,$saved->{trial},$t{occurrence_version},@$_) for @{$saved->{versions}};
    });
}
my $original_replication=replication_state(CXGN::Trial::AccessionChange->new({schema=>$schema,trial_id=>$trial_id}));
my $original = trial_state();
my $original_design = $schema->resultset('Project::Projectprop')->find({ project_id => $trial_id, type_id => $t{design} })->value;
my $files_at_start;   # the additional files of test_trial before any upload (set below)

sub set_prop {
    my ($stock_id, $type, $value) = @_;
    $schema->resultset('Stock::Stockprop')->search({ stock_id => $stock_id, type_id => $t{$type} })->delete;
    $schema->resultset('Stock::Stockprop')->create({ stock_id => $stock_id, type_id => $t{$type}, value => $value, rank => 0 }) if defined $value;
}
sub rename_plot { my ($id, $name) = @_; $schema->resultset('Stock::Stock')->find({ stock_id => $id })->update({ uniquename => $name, name => $name }); }

sub restore {
    CXGN::Trial::AccessionChange->new({schema=>$schema,trial_id=>$trial_id})->apply(
        [map {{plot_id=>$plot{$_},new_stock_id=>$original->{$_}{accession_id},new_plot_name=>$original->{$_}{name},not_planted=>$original->{$_}{not_planted} || 0,rejected=>$original->{$_}{rejected} || 0}} keys %plot],
        {curator=>1,rename_plots=>'none'});
    foreach my $n (keys %plot) {
        my $o = $original->{$n};
        rename_plot($plot{$n}, $o->{name});
        $schema->resultset('Stock::StockRelationship')->search({ subject_id => $plot{$n}, type_id => $t{plot_of} })->update({ object_id => $o->{accession_id} });
        set_prop($plot{$n}, 'replicate', $o->{rep});
        set_prop($plot{$n}, 'block', $o->{block});
        set_prop($plot{$n}, 'not_planted', $o->{not_planted});
        set_prop($plot{$n}, 'rejected', $o->{rejected});
        set_prop($plot{$n}, 'reject_reason', $o->{reject_reason});
    }
    $schema->resultset('Project::Projectprop')->search({ project_id => $trial_id, type_id => $t{design} })->update({ value => $original_design });
    restore_replication_state($original_replication);
    $schema->storage->dbh->do('SELECT refresh_materialized_phenotype_jsonb_table()');
    obsolete_new_files($trial_id, $files_at_start);
    $mech->get_ok("$base/ajax/breeders/trial/$trial_id/refresh_cache", 'refresh cache after restore');
    is_deeply(trial_state(), $original, 'test_trial restored');
}

sub post_json {
    my ($path, $params) = @_;
    $mech->post("$base$path", $params);
    my $r = eval { decode_json($mech->content) } || { http_status => $mech->status };
    return $r;
}

sub cached_accession {
    my $plot_name = shift;
    my $design = CXGN::Trial::TrialLayout->new({ schema => $schema, trial_id => $trial_id, experiment_type => 'field_layout' })->get_design();
    my ($p) = grep { $_->{plot_name} eq $plot_name } values %$design;
    return $p ? $p->{accession_name} : undef;
}

# posts a CSV file to the Change Accessions upload of a trial, as a user ($mech by default)
sub upload_as {
    my ($user_mech, $trial, $content, @fields) = @_;
    my ($fh, $filename) = tempfile(SUFFIX => '.csv', UNLINK => 1);
    print $fh $content;
    close($fh);
    $user_mech->post("$base/ajax/breeders/trial/$trial/change_plot_accessions_using_file/check", Content_Type => 'form-data', Content => [ trial_design_change_accessions_file => [ $filename, 'change_accessions.csv', Content_Type => 'text/csv' ], @fields ]);
    return eval { decode_json($user_mech->content) } || { http_status => $user_mech->status, content => substr($user_mech->content, 0, 500) };
}
sub upload_accessions { return upload_as($mech, @_); }

# the ids of the additional files of a trial (an applied upload is kept there)
sub additional_files {
    my $trial = shift;
    $mech->get_ok("$base/ajax/breeders/trial/$trial/get_uploaded_additional_file", 'the additional files of the trial');
    return [ map { $_->[0] } @{ decode_json($mech->content)->{files} || [] } ];
}
# the files added since $before are marked obsolete, so that the fixture is as it was
sub obsolete_new_files {
    my ($trial, $before) = @_;
    my %old = map { $_ => 1 } @$before;
    foreach my $file_id (grep { !$old{$_} } @{ additional_files($trial) }) {
        $mech->get_ok("$base/ajax/breeders/trial/$trial/obsolete_uploaded_additional_file/$file_id", "additional file $file_id obsoleted");
    }
}
$files_at_start = additional_files($trial_id);

my $replace_stock = "/ajax/breeders/trial/$trial_id/replace_stock";
$mech->get_ok("$base/ajax/breeders/trial/$trial_id/refresh_cache");

subtest 'replace_stock: preview changes nothing' => sub {
    my $r = post_json($replace_stock, [ old_stock_id => $acc{3}, new_stock => 'test_accession1', trial_stock_type => 'accession', preview => 1 ]);
    is($r->{preview}->{changed}, 3, 'three plots would change');
    is($r->{preview}->{replicates_changed}, 4, 'four replicates would change (CRD)');
    ok(!$r->{success}, 'no success flag');
    is_deeply(trial_state(), $original, 'nothing changed');
};

subtest 'replace_stock: errors' => sub {
    like(post_json($replace_stock, [ old_stock_id => $acc{3}, new_stock => 'test_trial21', trial_stock_type => 'accession' ])->{error}, qr/test_trial21 is not an accession\./, 'a plot name as new stock');
    like(post_json($replace_stock, [ old_stock_id => $acc{3}, new_stock => 'no_such_stock_xyz' ])->{error}, qr/Could not find no_such_stock_xyz/, 'unknown stock');
    like(post_json($replace_stock, [ old_stock_id => $acc{3}, new_stock => 'cross_test1' ])->{error}, qr/cross_test1 is not an accession\./, 'a cross in a trial of accessions, without trial_stock_type');
    like(post_json($replace_stock, [ old_stock_id => $acc{3}, new_stock => 'cross_test1', trial_stock_type => 'cross' ])->{error}, qr/cross_test1 is not an accession\./, 'trial_stock_type from the browser does not widen what the trial takes');
    like(post_json($replace_stock, [ old_stock_id => $plot{1}, new_stock => 'test_accession1' ])->{error}, qr/No plot of this trial has the stock to replace/, 'old stock not in the trial');
    like(post_json($replace_stock, [ old_stock_id => $acc{3}, new_stock => '  ' ])->{error}, qr/Provide new stock name/, 'empty name');
    my $anonymous = Test::WWW::Mechanize->new;
    $anonymous->post("$base$replace_stock", [ old_stock_id => $acc{3}, new_stock => 'test_accession1' ]);
    like(decode_json($anonymous->content)->{error}, qr/insufficient access privileges/, 'not logged in');
    is_deeply(trial_state(), $original, 'nothing changed');
};

subtest 'replace_stock: names are kept by default (labels in the field)' => sub {
    rename_plot($plot{3}, 'test_trial-rep1-test_accession3_3');
    my $r = post_json($replace_stock, [ old_stock_id => $acc{3}, new_stock => 'test_accession2', trial_stock_type => 'accession' ]);
    is($r->{success}, 1, 'success');
    is_deeply($r->{renamed}, [], 'nothing renamed');
    is(plot_state($plot{3})->{name}, 'test_trial-rep1-test_accession3_3', 'name kept');
    is(cached_accession('test_trial-rep1-test_accession3_3'), 'test_accession2', 'cached layout has the new accession');
    restore();
};

subtest 'replace_stock: names are updated when asked to' => sub {
    rename_plot($plot{3}, 'test_trial-rep1-test_accession3_3');
    my $r = post_json($replace_stock, [ old_stock_id => $acc{3}, new_stock => 'test_accession2', trial_stock_type => 'accession', rename_plots => 1 ]);
    is_deeply($r->{renamed}, [ { old_name => 'test_trial-rep1-test_accession3_3', new_name => 'test_trial-rep1-test_accession2_3' } ], 'renamed');
    is(plot_state($plot{3})->{name}, 'test_trial-rep1-test_accession2_3', 'in the database');
    restore();
};

subtest 'replace_stock in an RCBD rebuilds occurrences and preserves design tags/blocks' => sub {
    $schema->resultset('Project::Projectprop')->search({ project_id => $trial_id, type_id => $t{design} })->update({ value => 'RCBD' });
    foreach my $n (keys %plot) {
        my $b = int(($n - 1) / 5) + 1;
        set_prop($plot{$n}, 'block', $b);
        set_prop($plot{$n}, 'replicate', $b);
        set_prop($plot{$n}, 'design_replicate', $b);
    }
    my $before = trial_state();
    my $r = post_json($replace_stock, [ old_stock_id => $acc{3}, new_stock => 'test_accession1', trial_stock_type => 'accession' ]);
    is($r->{success}, 1, 'success');
    ok($r->{replicates_changed}>0,'RCBD accession merge rebuilds occurrence labels');
    my $after = trial_state();
    is_deeply({ map { $_ => [ $after->{$_}->{design_rep}, $after->{$_}->{block} ] } keys %$after }, { map { $_ => [ $before->{$_}->{design_rep}, $before->{$_}->{block} ] } keys %$before }, 'recorded design groups and blocks unchanged');
    is($after->{10}->{accession}, 'test_accession1', 'accession changed');
    restore();
};

subtest 'replace_plot_accessions: one plot' => sub {
    my $r = post_json("/ajax/breeders/trial/$trial_id/replace_plot_accessions", [ old_accession => '<a href="/stock/1/view">ignored</a>', new_accession => 'test_accession2', old_plot_id => $plot{10}, old_plot_name => 'test_trial210', new_plot_name => '', override => 'check' ]);
    is($r->{success}, 1, 'success');
    is(plot_state($plot{10})->{accession}, 'test_accession2', 'changed');
    is(cached_accession('test_trial210'), 'test_accession2', 'cached layout');
    $r = post_json("/ajax/breeders/trial/$trial_id/replace_plot_accessions", [ new_accession => 'test_accession1', old_plot_id => $plot{10}, new_plot_name => 'test_trial21', override => 'check' ]);
    like($r->{error}, qr/Nothing was changed: Plot name test_trial21 already exists/, 'taken name refused');
    unlike($r->{error}, qr/\{UNKNOWN\}|line \d+|\.pm/, 'without internal details');
    is(plot_state($plot{10})->{accession}, 'test_accession2', 'and the accession was not changed either');
    $r = post_json("/ajax/breeders/trial/$trial_id/replace_plot_accessions", [ new_accession => 'test_accession1', old_plot_id => 1, override => 'check' ]);
    like($r->{error}, qr/not part of this trial/, 'a stock that is not a plot of this trial');
    restore();
};

subtest 'Change Accessions upload' => sub {
    my $upload = sub { my ($content, $user_mech, @fields) = @_; return upload_as($user_mech || $mech, $trial_id, $content, @fields); };
    my $files_before = additional_files($trial_id);
    my $r = $upload->("plot_name,accession_name,new_plot_name\ntest_trial210,test_accession1,\ntest_trial23,test_accession2,review_upload_name\n", undef, preview => 1);
    is($r->{preview}->{changed}, 2, 'preview: two plots will change') or diag(explain $r);
    is($r->{preview}->{rows_read}, 2, 'the preview says how many plot rows the file had');
    is(scalar(@{ additional_files($trial_id) }) - scalar(@$files_before), 0, 'a preview keeps no file with the trial');
    $r = $upload->("plot_name,accession_name,new_plot_name\ntest_trial210,test_accession1,\ntest_trial23,test_accession2,review_upload_name\n");
    is($r->{success}, 1, 'success') or diag(explain $r);
    is($r->{changed}, 2, 'two plots changed');
    is(plot_state($plot{10})->{accession}, 'test_accession1', 'plot 10');
    is_deeply([ @{plot_state($plot{3})}{'name', 'accession'} ], [ 'review_upload_name', 'test_accession2' ], 'plot 3 renamed');
    is(cached_accession('review_upload_name'), 'test_accession2', 'cached layout');
    is(scalar(@{ additional_files($trial_id) }) - scalar(@$files_before), 1, 'the applied file is kept with the trial');
    restore();

    my $obsolete = $schema->resultset('Stock::Stock')->create({ uniquename => 'review_obsolete_<b>accession</b>', name => 'review_obsolete', type_id => $t{accession}, organism_id => $organism_id, is_obsolete => 1 });
    $r = $upload->("plot_name,accession_name\ntest_trial210,review_obsolete_<b>accession</b>\n");
    like($r->{error}, qr/review_obsolete_&lt;b&gt;accession&lt;\/b&gt; is obsolete/, 'obsolete accession refused, escaped for HTML');
    $obsolete->delete;
    is(plot_state($plot{10})->{accession}, 'test_accession3', 'nothing changed');

    $r = $upload->("plot_name,accession_name\ntest_trial210,test_trial21\n");
    like($r->{error}, qr/test_trial21 is not an accession\./, 'a plot as new accession refused');

    $r = $upload->("plot_name,accession_name\ntest_trial210,test_accession1\n", Test::WWW::Mechanize->new);
    like($r->{error}, qr/logged in/, 'not logged in');
    is_deeply(trial_state(), $original, 'nothing changed');
};

subtest 'Change Accessions upload: a plot that someone else changed after the preview is not changed over their head' => sub {
    my $file = "plot_name,accession_name\ntest_trial210,test_accession1\n";
    my $r = upload_accessions($trial_id, $file, preview => 1);
    my $digest = $r->{preview}->{plan_digest};
    ok($digest, 'the preview comes with the digest of its plan (test_accession3 -> test_accession1)') or diag(explain $r);
    # meanwhile someone else corrects plot 10 to test_accession2
    $schema->resultset('Stock::StockRelationship')->search({ subject_id => $plot{10}, type_id => $t{plot_of} })->update({ object_id => $acc{2} });
    $r = upload_accessions($trial_id, $file, plan_digest => $digest);
    like($r->{error}, qr/The trial changed after the preview, so the changes are not the ones you saw/, 'the file applied with the digest of the preview is refused') or diag(explain $r);
    is(plot_state($plot{10})->{accession}, 'test_accession2', 'the other change stays');
    is_deeply([ @{ $r }{'success', 'changed'} ], [ undef, undef ], 'nothing was changed');
    restore();
};

subtest 'a submitter of the program corrects a trial; a trial with phenotypes needs a curator' => sub {
    my $submitter = Test::WWW::Mechanize->new;
    $submitter->post_ok("$base/brapi/v1/token", [ username => 'johndoe', password => 'secretpw', grant_type => 'password' ], 'login as johndoe, a submitter of the program');
    my $r = upload_as($submitter, $trial_id, "plot_name,accession_name\ntest_trial210,test_accession1\n", preview => 1);
    is($r->{preview}->{changed}, 1, 'the submitter gets the preview for a trial without phenotypes') or diag(explain $r);

    my $phenotyped_trial_id = $schema->resultset('Project::Project')->find({ name => 'CASS_6Genotypes_Sampling_2015' })->project_id;
    my ($cass_plot) = sort { $a->{plot_number} <=> $b->{plot_number} } values %{ CXGN::Trial::AccessionChange->new({ schema => $schema, trial_id => $phenotyped_trial_id })->load_units() };
    $r = upload_as($submitter, $phenotyped_trial_id, "plot_name,accession_name\n$cass_plot->{plot_name},test_accession1\n", preview => 1, override => 1);
    like($r->{error}, qr/traits have been assayed/, 'a trial with phenotypes: the submitter is refused, override or not') or diag(explain $r);
    ok(!$r->{warning}, 'and not asked');
    $submitter->post("$base/ajax/breeders/trial/$phenotyped_trial_id/replace_plot_accessions", [ new_accession => 'test_accession1', old_plot_id => $cass_plot->{plot_id}, old_plot_name => $cass_plot->{plot_name}, new_plot_name => '', override => 'override' ]);
    like(decode_json($submitter->content)->{error}, qr/traits have been assayed/, 'the plot form refuses the submitter too');
    like(post_json("/ajax/breeders/trial/$phenotyped_trial_id/replace_stock", [ old_stock_id => $cass_plot->{stock_id}, new_stock => 'test_accession1', trial_stock_type => 'accession', preview => 1 ])->{error}, qr/traits have been assayed/, 'Replace Accession is refused for a trial with phenotypes, also for a curator');
    my $unchanged = CXGN::Trial::AccessionChange->new({ schema => $schema, trial_id => $phenotyped_trial_id })->load_units()->{ $cass_plot->{plot_id} };
    is($unchanged->{stock_id}, $cass_plot->{stock_id}, 'the plot keeps its accession');
};

subtest 'Change Accessions upload: keeping the plot names' => sub {
    my $upload = sub { return upload_accessions($trial_id, @_) };
    rename_plot($plot{3}, 'test_trial-rep1-test_accession3_3');
    rename_plot($plot{4}, 'test_trial-rep2-test_accession3_4');
    my $r = $upload->("plot_name,accession_name\ntest_trial-rep1-test_accession3_3,test_accession2\n", keep_plot_names => 1);
    is($r->{success}, 1, 'success') or diag(explain $r);
    is(plot_state($plot{3})->{name}, 'test_trial-rep1-test_accession3_3', 'keep_plot_names keeps the name');
    is(plot_state($plot{3})->{accession}, 'test_accession2', 'accession changed');
    $r = $upload->("plot_name,accession_name,new_plot_name\ntest_trial-rep2-test_accession3_4,test_accession2,test_trial-rep2-test_accession3_4\n");
    is($r->{success}, 1, 'a new_plot_name that is the current name is accepted') or diag(explain $r);
    is(plot_state($plot{4})->{name}, 'test_trial-rep2-test_accession3_4', 'and keeps it');
    $r = $upload->("plot_name,accession_name\ntest_trial210,test_accession2\n");
    is(plot_state($plot{10})->{accession}, 'test_accession2', 'without the option: changed too');
    restore();
};

subtest 'Change Accessions upload at the end of the season: the trial has phenotypes' => sub {
    my $phenotyped_trial_id = $schema->resultset('Project::Project')->find({ name => 'CASS_6Genotypes_Sampling_2015' })->project_id;
    my $ac = CXGN::Trial::AccessionChange->new({ schema => $schema, trial_id => $phenotyped_trial_id });
    my @plots = sort { $a->{plot_number} <=> $b->{plot_number} } values %{ $ac->load_units() };
    # plot 201 has no phenotypes: it was skipped (not planted), 202 and 203 have phenotypes and got the packets of 201 and 202
    my ($first) = grep { $plots[$_]->{plot_number} == 201 } 0 .. $#plots;
    my @stretch = @plots[$first .. $first + 2];
    my %saved = map { $_->{plot_id} => [ $_->{stock_id}, $_->{plot_name} ] } @stretch;
    my $saved_replication=replication_state($ac);
    my $saved_physical={map {$_->{plot_id}=>[$_->{block},$_->{design_replicate}]} @plots};
    my $phenotypes_h = $schema->storage->dbh->prepare("SELECT count(*) FROM nd_experiment_stock nes JOIN nd_experiment_phenotype nep ON nep.nd_experiment_id = nes.nd_experiment_id WHERE nes.stock_id = ?");
    my $phenotypes = sub { $phenotypes_h->execute($_[0]); return ($phenotypes_h->fetchrow_array())[0]; };
    my %phenotype_count = map { $_->{plot_id} => $phenotypes->($_->{plot_id}) } @stretch;
    is($phenotype_count{ $stretch[0]->{plot_id} }, 0, 'the first plot has no phenotypes');
    ok($phenotype_count{ $stretch[1]->{plot_id} } > 0, 'the others have');

    my $cass_files = additional_files($phenotyped_trial_id);
    my $file = "plot_name,accession_name,not_planted\n"
        .join('', map { "$stretch[$_]->{plot_name},".($stretch[$_ ? $_ - 1 : 0]->{stock_name}).",".($_ ? 0 : 1)."\n" } 0 .. 2);
    my $r = upload_accessions($phenotyped_trial_id, $file, preview => 1);
    like($r->{warning}, qr/traits have been assayed/, 'curators are warned first, with the reason');
    $r = upload_accessions($phenotyped_trial_id, $file, preview => 1, override => 1);
    ok($r->{preview}->{plots_with_phenotypes} > 0, 'the preview counts the plots with phenotypes') or diag(explain $r);
    ok((grep { /already have phenotypes/ } @{ $r->{preview}->{warnings} }), 'and warns that the values count for the new accessions');
    $r = upload_accessions($phenotyped_trial_id, $file, override => 1);
    is($r->{success}, 1, 'changed with override') or diag(explain $r);
    my $after = $ac->load_units();
    is($after->{ $stretch[1]->{plot_id} }->{stock_id}, $stretch[0]->{stock_id}, 'the second plot has the accession planned for the first');
    is_deeply({ map { $_->{plot_id} => $phenotypes->($_->{plot_id}) } @stretch }, \%phenotype_count, 'every plot keeps its phenotypes');
    is($after->{ $stretch[0]->{plot_id} }->{not_planted}, '1', 'the first plot is not planted');
    is_deeply({map {$_=>[$after->{$_}{block},$after->{$_}{design_replicate}]} keys %$after},$saved_physical,'season-end accession correction preserves all recorded design groups and blocks');
    for my $stock_id (keys %{ {map {$_->{stock_id}=>1} values %$after} }) {
        my @values=sort {$a<=>$b} map {$_->{replicate}} grep {$_->{stock_id}==$stock_id} values %$after;
        is_deeply(\@values,[1..scalar(@values)],'season-end correction retains every planned occurrence, including unsown places');
    }

    # a plot with observations cannot become not planted by deleting its raw values
    $r = upload_accessions($phenotyped_trial_id, "plot_name,accession_name,not_planted\n$stretch[1]->{plot_name},$stretch[0]->{stock_name},1\n", preview => 1, override => 1);
    like($r->{error}, qr/phenotype value\(s\) were stored for plots that are marked as not planted \(\Q$stretch[1]->{plot_name}\E\)/, 'a plot with phenotypes must retain the raw observations');
    ok($r->{not_planted_phenotypes} > 0, 'the page can explain the retained observations');

    # put the trial back
    $ac->apply([map {{plot_id=>$_,new_stock_id=>$saved{$_}[0],new_plot_name=>$saved{$_}[1],not_planted=>0}} keys %saved],{curator=>1,rename_plots=>'none'});
    restore_replication_state($saved_replication);
    $schema->storage->dbh->do('SELECT refresh_materialized_phenotype_jsonb_table()');
    obsolete_new_files($phenotyped_trial_id, $cass_files);
    $mech->get_ok("$base/ajax/breeders/trial/$phenotyped_trial_id/refresh_cache");
    is_deeply({ map { $_->{plot_id} => [ $_->{stock_id}, $_->{plot_name} ] } grep { $saved{ $_->{plot_id} } } values %{ $ac->load_units() } }, \%saved, 'restored');
};

subtest 'Change Accessions upload: the not_planted column' => sub {
    my $upload = sub { return upload_accessions($trial_id, @_) };
    my $r = $upload->("plot_name,accession_name,not_planted\ntest_trial24,$original->{4}->{accession},1\ntest_trial25,test_accession2,\ntest_trial26,$original->{6}->{accession},0\n", preview => 1);
    is_deeply($r->{preview}->{planting}, [ { plot_name => 'test_trial24', not_planted => 1 } ], 'preview: plot 4 will be marked as not planted') or diag(explain $r);
    is_deeply(trial_state(), $original, 'preview changes nothing');
    $r = $upload->("plot_name,accession_name,not_planted\ntest_trial24,$original->{4}->{accession},1\ntest_trial25,test_accession2,\ntest_trial26,$original->{6}->{accession},0\n");
    is($r->{success}, 1, 'success') or diag(explain $r);
    is_deeply($r->{planting}, [ { plot_name => 'test_trial24', not_planted => 1 } ], 'plot 4 marked as not planted');
    is_deeply([ map { plot_state($plot{$_})->{not_planted} } (4, 5, 6) ], [ '1', undef, undef ], 'stored');
    is(plot_state($plot{4})->{accession}, $original->{4}->{accession}, 'plot 4 keeps its accession');
    is(plot_state($plot{5})->{accession}, 'test_accession2', 'and plot 5 changed in the same file');
    restore();

    $r = $upload->("plot_name,accession_name,not_planted\ntest_trial25,$original->{5}->{accession},1\n");
    is_deeply([ map { plot_state($plot{$_})->{rep} } (5, 8, 11) ], [ 1, 2, 3 ], 'CRD: the replicates are kept; plot 5 keeps its place in the design');
    my $ua = LWP::UserAgent->new;
    $ua->default_header('Authorization' => 'Bearer '.$access_token);
    my $unit = sub { return decode_json($ua->get("$base/brapi/v2/observationunits/$_[0]")->decoded_content)->{result}; };
    ok($unit->($plot{5})->{additionalInfo}->{notPlanted}, 'BrAPI: additionalInfo.notPlanted');
    ok(!exists(($unit->($plot{8})->{additionalInfo} || {})->{notPlanted}), 'BrAPI: not for a planted plot');
    $r = $upload->("plot_name,accession_name,not planted\ntest_trial25,$original->{5}->{accession},no\n");
    is_deeply($r->{planting}, [ { plot_name => 'test_trial25', not_planted => 0 } ], "'not planted' with 'no' plants it again");
    is_deeply(trial_state(), $original, 'as before');
    $r = $upload->("plot_name,accession_name,not_planted\ntest_trial24,$original->{4}->{accession},maybe\n");
    like($r->{error}, qr/Plot test_trial24: not_planted must be 1 \(not planted\) or 0 \(planted\), not maybe\./, 'an unknown value is refused');
    restore();
};

subtest 'Change Accessions upload: a planting order file, corrected and uploaded again' => sub {
    # 3 rows of 5 columns, planted by column, serpentine, with border rows at the bottom and the top:
    # border, 1, 6, 11, border up column 1; border, 12, 7, 2, border down column 2; border, 3, 8, 13, border up column 3 ...
    foreach my $n (1 .. 15) {
        set_prop($plot{$n}, 'row_number', int(($n - 1) / 5) + 1);
        set_prop($plot{$n}, 'col_number', ($n - 1) % 5 + 1);
    }
    $mech->get_ok("$base/ajax/breeders/trial/$trial_id/refresh_cache");
    my $download = sub {
        $mech->get_ok("$base/ajax/breeders/trial_plot_order?trial_ids=$trial_id&type=planting&order=by_col_serpentine&start=bottom_left&top_border=true&bottom_border=true", 'download the planting order');
        my ($header, @rows) = map { [ split /,/, $_, -1 ] } grep { /\S/ } split /\r?\n/, $mech->content;
        my %col = map { $header->[$_] => $_ } 0 .. $#$header;
        return ($header, \@rows, \%col);
    };
    my $upload = sub {
        my ($header, $rows, @fields) = @_;
        return upload_accessions($trial_id, join("\n", map { join(',', @$_) } $header, @$rows)."\n", keep_plot_names => 1, @fields);
    };
    my ($header, $rows, $col) = $download->();
    is_deeply([ map { $_->[ $col->{type} ] eq 'plot' ? ($_->[ $col->{plot_name} ] =~ /^test_trial2(\d+)$/)[0] + 0 : 'b' } grep { $_->[ $col->{col_number} ] == 2 } @$rows ], [ 'b', 12, 7, 2, 'b' ], 'column 2 in the file: border, 12, 7, 2, border');
    is_deeply([ map { $_->[ $col->{type} ] eq 'plot' ? ($_->[ $col->{plot_name} ] =~ /^test_trial2(\d+)$/)[0] + 0 : 'b' } grep { $_->[ $col->{col_number} ] == 3 } @$rows ], [ 'b', 3, 8, 13, 'b' ], 'column 3: border, 3, 8, 13, border');
    ok(!exists($col->{not_planted}), 'no not_planted column while every plot is planted');

    # the place of plot 8 was skipped: plot 13 got the packet of plot 8, the packet of plot 13 went into the top border
    push @$header, 'not_planted';
    my %row_of = map { $_->[ $col->{plot_name} ] => $_ } grep { $_->[ $col->{type} ] eq 'plot' } @$rows;
    push @$_, '' for @$rows;
    my ($top_border) = grep { $_->[ $col->{type} ] eq 'border' && $_->[ $col->{col_number} ] == 3 && $_->[ $col->{row_number} ] == 4 } @$rows;
    $top_border->[ $col->{accession_name} ] = $row_of{test_trial213}->[ $col->{accession_name} ];
    $row_of{test_trial213}->[ $col->{accession_name} ] = $row_of{test_trial28}->[ $col->{accession_name} ];
    $row_of{test_trial28}->[-1] = 1;

    my $r = $upload->($header, $rows, preview => 1);
    is($r->{preview}->{changed}, 1, 'preview: one plot gets another accession') or diag(explain $r);
    is_deeply($r->{preview}->{planting}, [ { plot_name => 'test_trial28', not_planted => 1 } ], 'preview: plot 8 is not planted; the border rows are skipped');
    is_deeply(trial_state(), $original, 'preview changes nothing');

    $r = $upload->($header, $rows);
    is($r->{success}, 1, 'uploaded') or diag(explain $r);
    is_deeply([ plot_state($plot{13})->{accession}, plot_state($plot{8})->{accession}, plot_state($plot{8})->{not_planted} ], [ $original->{8}->{accession}, $original->{8}->{accession}, '1' ], 'plot 13 has the accession planned for plot 8, plot 8 is not planted');

    $r = $upload->($header, $rows, preview => 1);
    is_deeply([ $r->{preview}->{changed}, $r->{preview}->{planting} ], [ 0, [] ], 'the same file again: nothing to change');
    $r = $upload->($header, $rows);
    is_deeply([ $r->{success}, $r->{changed} ], [ 1, 0 ], 'uploading it again changes nothing');
    is(plot_state($plot{13})->{accession}, $original->{8}->{accession}, 'plot 13 is as after the first upload');

    # a later correction starts from a new download, which has the not_planted column now
    ($header, $rows, $col) = $download->();
    ok(exists($col->{not_planted}), 'the new download has a not_planted column');
    %row_of = map { $_->[ $col->{plot_name} ] => $_ } grep { $_->[ $col->{type} ] eq 'plot' } @$rows;
    is_deeply([ map { $row_of{$_}->[ $col->{not_planted} ] } qw(test_trial28 test_trial212) ], [ 1, 0 ], 'with plot 8 not planted');
    $row_of{test_trial212}->[ $col->{not_planted} ] = 1;
    $r = $upload->($header, $rows);
    is_deeply($r->{planting}, [ { plot_name => 'test_trial212', not_planted => 1 } ], 'second correction: plot 12 not planted too') or diag(explain $r);
    is_deeply([ map { plot_state($plot{$_})->{not_planted} } (8, 12) ], [ '1', '1' ], 'plots 8 and 12 are not planted');

    # the layout download of the Change Accessions dialog (by plot number), uploaded as it is, changes nothing
    my $columns = uri_escape('{"plot_name":1,"accession_name":1,"plot_number":1,"block_number":1,"not_planted":1,"rep_number":1,"row_number":1,"col_number":1}');
    $mech->get_ok("$base/breeders/trial/$trial_id/download/layout?format=xlsx&dataLevel=plots&selected_columns=$columns", 'the layout as Excel');
    my ($xlsx_fh, $xlsx) = tempfile(SUFFIX => '.xlsx', UNLINK => 1);
    binmode($xlsx_fh);
    print $xlsx_fh $mech->response->content;
    close($xlsx_fh);
    $mech->post("$base/ajax/breeders/trial/$trial_id/change_plot_accessions_using_file/check", Content_Type => 'form-data', Content => [ trial_design_change_accessions_file => [ $xlsx, 'layout.xlsx' ], keep_plot_names => 1, preview => 1 ]);
    $r = decode_json($mech->content);
    is_deeply([ $r->{preview}->{changed}, $r->{preview}->{planting} ], [ 0, [] ], 'the Excel file uploaded as it is: nothing to change') or diag(explain $r);
    $mech->get_ok("$base/breeders/trial/$trial_id/download/layout?format=csv&dataLevel=plots&selected_columns=$columns", 'the layout as CSV');
    my ($layout_header, @layout_rows) = map { [ map { s/^"|"$//gr } split /,/, $_, -1 ] } grep { /\S/ } split /\r?\n/, $mech->content;
    is_deeply($layout_header, [ qw(plot_name accession_name plot_number block_number rep_number row_number col_number not_planted) ], 'with plot_name, accession_name and not_planted (last, so that the other columns stay where they are)');
    $r = $upload->($layout_header, \@layout_rows, preview => 1);
    is_deeply([ $r->{preview}->{changed}, $r->{preview}->{planting} ], [ 0, [] ], 'uploaded unchanged: nothing to change') or diag(explain $r);

    $schema->resultset('Stock::Stockprop')->search({ stock_id => { -in => [ values %plot ] }, type_id => { -in => [ $t{row_number}, $t{col_number} ] } })->delete;
    restore();
};

subtest 'Change Accessions upload: what the parser reads' => sub {
    my $r = upload_accessions($trial_id, "plot_name,accession_name\n<b>x</b>,test_accession1\n");
    like($r->{error}, qr/Plot &lt;b&gt;x&lt;\/b&gt; does not exist in this trial/, 'names from the file are escaped in errors');
    $r = upload_accessions($trial_id, "Plot;Accession\ntest_trial21;test_accession1\n");
    like($r->{error} // '', qr/plot_name/, 'a file without a plot_name column is an error, not a crash') or diag(explain $r);
    $r = upload_accessions($trial_id, "trial_name,plot_name,accession_name,not_planted\nother_trial,other_trial_plot_1,test_accession1,\ntest_trial,test_trial25,,1\n", preview => 1);
    is_deeply($r->{preview}->{planting}, [ { plot_name => 'test_trial25', not_planted => 1 } ], 'rows of other trials are skipped; a plot that was not planted needs no accession') or diag(explain $r);
    is_deeply($r->{preview}->{warnings}, [ '1 row(s) of trial other_trial were skipped; upload the file in that trial too if it has corrections there.' ], 'a planting-only preview has exactly the parser warning') or diag(explain $r);
    $r = upload_accessions($trial_id, "trial_name,plot_name,accession_name\nother_trial,other_trial_plot_1,test_accession1\ntest_trial,test_trial25,test_accession2\n", preview => 1);
    is_deeply([ $r->{preview}->{rows_read}, $r->{preview}->{changed} ], [ 1, 1 ], 'an accession correction reads one current-trial row and changes one accession') or diag(explain $r);
    my @parser_warnings=grep {!/^Design:/} @{$r->{preview}->{warnings} || []};
    is_deeply(\@parser_warnings, [ '1 row(s) of trial other_trial were skipped; upload the file in that trial too if it has corrections there.' ], 'and the preview preserves the exact parser warning') or diag(explain $r);
    like(join("\n",@{$r->{preview}->{warnings} || []}),qr/^Design: .*no longer balanced/m,'the same preview also reports its actual design imbalance');
    $r = upload_accessions($trial_id, "trial_name,plot_name,accession_name\nother_trial,other_trial_plot_1,test_accession1\n");
    like($r->{error} // '', qr/The file has no plots of this trial \(it is a file of trial other_trial\)/, 'a file of another trial') or diag(explain $r);
    $r = upload_accessions($trial_id, "Type,Trial Name,Plot Name,Accession Name\nborder,,,\nplot,test_trial,test_trial25,test_accession2\ncheck,test_trial,test_trial26,$original->{6}->{accession}\n", preview => 1);
    is_deeply([ $r->{preview}->{rows_read}, $r->{preview}->{changed} ], [ 2, 1 ], 'headers as written by hand: the border row is skipped, a row of another type (check) is read as a plot') or diag(explain $r);
    is_deeply(trial_state(), $original, 'nothing changed');
};

subtest 'Change Accessions upload: a trial planted from seedlots' => sub {
    # a seedlot of 100 seeds for each accession, 10 seeds planted in each plot
    my %seedlot;
    foreach my $n (sort { $a <=> $b } keys %plot) {
        my $accession = $original->{$n};
        $seedlot{ $accession->{accession} } //= do {
            my $name = "review_upload_seedlot_$accession->{accession}";
            my $seedlot = $schema->resultset('Stock::Stock')->create({ uniquename => $name, name => $name, type_id => $t{seedlot}, organism_id => $organism_id });
            $schema->resultset('Stock::StockRelationship')->create({ subject_id => $accession->{accession_id}, object_id => $seedlot->stock_id, type_id => $t{collection_of} });
            CXGN::Stock::Seedlot::Transaction->new(schema => $schema, from_stock => [ $seedlot->stock_id, $name ], to_stock => [ $seedlot->stock_id, $name ], amount => 100, weight_gram => 'NA', factor => 1, operator => 'janedoe', timestamp => '2026-04-01', description => 'harvest')->store();
            $seedlot;
        };
        CXGN::Stock::Seedlot::Transaction->new(schema => $schema, from_stock => [ $seedlot{ $accession->{accession} }->stock_id, 'x' ], to_stock => [ $plot{$n}, $accession->{name} ], amount => 10, weight_gram => 'NA', operator => 'janedoe', timestamp => '2026-05-01', description => 'planted')->store();
    }
    my $planted_from = sub { return join(',', map { $_->object->uniquename } $schema->resultset('Stock::StockRelationship')->search({ subject_id => $_[0], type_id => $t{seed_transaction} })->all); };
    $mech->get_ok("$base/ajax/breeders/trial/$trial_id/refresh_cache");

    # the layout as the Change Accessions dialog downloads it, with the seedlots
    my $download = sub {
        my $columns = uri_escape('{"plot_name":1,"accession_name":1,"plot_number":1,"block_number":1,"not_planted":1,"rep_number":1,"row_number":1,"col_number":1,"seedlot_name":1}');
        $mech->get_ok("$base/breeders/trial/$trial_id/download/layout?format=csv&dataLevel=plots&selected_columns=$columns", 'download the layout');
        my ($header, @rows) = map { [ map { s/^"|"$//gr } split /,/, $_, -1 ] } grep { /\S/ } split /\r?\n/, $mech->content;
        return ($header, \@rows, { map { $header->[$_] => $_ } 0 .. $#$header });
    };
    my ($header, $rows, $col) = $download->();
    my %row_of = map { $_->[ $col->{plot_name} ] => $_ } @$rows;
    is($row_of{test_trial24}->[ $col->{seedlot_name} ], "review_upload_seedlot_$original->{4}->{accession}", 'with the seedlot of each plot');
    my $csv = sub { return join("\n", map { join(',', @$_) } $header, @$rows)."\n"; };

    # saved seedlots are a reason to ask, as for the field map: a curator is warned and confirms, Replace Accession is refused
    my $r = upload_accessions($trial_id, $csv->(), preview => 1);
    like($r->{warning}, qr/Seedlots have already been saved/, 'the upload warns the curator that the trial has seedlots') or diag(explain $r);
    like(post_json($replace_stock, [ old_stock_id => $acc{3}, new_stock => 'test_accession1', trial_stock_type => 'accession', preview => 1 ])->{error}, qr/Seedlots have already been saved/, 'Replace Accession is refused, as before');
    $r = upload_accessions($trial_id, $csv->(), preview => 1, override => 1);
    is_deeply([ $r->{warning}, $r->{preview}->{changed}, $r->{preview}->{seedlots}, $r->{preview}->{planting} ], [ undef, 0, [], [] ], 'the layout uploaded as it is, confirmed: nothing to change') or diag(explain $r);

    # plot 4 was skipped: plots 5 to 8 got the packets planned for 4 to 7, the packet of 8 went into a border;
    # only accession_name and not_planted are corrected, the seedlot_name cells are left as they are
    my @accessions = map { $row_of{"test_trial2$_"}->[ $col->{accession_name} ] } 4 .. 8;
    $row_of{"test_trial2$_"}->[ $col->{accession_name} ] = $accessions[$_ - 5] for 5 .. 8;
    $row_of{test_trial24}->[ $col->{not_planted} ] = 1;
    $r = upload_accessions($trial_id, $csv->(), preview => 1, override => 1, keep_plot_names => 1);
    is_deeply([ map { [ $_->{type}, $_->{from_plot_name} // '', $_->{plot_name} ] } @{ $r->{preview}->{seedlots} } ],
        [ (map { [ 'move', 'test_trial2'.($_ - 1), "test_trial2$_" ] } 5 .. 8), [ 'taken', '', 'test_trial28' ] ],
        'preview: the seed transactions follow the packets, the packet of plot 8 is in no plot') or diag(explain $r);
    $r = upload_accessions($trial_id, $csv->(), override => 1, keep_plot_names => 1);
    is($r->{success}, 1, 'changed') or diag(explain $r);
    is_deeply([ map { $planted_from->($plot{$_}) } 4 .. 8 ], [ '', map { "review_upload_seedlot_$original->{$_}->{accession}" } 4 .. 7 ], 'plots 5 to 8 were planted from the seedlots of their new accessions, plot 4 from none');

    # the same file again (its seedlot cells are those of before the packets moved) changes nothing
    $r = upload_accessions($trial_id, $csv->(), preview => 1, override => 1, keep_plot_names => 1);
    is_deeply([ $r->{error}, $r->{preview}->{changed}, $r->{preview}->{seedlots}, $r->{preview}->{planting}, $r->{preview}->{warnings} ], [ undef, 0, [], [], [] ], 'the same file again: nothing to change') or diag(explain $r);

    # a new download, uploaded as it is, changes nothing
    ($header, $rows, $col) = $download->();
    $r = upload_accessions($trial_id, $csv->(), preview => 1, override => 1, keep_plot_names => 1);
    is_deeply([ $r->{preview}->{changed}, $r->{preview}->{seedlots}, $r->{preview}->{planting} ], [ 0, [], [] ], 'the new download uploaded as it is: nothing to change') or diag(explain $r);

    my @seedlot_ids = map { $_->stock_id } values %seedlot;
    $schema->resultset('Stock::StockRelationship')->search({ type_id => $t{seed_transaction}, -or => [ subject_id => { -in => \@seedlot_ids }, object_id => { -in => \@seedlot_ids } ] })->delete;
    $_->delete for values %seedlot;
    restore();
};

subtest 'Change Accessions upload: raw phenotypes survive a refused not-planted transition' => sub {
    my $temp_file = $f->config->{cluster_shared_tempdir}."/test_temp_nd_experiment_id_delete";
    my $store = CXGN::Phenotypes::StorePhenotypes->new(
        basepath => $f->config->{basepath}, dbhost => $f->config->{dbhost}, dbname => $f->config->{dbname}, dbuser => $f->config->{dbuser}, dbpass => $f->config->{dbpass},
        temp_file_nd_experiment_id => $temp_file, bcs_schema => $schema, metadata_schema => $f->metadata_schema, phenome_schema => $f->phenome_schema, user_id => 41,
        stock_list => [ 'test_trial210' ], trait_list => [ 'dry yield|CO_334:0000014' ], values_hash => { test_trial210 => { 'dry yield|CO_334:0000014' => [ 30, '' ] } },
        has_timestamps => 0, overwrite_values => 0, metadata_hash => { operator => 'janedoe', date => '20260901' },
        composable_validation_check_name => $f->config->{composable_validation_check_name},
    );
    my (undef, undef, $seed_details) = $store->store();
    my @created_phenotypes = map { $_->{observationDbId} } @$seed_details;
    my $values_h = $schema->storage->dbh->prepare("SELECT count(*) FROM nd_experiment_stock nes JOIN nd_experiment_phenotype nep USING (nd_experiment_id) WHERE nes.stock_id = ?");
    my $values = sub { $values_h->execute($_[0]); return ($values_h->fetchrow_array())[0]; };
    is($values->($plot{10}), 1, 'plot 10 has a phenotype');

    my $file = "plot_name,accession_name,not_planted\ntest_trial210,$original->{10}->{accession},1\n";
    my $r = upload_accessions($trial_id, $file, preview => 1, override => 1);
    like($r->{error}, qr/1 phenotype value\(s\) were stored for plots that are marked as not planted \(test_trial210\)/, 'the preview refuses');
    is($r->{not_planted_phenotypes}, 1, 'and counts the values, so that the page can ask');
    $r = upload_accessions($trial_id, $file, preview => 1, override => 1, delete_phenotypes => 1);
    like($r->{error}, qr/values are retained/, 'legacy deletion option is refused during preview');
    is($values->($plot{10}), 1, 'preview preserves the measurement');
    $r = upload_accessions($trial_id, $file, override => 1, delete_phenotypes => 1);
    like($r->{error}, qr/values are retained/, 'apply also refuses deleting observations through a status change');
    is($values->($plot{10}), 1, 'recorded phenotype remains');
    ok(!plot_state($plot{10})->{not_planted}, 'planting state remains unchanged');
    # Remove only the synthetic observations created by this test, not trial data.
    my $db = $schema->storage->dbh;
    my $experiments = $db->selectcol_arrayref('SELECT DISTINCT nd_experiment_id FROM nd_experiment_phenotype WHERE phenotype_id = ANY(?)', undef, \@created_phenotypes);
    $db->do('DELETE FROM phenotype WHERE phenotype_id = ANY(?)', undef, \@created_phenotypes);
    $db->do('DELETE FROM nd_experiment WHERE nd_experiment_id = ANY(?) AND NOT EXISTS (SELECT 1 FROM nd_experiment_phenotype ep WHERE ep.nd_experiment_id = nd_experiment.nd_experiment_id)', undef, $experiments);
    $db->do('SELECT refresh_materialized_phenotype_jsonb_table()');
    restore();
};

subtest 'Change Accessions upload: the rejected and reject_reason columns' => sub {
    my $r = upload_accessions($trial_id, "plot_name,accession_name,rejected,reject_reason\ntest_trial210,test_accession3,1,trampled by cattle\ntest_trial23,test_accession3,,\n", preview => 1);
    is_deeply([ $r->{preview}->{changed}, $r->{preview}->{rejections} ], [ 0, [ { plot_name => 'test_trial210', rejected => 1, reject_reason => 'trampled by cattle', was_rejected => 0 } ] ], 'preview: one plot will be rejected, nothing else changes') or diag(explain $r);
    $r = upload_accessions($trial_id, "plot_name,accession_name,rejected,reject_reason\ntest_trial210,test_accession3,1,trampled by cattle\n");
    is_deeply([ $r->{success}, $r->{rejections} ], [ 1, [ { plot_name => 'test_trial210', rejected => 1, reject_reason => 'trampled by cattle', was_rejected => 0 } ] ], 'applied') or diag(explain $r);
    is_deeply([ @{ plot_state($plot{10}) }{qw(accession rejected reject_reason not_planted)} ], [ 'test_accession3', '1', 'trampled by cattle', undef ], 'the plot is rejected, with its accession, planted');
    is(cached_accession('test_trial210'), 'test_accession3', 'the cached layout still has the plot');

    # the layout download: the two columns come last once a plot is rejected; a changed reason is the only change
    my $columns = uri_escape('{"plot_name":1,"accession_name":1,"plot_number":1,"block_number":1,"rep_number":1,"row_number":1,"col_number":1}');
    $mech->get_ok("$base/breeders/trial/$trial_id/download/layout?format=csv&dataLevel=plots&selected_columns=$columns", 'the layout as CSV');
    my $parse_csv = sub { my $p = Text::CSV->new({ binary => 1 }); return map { $p->parse($_) ? [ $p->fields() ] : die("not CSV: $_") } grep { /\S/ } split /\r?\n/, $_[0]; };
    my ($header, @rows) = $parse_csv->($mech->content);
    is_deeply([ @$header[-2, -1] ], [ 'rejected', 'reject_reason' ], 'rejected and reject_reason are the last columns');
    my %col = map { $header->[$_] => $_ } 0 .. $#$header;
    my ($row) = grep { $_->[ $col{plot_name} ] eq 'test_trial210' } @rows;
    is_deeply([ @$row[ $col{rejected}, $col{reject_reason} ] ], [ 1, 'trampled by cattle' ], 'with the values');
    my $csv = sub { return join("\n", map { join(',', map { my $v = $_ // ''; $v =~ s/"/""/g; "\"$v\"" } @$_) } $header, @rows)."\n" };
    $r = upload_accessions($trial_id, $csv->(), preview => 1, keep_plot_names => 1);
    is_deeply([ $r->{preview}->{changed}, $r->{preview}->{rejections} ], [ 0, [] ], 'the download uploaded as it is: nothing to change') or diag(explain $r);
    # a reason is free text, with commas and quotes
    my $reason = 'trampled, then "flooded"';
    $row->[ $col{reject_reason} ] = $reason;
    $r = upload_accessions($trial_id, $csv->(), keep_plot_names => 1);
    is_deeply($r->{rejections}, [ { plot_name => 'test_trial210', rejected => 1, reject_reason => $reason, was_rejected => 1 } ], 'a changed reason is the change') or diag(explain $r);
    is(plot_state($plot{10})->{reject_reason}, $reason, 'stored');
    $mech->get_ok("$base/breeders/trial/$trial_id/download/layout?format=csv&dataLevel=plots&selected_columns=$columns", 'the layout as CSV again');
    my ($reason_row) = grep { $_->[ $col{plot_name} ] eq 'test_trial210' } $parse_csv->($mech->content);
    is($reason_row->[ $col{reject_reason} ], $reason, 'the layout CSV keeps the reason in one cell');

    # the planting order download has the columns too
    foreach my $n (1 .. 15) {
        set_prop($plot{$n}, 'row_number', int(($n - 1) / 5) + 1);
        set_prop($plot{$n}, 'col_number', ($n - 1) % 5 + 1);
    }
    $mech->get_ok("$base/ajax/breeders/trial/$trial_id/refresh_cache");
    $mech->get_ok("$base/ajax/breeders/trial_plot_order?trial_ids=$trial_id&type=planting&order=by_col_serpentine&start=bottom_left", 'download the planting order');
    my $order_file = $mech->content;
    my ($order_header, @order_rows) = $parse_csv->($order_file);
    my %order_col = map { $order_header->[$_] => $_ } 0 .. $#$order_header;
    my ($order_row) = grep { ($_->[ $order_col{plot_name} ] // '') eq 'test_trial210' } @order_rows;
    is_deeply([ @$order_row[ $order_col{rejected}, $order_col{reject_reason} ] ], [ 1, $reason ], 'the planting order file has rejected and reject_reason, the reason in one cell') or diag(explain [ $order_header, $order_row ]);
    $r = upload_accessions($trial_id, $order_file, preview => 1, keep_plot_names => 1);
    is_deeply([ $r->{error}, $r->{preview}->{rejections} ], [ undef, [] ], 'uploaded as it is: the reason is read whole, nothing to change') or diag(explain $r);
    $schema->resultset('Stock::Stockprop')->search({ stock_id => { -in => [ values %plot ] }, type_id => { -in => [ $t{row_number}, $t{col_number} ] } })->delete;

    # what the parser refuses
    like(upload_accessions($trial_id, "plot_name,accession_name,reject\ntest_trial23,test_accession3,maybe\n")->{error} // '', qr/rejected must be 1 \(rejected\) or 0 \(not rejected\), not maybe/, 'the alias reject; maybe is refused');
    like(upload_accessions($trial_id, "plot_name,accession_name,rejected,reject_reason\ntest_trial23,test_accession3,0,weeds\n")->{error} // '', qr/reject_reason is given but rejected is 0/, 'a reason with rejected 0');
    like(upload_accessions($trial_id, "plot_name,accession_name,rejected,reject_reason\ntest_trial23,test_accession3,1,".('x' x 501)."\n")->{error} // '', qr/reject_reason is longer than 500 characters/, 'a reason that is too long');
    like(upload_accessions($trial_id, "plot_name,accession_name,reject_reason\ntest_trial23,test_accession3,weeds\n")->{error} // '', qr/has a reject_reason but is not rejected/, 'a reason alone on a plot that is not rejected');
    # the two states
    like(upload_accessions($trial_id, "plot_name,accession_name,not_planted,rejected\ntest_trial23,,1,1\n")->{error} // '', qr/cannot be rejected: it is not planted/, 'rejected and not planted in one row');
    $r = upload_accessions($trial_id, "plot_name,accession_name,not_planted\ntest_trial210,,1\n", preview => 1);
    is_deeply($r->{preview}->{rejections}, [ { plot_name => 'test_trial210', rejected => 0, reject_reason => undef, was_rejected => 1 } ], 'marked as not planted: the rejection is taken back') or diag(explain $r);
    ok((grep { /no longer rejected/ } @{ $r->{preview}->{warnings} }), 'with a note');
    $r = upload_accessions($trial_id, "plot_name,accession_name,not_planted\ntest_trial210,,1\n");
    is_deeply([ @{ plot_state($plot{10}) }{qw(not_planted rejected reject_reason)} ], [ '1', undef, undef ], 'not planted, no longer rejected');
    restore();
};

subtest 'a rejected plot is left out of the phenotype downloads and the trait summary, and is flagged in BrAPI' => sub {
    my $phenotyped_trial_id = $schema->resultset('Project::Project')->find({ name => 'CASS_6Genotypes_Sampling_2015' })->project_id;
    my $ac = CXGN::Trial::AccessionChange->new({ schema => $schema, trial_id => $phenotyped_trial_id });
    my ($plot) = grep { $_->{plot_name} eq 'CASS_6Genotypes_104' } values %{ $ac->load_units() };
    my $cass_files = additional_files($phenotyped_trial_id);
    my $download = sub {
        $mech->get_ok("$base/breeders/trials/phenotype/download?trial_list=%5B$phenotyped_trial_id%5D&format=csv&dataLevel=plot&speed=$_[0]", "the phenotype download ($_[0])");
        return $mech->content;
    };
    my $n_obs = sub {
        $mech->get_ok("$base/ajax/breeders/trial/$phenotyped_trial_id/phenotypes?display=plots", 'the trait summary');
        # the number of values of the trial over all traits, and the percentage missing of each trait:
        # a row is [ trait, average, min, max, stddev, cv, count, missing, histogram ]
        my $rows = decode_json($mech->content)->{data};
        my $n = 0; $n += $_->[6] // 0 for @$rows;
        return wantarray ? ($n, { map { $_->[0] => $_->[7] } @$rows }) : $n;
    };
    my $ua = LWP::UserAgent->new;
    $ua->default_header('Authorization' => 'Bearer '.$access_token);
    like($download->('Native'), qr/CASS_6Genotypes_104/, 'before: the plot is in the download');
    my ($n_before, $missing_before) = $n_obs->();
    ok($n_before > 0, 'before: the trait summary counts its values');

    my $r = upload_accessions($phenotyped_trial_id, "plot_name,accession_name,rejected,reject_reason\nCASS_6Genotypes_104,$plot->{stock_name},1,flooded after emergence\n", override => 1);
    is($r->{success}, 1, 'rejected by a curator') or diag(explain $r);
    my $native = $download->('Native');
    ok($native !~ /CASS_6Genotypes_104/ && $native =~ /CASS_6Genotypes_103/, 'the Native download leaves the plot out, the others stay');
    my $mvt = $download->('MaterializedViewTable');
    ok($mvt !~ /CASS_6Genotypes_104/ && $mvt =~ /CASS_6Genotypes_103/, 'the MaterializedViewTable download too');
    my ($n_after, $missing_after) = $n_obs->();
    ok($n_after < $n_before, 'the trait summary counts fewer values') or diag("before $n_before, after $n_after");
    # the rejected plot has a value of every trait: it leaves the denominator, so the number of plots missing a value stays
    my ($n_plots) = $schema->storage->dbh->selectrow_array("SELECT count(DISTINCT stock.stock_id) FROM stock JOIN nd_experiment_stock USING(stock_id) JOIN nd_experiment_project USING(nd_experiment_id) JOIN cvterm ON cvterm.cvterm_id = stock.type_id AND cvterm.name = 'plot' WHERE project_id = ?", undef, $phenotyped_trial_id);
    my $plots_missing = sub { my ($percent, $n) = @_; $percent =~ s/%$//; return sprintf('%.0f', $percent * $n / 100); };
    my @traits = sort keys %$missing_before;
    is_deeply([ map { $plots_missing->($missing_after->{$_}, $n_plots - 1) } @traits ], [ map { $plots_missing->($missing_before->{$_}, $n_plots) } @traits ], 'the percentage missing: the rejected plot is not counted as a plot without values') or diag(explain [ $n_plots, $missing_before, $missing_after ]);
    my $unit = decode_json($ua->get("$base/brapi/v2/observationunits/$plot->{plot_id}")->decoded_content)->{result};
    is_deeply([ $unit->{additionalInfo}->{rejected} ? 1 : 0, $unit->{additionalInfo}->{rejectReason} ], [ 1, 'flooded after emergence' ], 'BrAPI v2 observation unit: additionalInfo.rejected and rejectReason') or diag(explain $unit->{additionalInfo});
    $mech->get_ok("$base/brapi/v1/studies/$phenotyped_trial_id/layout?pageSize=300");
    my ($v1) = grep { $_->{observationUnitName} eq 'CASS_6Genotypes_104' } @{ decode_json($mech->content)->{result}->{data} };
    is_deeply([ $v1->{additionalInfo}->{rejected} ? 1 : 0, $v1->{additionalInfo}->{rejectReason} ], [ 1, 'flooded after emergence' ], 'BrAPI v1 study layout too');
    my $observations = sub { return decode_json($ua->get("$base/brapi/v2/observations?observationUnitDbId=$plot->{plot_id}&pageSize=50".($_[0] // ''))->decoded_content)->{result}->{data} };
    is(scalar(@{ $observations->() }), 0, 'BrAPI v2 observations leave its values out, like the downloads');
    my $flagged = $observations->('&includeRejected=true');
    ok(scalar(@$flagged) > 0 && !grep({ !$_->{additionalInfo}->{rejected} } @$flagged), 'with includeRejected=true (the heatmap) they are listed, each flagged rejected') or diag(explain [ scalar(@$flagged), $flagged->[0] ]);
    my $with_observations = decode_json($ua->get("$base/brapi/v2/observationunits?observationUnitDbId=$plot->{plot_id}&includeObservations=true")->decoded_content)->{result}->{data};
    is_deeply([ map { [ $_->{observationUnitName}, scalar(@{ $_->{observations} || [] }) ] } @$with_observations ], [ [ 'CASS_6Genotypes_104', 0 ] ], 'BrAPI v2 observation units with observations: the plot is listed, without its values (Trial Comparison, Boxplotter)');
    $mech->get_ok("$base/brapi/v1/studies/$phenotyped_trial_id/observationunits?pageSize=300");
    my ($v1_unit) = grep { $_->{observationUnitName} eq 'CASS_6Genotypes_104' } @{ decode_json($mech->content)->{result}->{data} };
    ok($v1_unit, 'BrAPI v1 observation units of the study still list the plot (Field Book import)');
    is(scalar(@{ ($v1_unit || {})->{observations} || [] }), 0, 'without its values');
    $mech->get_ok("$base/brapi/v1/studies/$phenotyped_trial_id/observations?pageSize=10000");
    is(scalar(grep { $_->{observationUnitDbId} eq $plot->{plot_id} } @{ decode_json($mech->content)->{result}->{data} }), 0, 'BrAPI v1 observations of the study leave its values out');
    $mech->get_ok("$base/brapi/v1/phenotypes-search?observationUnitNames=CASS_6Genotypes_104&studyDbIds=$phenotyped_trial_id&pageSize=50");
    is_deeply([ map { [ $_->{observationUnitName}, scalar(@{ $_->{observations} || [] }) ] } grep { $_->{observationUnitName} eq 'CASS_6Genotypes_104' } @{ decode_json($mech->content)->{result}->{data} } ], [ [ 'CASS_6Genotypes_104', 0 ] ], 'BrAPI v1 phenotypes-search lists the plot without its values');
    my $value_id = $flagged->[0] ? $flagged->[0]->{observationDbId} : 0;
    my $detail = decode_json($ua->get("$base/brapi/v2/observations/$value_id")->decoded_content)->{result};
    ok($detail && $detail->{additionalInfo}->{rejected}, 'BrAPI v2 observations/{id} still gives a value of a rejected plot, flagged') or diag(explain $detail);

    $r = upload_accessions($phenotyped_trial_id, "plot_name,accession_name,rejected\nCASS_6Genotypes_104,$plot->{stock_name},0\n", override => 1);
    is($r->{success}, 1, 'no longer rejected') or diag(explain $r);
    like($download->('Native'), qr/CASS_6Genotypes_104/, 'back in the download');
    is(scalar($n_obs->()), $n_before, 'and in the trait summary');
    obsolete_new_files($phenotyped_trial_id, $cass_files);
};

subtest 'substitute_stock swaps two plots and keeps their names' => sub {
    rename_plot($plot{1}, "test_trial-$original->{1}->{accession}-1");
    my $r = post_json("/ajax/breeders/trial/$trial_id/substitute_stock", [ plot_1_info => "$plot{1},x", plot_2_info => "$plot{2},y" ]);
    is($r->{success}, 1, 'success');
    is_deeply([ map { plot_state($plot{$_})->{accession} } (1, 2) ], [ $original->{2}->{accession}, $original->{1}->{accession} ], 'accessions swapped');
    is_deeply([ map { plot_state($plot{$_})->{name} } (1, 2) ], [ "test_trial-$original->{1}->{accession}-1", 'test_trial22' ], 'names kept, also one with the old accession name in it (as before)');
    is_deeply($r->{renamed}, [], 'nothing renamed');
    like(post_json("/ajax/breeders/trial/$trial_id/substitute_stock", [ plot_1_info => "$plot{1},x", plot_2_info => "$plot{1},x" ])->{error}, qr/Choose a different plot/, 'the same plot twice');
    restore();
};

subtest 'replace_well_accessions only for genotyping plates' => sub {
    like(post_json("/ajax/breeders/trial/$trial_id/replace_well_accessions", [ old_plot_id => $plot{1}, new_accession => 'test_accession1' ])->{error}, qr/not a genotyping plate/, 'refused for a field trial');
};

subtest 'BrAPI: a plot that was not planted is marked in the v1 layout, and a value for it is left out with the reason' => sub {
    my $r = upload_accessions($trial_id, "plot_name,accession_name,not_planted\ntest_trial210,,1\n");
    is($r->{success}, 1, 'plot 10 marked as not planted') or diag(explain $r);
    $mech->get_ok("$base/brapi/v1/studies/$trial_id/layout?pageSize=100");
    my ($row) = grep { $_->{observationUnitName} eq 'test_trial210' } @{ decode_json($mech->content)->{result}->{data} };
    ok($row && $row->{additionalInfo}->{notPlanted}, 'v1 layout: additionalInfo.notPlanted') or diag(explain $row);
    my $ua = LWP::UserAgent->new;
    $ua->default_header('Content-Type' => 'application/json');
    $ua->default_header('Authorization' => 'Bearer '.$access_token);
    my $values_of = sub { my ($n) = $schema->storage->dbh->selectrow_array("SELECT count(*) FROM nd_experiment_stock nes JOIN nd_experiment_phenotype nep USING(nd_experiment_id) WHERE nes.stock_id = ?", undef, $_[0]); return $n; };
    my %before = map { $_ => $values_of->($plot{$_}) } (10, 11);
    # a Field Book that lists every plot sends a value for plot 10 too
    my $resp = $ua->post("$base/brapi/v2/observations", Content => encode_json([ map { { observationUnitDbId => "$plot{$_}", observationVariableDbId => '70741', value => '15', observationTimeStamp => '2026-06-01T10:00:00Z' } } (10, 11) ]));
    ok($resp->is_success, 'v2 observations: the request succeeds') or diag($resp->decoded_content);
    my $brapi = decode_json($resp->decoded_content);
    like(join(' ', map { $_->{message} // '' } @{ $brapi->{metadata}->{status} }), qr/1 unit\(s\) were not planted, so their values were not stored: test_trial210/, 'and says that the value of plot 10 was left out') or diag($resp->decoded_content);
    is_deeply([ $values_of->($plot{10}), $values_of->($plot{11}) ], [ $before{10}, $before{11} + 1 ], 'in the database: nothing for plot 10, the value of plot 11 is stored');
    $schema->storage->dbh->do("DELETE FROM phenotype WHERE phenotype_id IN (SELECT nep.phenotype_id FROM nd_experiment_stock nes JOIN nd_experiment_phenotype nep USING(nd_experiment_id) JOIN phenotype p USING(phenotype_id) WHERE nes.stock_id = ? AND p.value = '15' AND p.cvalue_id = 70741)", undef, $plot{11});
    restore();
};

subtest 'BrAPI PUT observationunits changes the germplasm of a plot' => sub {
    my $ua = LWP::UserAgent->new;
    $ua->default_header('Content-Type' => 'application/json');
    $ua->default_header('Authorization' => 'Bearer '.$access_token);
    my $body = encode_json({ germplasmDbId => "$acc{1}", germplasmName => 'test_accession1', studyDbId => "$trial_id", observationUnitPosition => { observationLevel => { levelName => 'plot' } } });
    my $resp = $ua->put("$base/brapi/v2/observationunits/$plot{10}", Content => $body);
    ok($resp->is_success, 'PUT succeeds') or diag($resp->decoded_content);
    is(plot_state($plot{10})->{accession}, 'test_accession1', 'germplasm changed');
    is(plot_state($plot{10})->{name}, 'test_trial210', 'name kept');
    is(cached_accession('test_trial210'), 'test_accession1', 'cached layout');
    restore();

    # the rights of the trial page: a submitter of the trial's breeding program, not of another one
    my $submitter = Test::WWW::Mechanize->new;
    $submitter->post_ok("$base/brapi/v1/token", [ username => 'johndoe', password => 'secretpw', grant_type => 'password' ], 'login as johndoe, a submitter of the program');
    my $submitter_ua = LWP::UserAgent->new;
    $submitter_ua->default_header('Content-Type' => 'application/json');
    $submitter_ua->default_header('Authorization' => 'Bearer '.decode_json($submitter->content)->{access_token});
    my $dbh = $schema->storage->dbh;
    my ($johndoe_id) = $dbh->selectrow_array("SELECT sp_person_id FROM sgn_people.sp_person WHERE username = 'johndoe'");
    my $program = CXGN::BreedersToolbox::Projects->new({ schema => $schema })->get_breeding_programs_by_trial($trial_id)->[0]->[1];
    my ($program_role_id) = $dbh->selectrow_array("SELECT sp_role_id FROM sgn_people.sp_roles WHERE name = ?", undef, $program);
    my $had_role = $dbh->do("DELETE FROM sgn_people.sp_person_roles WHERE sp_person_id = ? AND sp_role_id = ?", undef, $johndoe_id, $program_role_id);
    ok($had_role > 0, "johndoe had the role of program $program");
    $resp = $submitter_ua->put("$base/brapi/v2/observationunits/$plot{10}", Content => $body);
    is($resp->code, 403, 'a submitter who is not in the program of the trial is refused');
    like($resp->decoded_content, qr/submitter associated with breeding program \Q$program\E/, 'and told why');
    is(plot_state($plot{10})->{accession}, $original->{10}->{accession}, 'the plot keeps its accession');
    $dbh->do("INSERT INTO sgn_people.sp_person_roles (sp_person_id, sp_role_id) VALUES (?, ?)", undef, $johndoe_id, $program_role_id);
    $resp = $submitter_ua->put("$base/brapi/v2/observationunits/$plot{10}", Content => $body);
    ok($resp->is_success, 'a submitter of the program may') or diag($resp->decoded_content);
    is(plot_state($plot{10})->{accession}, 'test_accession1', 'germplasm changed');
    restore();
};

subtest 'BrAPI PUT observationunits marks a plot as not planted or rejected' => sub {
    my $put = sub {
        my ($token, $plot_id, $additional_info) = @_;
        my $ua = LWP::UserAgent->new;
        $ua->default_header('Content-Type' => 'application/json');
        $ua->default_header('Authorization' => 'Bearer '.$token);
        my $resp = $ua->put("$base/brapi/v2/observationunits/$plot_id", Content => encode_json({ additionalInfo => $additional_info, observationUnitPosition => { observationLevel => { levelName => 'plot' } } }));
        my $brapi = eval { decode_json($resp->decoded_content) } || {};
        my ($message) = map { $_->{message} } grep { ($_->{messageType} // '') eq 'ERROR' } @{ $brapi->{metadata}->{status} || [] };
        return { code => $resp->code, error => $message, unit => $brapi->{result} };
    };
    my $submitter = Test::WWW::Mechanize->new;
    $submitter->post_ok("$base/brapi/v1/token", [ username => 'johndoe', password => 'secretpw', grant_type => 'password' ], 'login as johndoe, a submitter of the program');
    my $submitter_token = decode_json($submitter->content)->{access_token};

    my $r = $put->($submitter_token, $plot{10}, { rejected => JSON::true, rejectReason => 'trampled', kept => 'yes' });
    is($r->{code}, 200, 'a submitter of the program rejects a plot of a trial without phenotypes') or diag(explain $r);
    is_deeply([ @{ plot_state($plot{10}) }{qw(rejected reject_reason accession)} ], [ 1, 'trampled', $original->{10}->{accession} ], 'the plot is rejected with the reason and keeps its accession');
    my ($stored) = $schema->storage->dbh->selectrow_array("SELECT value FROM stockprop WHERE stock_id = ? AND type_id = (SELECT cvterm_id FROM cvterm WHERE name = 'stock_additional_info')", undef, $plot{10});
    is_deeply(decode_json($stored // '{}'), { kept => 'yes' }, 'the other keys are stored as additional info, rejected and rejectReason are not');

    my $reader = LWP::UserAgent->new;
    $reader->default_header('Authorization' => 'Bearer '.$submitter_token);
    my $unit = decode_json($reader->get("$base/brapi/v2/observationunits/$plot{10}")->decoded_content)->{result};
    is_deeply([ @{ $unit->{additionalInfo} }{qw(rejected rejectReason)} ], [ JSON::true, 'trampled' ], 'the unit says so');
    $r = $put->($submitter_token, $plot{10}, $unit->{additionalInfo});
    is($r->{code}, 200, 'sending back what was read succeeds') or diag(explain $r);
    is_deeply([ @{ plot_state($plot{10}) }{qw(rejected reject_reason)} ], [ 1, 'trampled' ], 'and changes nothing');

    $r = $put->($submitter_token, $plot{10}, { rejected => JSON::false });
    is($r->{code}, 200, 'rejected false') or diag(explain $r);
    is_deeply([ @{ plot_state($plot{10}) }{qw(rejected reject_reason)} ], [ undef, undef ], 'takes the rejection back');

    $r = $put->($submitter_token, $plot{10}, { notPlanted => JSON::true });
    is($r->{code}, 200, 'notPlanted true') or diag(explain $r);
    is(plot_state($plot{10})->{not_planted}, 1, 'marks the plot as not planted');
    $r = $put->($submitter_token, $plot{10}, { rejected => JSON::true, rejectReason => 'trampled' });
    is($r->{code}, 400, 'a plot that is not planted cannot be rejected');
    like($r->{error} // '', qr/cannot be rejected: it is not planted/, 'and the message says why');
    $r = $put->($submitter_token, $plot{10}, { notPlanted => JSON::false });
    is($r->{code}, 200, 'notPlanted false') or diag(explain $r);
    ok(!plot_state($plot{10})->{not_planted}, 'marks it as planted again');
    restore();

    # a trial with phenotypes: a curator only, and values of a plot are never deleted through BrAPI
    my $phenotyped_trial_id = $schema->resultset('Project::Project')->find({ name => 'CASS_6Genotypes_Sampling_2015' })->project_id;
    my $phenotypes_h = $schema->storage->dbh->prepare("SELECT count(*) FROM nd_experiment_stock nes JOIN nd_experiment_phenotype nep ON nep.nd_experiment_id = nes.nd_experiment_id WHERE nes.stock_id = ?");
    my ($cass_plot) = grep { $phenotypes_h->execute($_->{plot_id}); ($phenotypes_h->fetchrow_array())[0] > 0 }
        sort { $a->{plot_number} <=> $b->{plot_number} } values %{ CXGN::Trial::AccessionChange->new({ schema => $schema, trial_id => $phenotyped_trial_id })->load_units() };
    $r = $put->($submitter_token, $cass_plot->{plot_id}, { rejected => JSON::true, rejectReason => 'flooded' });
    is($r->{code}, 403, 'a submitter cannot reject a plot of a trial with phenotypes');
    like($r->{error} // '', qr/traits have been assayed/, 'and the message says why');
    $r = $put->($access_token, $cass_plot->{plot_id}, { rejected => JSON::true, rejectReason => 'flooded' });
    is($r->{code}, 200, 'a curator can') or diag(explain $r);
    is_deeply([ @{ plot_state($cass_plot->{plot_id}) }{qw(rejected reject_reason)} ], [ 1, 'flooded' ], 'the plot is rejected');
    $r = $put->($access_token, $cass_plot->{plot_id}, { notPlanted => JSON::true });
    is($r->{code}, 400, 'a plot with phenotypes is not marked as not planted');
    like($r->{error} // '', qr/marked as not planted/, 'the message names the phenotypes');
    set_prop($cass_plot->{plot_id}, $_, undef) for qw(rejected reject_reason not_planted);
    $mech->get_ok("$base/ajax/breeders/trial/$phenotyped_trial_id/refresh_cache", 'refresh the cache of the phenotyped trial');
    restore();
};

subtest 'the plot names are renamed by default until the trial has phenotypes' => sub {
    my $phenotyped_trial_id = $schema->resultset('Project::Project')->find({ name => 'CASS_6Genotypes_Sampling_2015' })->project_id;
    $mech->get_ok("$base/ajax/breeders/trial/$trial_id/accession_change_defaults");
    is_deeply(decode_json($mech->content), { has_phenotypes => 0 }, 'a trial without phenotypes');
    $mech->get_ok("$base/ajax/breeders/trial/$phenotyped_trial_id/accession_change_defaults");
    is_deeply(decode_json($mech->content), { has_phenotypes => 1 }, 'a trial with phenotypes');
};

done_testing();
