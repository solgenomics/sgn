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
    [ block => 'block', 'stock_property' ],
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
    my $block = $schema->resultset('Stock::Stockprop')->find({ stock_id => $plot_id, type_id => $t{block} });
    return { name => $plot->uniquename, accession => $accession->uniquename, accession_id => $accession->stock_id, rep => $rep ? $rep->value : undef, block => $block ? $block->value : undef };
}
sub trial_state { return { map { $_ => plot_state($plot{$_}) } keys %plot }; }
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
    rename_plot($plot{$_}, "review_restore_$_") for keys %plot;
    foreach my $n (keys %plot) {
        my $o = $original->{$n};
        rename_plot($plot{$n}, $o->{name});
        $schema->resultset('Stock::StockRelationship')->search({ subject_id => $plot{$n}, type_id => $t{plot_of} })->update({ object_id => $o->{accession_id} });
        set_prop($plot{$n}, 'replicate', $o->{rep});
        set_prop($plot{$n}, 'block', $o->{block});
    }
    $schema->resultset('Project::Projectprop')->search({ project_id => $trial_id, type_id => $t{design} })->update({ value => $original_design });
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

subtest 'replace_stock in an RCBD keeps the blocks and numbers the replicates of the merged accession again' => sub {
    $schema->resultset('Project::Projectprop')->search({ project_id => $trial_id, type_id => $t{design} })->update({ value => 'RCBD' });
    foreach my $n (keys %plot) {
        my $b = int(($n - 1) / 5) + 1;
        set_prop($plot{$n}, 'block', $b);
        set_prop($plot{$n}, 'replicate', $b);
    }
    my $before = trial_state();
    my $r = post_json($replace_stock, [ old_stock_id => $acc{3}, new_stock => 'test_accession1', trial_stock_type => 'accession' ]);
    is($r->{success}, 1, 'success');
    my $after = trial_state();
    is_deeply({ map { $_ => $after->{$_}->{block} } keys %$after }, { map { $_ => $before->{$_}->{block} } keys %$before }, 'blocks unchanged');
    my @merged = sort { $a <=> $b } grep { $after->{$_}->{accession} eq 'test_accession1' } keys %$after;
    is_deeply(\@merged, [ 3, 4, 5, 8, 10, 11 ], 'test_accession1 is in the plots of both accessions');
    is_deeply([ map { $after->{$_}->{rep} } @merged ], [ 1 .. 6 ], 'its replicates are 1..6 by plot number');
    is($r->{replicates_changed}, 5, 'five replicates changed (plot 3 keeps 1)');
    is_deeply({ map { $_ => $after->{$_}->{rep} } grep { $after->{$_}->{accession} ne 'test_accession1' } keys %$after },
        { map { $_ => $before->{$_}->{rep} } grep { $after->{$_}->{accession} ne 'test_accession1' } keys %$after }, 'the other accessions keep their replicates');
    restore();
};

subtest 'replace_plot_accessions: one plot' => sub {
    my $p = post_json("/ajax/breeders/trial/$trial_id/replace_plot_accessions", [ new_accession => 'test_accession2', old_plot_id => $plot{10}, preview => 1 ]);
    is($p->{preview}->{changed}, 1, 'preview: one plot would change') or diag(explain $p);
    ok((grep { /^Design: / } @{ $p->{preview}->{warnings} || [] }), 'the preview has the design warnings (test_accession2 would have 4 plots, test_accession3 2)') or diag(explain $p);
    is(plot_state($plot{10})->{accession}, 'test_accession3', 'the preview changes nothing');
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
    like(post_json("/ajax/breeders/trial/$phenotyped_trial_id/replace_plot_accessions", [ new_accession => 'test_accession1', old_plot_id => $cass_plot->{plot_id}, preview => 1 ])->{warning}, qr/traits have been assayed/, 'the plot form asks a curator first');
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
    # plot 201 has no phenotypes; 202 and 203 have phenotypes and got the packets of 201 and 202
    my ($first) = grep { $plots[$_]->{plot_number} == 201 } 0 .. $#plots;
    my @stretch = @plots[$first .. $first + 2];
    my %saved = map { $_->{plot_id} => [ $_->{stock_id}, $_->{plot_name} ] } @stretch;
    my $all_replicates = sub { return { map { $_->[0] => $_->[1] } @{ $schema->storage->dbh->selectall_arrayref('SELECT stockprop_id, value FROM stockprop WHERE type_id = ?', undef, $t{replicate}) } }; };
    my $replicates_before = $all_replicates->();
    my $phenotypes_h = $schema->storage->dbh->prepare("SELECT count(*) FROM nd_experiment_stock nes JOIN nd_experiment_phenotype nep ON nep.nd_experiment_id = nes.nd_experiment_id WHERE nes.stock_id = ?");
    my $phenotypes = sub { $phenotypes_h->execute($_[0]); return ($phenotypes_h->fetchrow_array())[0]; };
    my %phenotype_count = map { $_->{plot_id} => $phenotypes->($_->{plot_id}) } @stretch;
    is($phenotype_count{ $stretch[0]->{plot_id} }, 0, 'the first plot has no phenotypes');
    ok($phenotype_count{ $stretch[1]->{plot_id} } > 0, 'the others have');

    my $cass_files = additional_files($phenotyped_trial_id);
    my $file = "plot_name,accession_name\n".join('', map { "$stretch[$_]->{plot_name},$stretch[$_ - 1]->{stock_name}\n" } 1 .. 2);
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
    my %involved = map { $_->{stock_id} => 1 } @stretch;
    foreach my $stock_id (sort keys %involved) {
        my @mine = sort { $a->{plot_number} <=> $b->{plot_number} } grep { $_->{stock_id} == $stock_id && defined($_->{replicate}) } values %$after;
        is_deeply([ map { $_->{replicate} } @mine ], [ 1 .. scalar(@mine) ], "the replicates of stock $stock_id are numbered again by plot number");
    }

    # put the trial back
    foreach my $plot_id (keys %saved) {
        $schema->resultset('Stock::StockRelationship')->search({ subject_id => $plot_id, type_id => $t{plot_of} })->update({ object_id => $saved{$plot_id}->[0] });
    }
    my $replicates_now = $all_replicates->();
    foreach my $id (grep { exists($replicates_before->{$_}) && ($replicates_now->{$_} // '') ne ($replicates_before->{$_} // '') } keys %$replicates_now) {
        $schema->resultset('Stock::Stockprop')->find({ stockprop_id => $id })->update({ value => $replicates_before->{$id} });
    }
    is_deeply($all_replicates->(), $replicates_before, 'replicates restored');
    obsolete_new_files($phenotyped_trial_id, $cass_files);
    $mech->get_ok("$base/ajax/breeders/trial/$phenotyped_trial_id/refresh_cache");
    is_deeply({ map { $_->{plot_id} => [ $_->{stock_id}, $_->{plot_name} ] } grep { $saved{ $_->{plot_id} } } values %{ $ac->load_units() } }, \%saved, 'restored');
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

    # the packet of plot 8 went into plot 13 (the packet of plot 13 into the top border, which is written there too)
    my %row_of = map { $_->[ $col->{plot_name} ] => $_ } grep { $_->[ $col->{type} ] eq 'plot' } @$rows;
    my ($top_border) = grep { $_->[ $col->{type} ] eq 'border' && $_->[ $col->{col_number} ] == 3 && $_->[ $col->{row_number} ] == 4 } @$rows;
    $top_border->[ $col->{accession_name} ] = $row_of{test_trial213}->[ $col->{accession_name} ];
    $row_of{test_trial213}->[ $col->{accession_name} ] = $row_of{test_trial28}->[ $col->{accession_name} ];

    my $r = $upload->($header, $rows, preview => 1);
    is($r->{preview}->{changed}, 1, 'preview: one plot gets another accession; the border rows are skipped') or diag(explain $r);
    is_deeply(trial_state(), $original, 'preview changes nothing');

    $r = $upload->($header, $rows);
    is($r->{success}, 1, 'uploaded') or diag(explain $r);
    is(plot_state($plot{13})->{accession}, $original->{8}->{accession}, 'plot 13 has the accession planned for plot 8');

    $r = $upload->($header, $rows, preview => 1);
    is($r->{preview}->{changed}, 0, 'the same file again: nothing to change');
    $r = $upload->($header, $rows);
    is_deeply([ $r->{success}, $r->{changed} ], [ 1, 0 ], 'uploading it again changes nothing');
    is(plot_state($plot{13})->{accession}, $original->{8}->{accession}, 'plot 13 is as after the first upload');

    # a later correction starts from a new download
    ($header, $rows, $col) = $download->();
    %row_of = map { $_->[ $col->{plot_name} ] => $_ } grep { $_->[ $col->{type} ] eq 'plot' } @$rows;
    is($row_of{test_trial213}->[ $col->{accession_name} ], $original->{8}->{accession}, 'the new download has the correction');
    $row_of{test_trial212}->[ $col->{accession_name} ] = $original->{1}->{accession};
    $r = $upload->($header, $rows);
    is_deeply([ map { $_->{plot_name} } @{ $r->{changes} } ], [ 'test_trial212' ], 'second correction: plot 12') or diag(explain $r);
    is(plot_state($plot{12})->{accession}, $original->{1}->{accession}, 'plot 12 has the accession of plot 1');

    # the layout download of the Change Accessions dialog (by plot number), uploaded as it is, changes nothing
    my $columns = uri_escape('{"plot_name":1,"accession_name":1,"plot_number":1,"block_number":1,"rep_number":1,"row_number":1,"col_number":1}');
    $mech->get_ok("$base/breeders/trial/$trial_id/download/layout?format=xlsx&dataLevel=plots&selected_columns=$columns", 'the layout as Excel');
    my ($xlsx_fh, $xlsx) = tempfile(SUFFIX => '.xlsx', UNLINK => 1);
    binmode($xlsx_fh);
    print $xlsx_fh $mech->response->content;
    close($xlsx_fh);
    $mech->post("$base/ajax/breeders/trial/$trial_id/change_plot_accessions_using_file/check", Content_Type => 'form-data', Content => [ trial_design_change_accessions_file => [ $xlsx, 'layout.xlsx' ], keep_plot_names => 1, preview => 1 ]);
    $r = decode_json($mech->content);
    is($r->{preview}->{changed}, 0, 'the Excel file uploaded as it is: nothing to change') or diag(explain $r);
    $mech->get_ok("$base/breeders/trial/$trial_id/download/layout?format=csv&dataLevel=plots&selected_columns=$columns", 'the layout as CSV');
    my ($layout_header, @layout_rows) = map { [ map { s/^"|"$//gr } split /,/, $_, -1 ] } grep { /\S/ } split /\r?\n/, $mech->content;
    is_deeply($layout_header, [ qw(plot_name accession_name plot_number block_number rep_number row_number col_number) ], 'with plot_name and accession_name');
    $r = $upload->($layout_header, \@layout_rows, preview => 1);
    is($r->{preview}->{changed}, 0, 'uploaded unchanged: nothing to change') or diag(explain $r);

    $schema->resultset('Stock::Stockprop')->search({ stock_id => { -in => [ values %plot ] }, type_id => { -in => [ $t{row_number}, $t{col_number} ] } })->delete;
    restore();
};

subtest 'Change Accessions upload: what the parser reads' => sub {
    my $r = upload_accessions($trial_id, "plot_name,accession_name\n<b>x</b>,test_accession1\n");
    like($r->{error}, qr/Plot &lt;b&gt;x&lt;\/b&gt; does not exist in this trial/, 'names from the file are escaped in errors');
    $r = upload_accessions($trial_id, "Plot;Accession\ntest_trial21;test_accession1\n");
    like($r->{error} // '', qr/plot_name/, 'a file without a plot_name column is an error, not a crash') or diag(explain $r);
    $r = upload_accessions($trial_id, "trial_name,plot_name,accession_name\nother_trial,other_trial_plot_1,test_accession1\ntest_trial,test_trial25,test_accession2\n", preview => 1);
    is_deeply([ $r->{preview}->{rows_read}, $r->{preview}->{changed} ], [ 1, 1 ], 'rows of other trials are skipped') or diag(explain $r);
    is_deeply([ grep { !/^Design: / } @{ $r->{preview}->{warnings} } ], [ '1 row(s) of trial other_trial were skipped; upload the file in that trial too if it has corrections there.' ], 'and the preview says so') or diag(explain $r);
    ok((grep { /^Design: Every accession had 3 plot\(s\); after the change test_accession1 has 2, test_accession2 has 4\./ } @{ $r->{preview}->{warnings} }), 'with the design warning of the change itself') or diag(explain $r);
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
        my $columns = uri_escape('{"plot_name":1,"accession_name":1,"plot_number":1,"block_number":1,"rep_number":1,"row_number":1,"col_number":1,"seedlot_name":1}');
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
    is_deeply([ $r->{warning}, $r->{preview}->{changed}, $r->{preview}->{seedlots} ], [ undef, 0, [] ], 'the layout uploaded as it is, confirmed: nothing to change') or diag(explain $r);

    # the packets of plots 4 to 7 went one place on, into 5 to 8, and the packet of plot 8 into plot 4;
    # only accession_name is corrected, the seedlot_name cells are left as they are
    my @accessions = map { $row_of{"test_trial2$_"}->[ $col->{accession_name} ] } 4 .. 8;
    $row_of{"test_trial2$_"}->[ $col->{accession_name} ] = $accessions[$_ - 5] for 5 .. 8;
    $row_of{test_trial24}->[ $col->{accession_name} ] = $accessions[4];
    $r = upload_accessions($trial_id, $csv->(), preview => 1, override => 1, keep_plot_names => 1);
    is_deeply([ map { [ $_->{type}, $_->{from_plot_name} // '', $_->{plot_name} ] } @{ $r->{preview}->{seedlots} } ],
        [ [ 'move', 'test_trial25', 'test_trial24' ], [ 'move', 'test_trial24', 'test_trial25' ], [ 'move', 'test_trial28', 'test_trial26' ], [ 'move', 'test_trial26', 'test_trial27' ], [ 'move', 'test_trial27', 'test_trial28' ] ],
        'preview: the seed transactions follow the packets (plot 4 takes the nearest packet of its accession, that of plot 5, from the same seedlot as that of plot 8)') or diag(explain $r);
    $r = upload_accessions($trial_id, $csv->(), override => 1, keep_plot_names => 1);
    is($r->{success}, 1, 'changed') or diag(explain $r);
    is_deeply([ map { $planted_from->($plot{$_}) } 4 .. 8 ], [ "review_upload_seedlot_$original->{8}->{accession}", map { "review_upload_seedlot_$original->{$_}->{accession}" } 4 .. 7 ], 'plots 4 to 8 were planted from the seedlots of their new accessions');

    # the same file again (its seedlot cells are those of before the packets moved) changes nothing
    $r = upload_accessions($trial_id, $csv->(), preview => 1, override => 1, keep_plot_names => 1);
    is_deeply([ $r->{error}, $r->{preview}->{changed}, $r->{preview}->{seedlots}, $r->{preview}->{warnings} ], [ undef, 0, [], [] ], 'the same file again: nothing to change') or diag(explain $r);

    # a new download, uploaded as it is, changes nothing
    ($header, $rows, $col) = $download->();
    $r = upload_accessions($trial_id, $csv->(), preview => 1, override => 1, keep_plot_names => 1);
    is_deeply([ $r->{preview}->{changed}, $r->{preview}->{seedlots} ], [ 0, [] ], 'the new download uploaded as it is: nothing to change') or diag(explain $r);

    my @seedlot_ids = map { $_->stock_id } values %seedlot;
    $schema->resultset('Stock::StockRelationship')->search({ type_id => $t{seed_transaction}, -or => [ subject_id => { -in => \@seedlot_ids }, object_id => { -in => \@seedlot_ids } ] })->delete;
    $_->delete for values %seedlot;
    restore();
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
    my $service_rep = plot_state($plot{10})->{rep};
    restore();

    # a client that reads the plot, changes its germplasm and sends it back also sends the old
    # replicate; the replicate of the service stays
    my $with_rep = encode_json({ germplasmDbId => "$acc{1}", germplasmName => 'test_accession1', studyDbId => "$trial_id",
        observationUnitPosition => { observationLevel => { levelName => 'plot' },
            observationLevelRelationships => [ { levelName => 'rep', levelCode => '99' } ] } });
    $resp = $ua->put("$base/brapi/v2/observationunits/$plot{10}", Content => $with_rep);
    ok($resp->is_success, 'PUT with the old replicate succeeds') or diag($resp->decoded_content);
    is(plot_state($plot{10})->{accession}, 'test_accession1', 'germplasm changed');
    is(plot_state($plot{10})->{rep}, $service_rep, 'the replicate is the one of the service, not the one sent');
    restore();
    $resp = $ua->put("$base/brapi/v2/observationunits/$plot{10}", Content => encode_json({ germplasmDbId => "$original->{10}->{accession_id}",
        studyDbId => "$trial_id", observationUnitPosition => { observationLevel => { levelName => 'plot' },
            observationLevelRelationships => [ { levelName => 'rep', levelCode => '7' } ] } }));
    ok($resp->is_success, 'PUT of a replicate without a change of germplasm succeeds') or diag($resp->decoded_content);
    is(plot_state($plot{10})->{rep}, '7', 'without a change of germplasm the replicate sent is stored');
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

done_testing();
