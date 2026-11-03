use strict;
use warnings;
use lib 't/lib';
use Test::More;
use Test::WWW::Mechanize;
use JSON qw(encode_json decode_json);
use File::Slurp qw(read_file);
use File::Temp qw(tempdir);
use File::Basename qw(basename dirname);
use Digest::MD5 qw(md5_hex);
use Storable qw(dclone);
use SGN::Test::Fixture;
use SGN::Model::Cvterm;
use SGN::Controller::AJAX::DroneImagery::DroneImageryAnalytics;

# Representation/persistence fixture only. Native model/solver correctness is
# qualified by the separate actual native drivers and variance oracle.
my $fixture=SGN::Test::Fixture->new;
my $schema=$fixture->bcs_schema;
my $dbh=$schema->storage->dbh;
my $base=$ENV{SGN_TEST_BASE} || 'http://localhost:3010';
my ($analytics_protocol_id,$analytics_nd_experiment_id,@owned_terms,@owned_xrefs);
my $archive_dir=tempdir(CLEANUP=>1);
my @owned_files;
{package NativeSummaryArchiveContext;sub config {$_[0]{config}}sub stash {$_[0]{stash} ||= {}}} ## no critic (Modules::RequireFilenameMatchesPackage) -- This test embeds its named test double beside the assertions.
sub _archive_analytics_result {SGN::Controller::AJAX::DroneImagery::DroneImageryAnalytics::_archive_analytics_result(@_)}
my $prefix='audit_native_summary_'.$$;
sub term {
    my ($name,$cv)=@_;
    my $row=$schema->resultset('Cv::Cvterm')->search({'me.name'=>$name,'cv.name'=>$cv},{join=>'cv'})->first;
    return $row->cvterm_id if $row;
    my $template=$schema->resultset('Cv::Cvterm')->search({'cv.name'=>$cv},{join=>'cv'})->first
        or die "Missing fixture vocabulary: $cv";
    my $xref=$schema->resultset('General::Dbxref')->create({db_id=>$template->dbxref->db_id,accession=>$prefix.'_'.$name});
    my $created=$schema->resultset('Cv::Cvterm')->create({name=>$name,cv_id=>$template->cv_id,dbxref_id=>$xref->dbxref_id});
    push @owned_terms,$created->cvterm_id;push @owned_xrefs,$xref->dbxref_id;
    return $created->cvterm_id;
}
sub cleanup {
    $schema->txn_do(sub {
        foreach my $id (@owned_files) {
            $dbh->do('DELETE FROM phenome.nd_experiment_md_files WHERE file_id=?',undef,$id);
            my ($metadata)=$dbh->selectrow_array('SELECT metadata_id FROM metadata.md_files WHERE file_id=?',undef,$id);
            $dbh->do('DELETE FROM metadata.md_files WHERE file_id=?',undef,$id);
            $dbh->do('DELETE FROM metadata.md_metadata WHERE metadata_id=?',undef,$metadata) if $metadata;
        }
        $dbh->do('DELETE FROM nd_experiment WHERE nd_experiment_id=?',undef,$analytics_nd_experiment_id) if $analytics_nd_experiment_id;
        if ($analytics_protocol_id) {
            $dbh->do('DELETE FROM nd_protocolprop WHERE nd_protocol_id=?',undef,$analytics_protocol_id);
            $dbh->do('DELETE FROM nd_protocol WHERE nd_protocol_id=?',undef,$analytics_protocol_id);
        }
        $dbh->do('DELETE FROM cvterm WHERE cvterm_id=ANY(?)',undef,\@owned_terms) if @owned_terms;
        $dbh->do('DELETE FROM dbxref WHERE dbxref_id=ANY(?)',undef,\@owned_xrefs) if @owned_xrefs;
    });
}
my $all=eval {
    my $protocolprop_result_type_cvterm_id;
    my $legacy={statistics_select_original=>'airemlf90_grm_random_regression_dap_blups',avg_varcomps_display=>[{type=>'legacy',type_scenario=>'original',level=>'h2_coeff_1',mean=>.949690130321078,std=>0}]};
    $schema->txn_do(sub {
        my $type=term('drone_imagery_analytics_env_simulation_protocol','protocol_type');
        my $properties=term('analytics_protocol_properties','protocol_property');
        my $experiment_type=term('analytics_protocol_experiment','experiment_type');
        $protocolprop_result_type_cvterm_id=term('analytics_protocol_result_summary','protocol_property');
        ($analytics_protocol_id)=$dbh->selectrow_array('INSERT INTO nd_protocol(name,type_id,description) VALUES(?,?,?) RETURNING nd_protocol_id',undef,$prefix,$type,'Private summary persistence/display fixture');
        ($analytics_nd_experiment_id)=$dbh->selectrow_array('INSERT INTO nd_experiment(nd_geolocation_id,type_id) VALUES(?,?) RETURNING nd_experiment_id',undef,$schema->resultset('NaturalDiversity::NdGeolocation')->first->nd_geolocation_id,$experiment_type);
        $dbh->do('INSERT INTO nd_experiment_protocol(nd_experiment_id,nd_protocol_id) VALUES(?,?)',undef,$analytics_nd_experiment_id,$analytics_protocol_id);

        $dbh->do('INSERT INTO nd_protocolprop(nd_protocol_id,type_id,value,rank) VALUES(?,?,?,0)',undef,$analytics_protocol_id,$properties,encode_json({test_fixture=>1}));
        $dbh->do('INSERT INTO nd_protocolprop(nd_protocol_id,type_id,value,rank) VALUES(?,?,?,0)',undef,$analytics_protocol_id,$protocolprop_result_type_cvterm_id,encode_json([$legacy]));
    });
    my $summary={version=>2,estimand_id=>'rr_observation_marginal_genetic_share',time_scale=>'DAP',kernel_origin=>'genotypic_identity',quantity_label=>'Observation-scale broad-sense genotypic H2',covariance_source=>'estimated',definition=>{reference=>'Fixed physical plots; equal per-plot weights',scale=>'Individual observation after fixed effects'},reference_units=>[{plot_id=>1001,genotype_id=>101,weight=>1}],genetic_covariance=>[0],env_covariance=>[1],genetic_correlation=>[undef],env_correlation=>[1],residual=>{gamma=>[0],printed_se_for_R=>[.18314]},by_time=>[{time=>0,mean_genetic_variance=>0,mean_permanent_variance=>1,residual_variance=>1,genetic_share=>0,genetic_share_range=>[0,0],units=>[{plot_id=>1001,genotype_id=>101,genetic_variance=>0,permanent_variance=>1,residual_variance=>1,genetic_share=>0}]}]};
    my $native_variance_summaries={version=>2,stages=>{original=>$summary}};
    if ($ENV{SGN_NATIVE_SUMMARY_ARTIFACT}) {
        my $actual=decode_json(read_file($ENV{SGN_NATIVE_SUMMARY_ARTIFACT}));
        $native_variance_summaries=$actual->{stages} ? $actual:{version=>2,stages=>{original=>$actual}};
        $summary=$native_variance_summaries->{stages}{original};
        die 'Actual summary artifact version missing' if ($summary->{version} // 0)!=2;
    }
    my $archive_file="$archive_dir/$prefix-summary.json";
    open(my $raw,'>',$archive_file)or die$!;print $raw encode_json($native_variance_summaries);close($raw);
    my $descriptor={basename=>basename($archive_file),filetype=>'native_rr_variance_summary_v2'};
    my $source=read_file('lib/SGN/Controller/AJAX/DroneImagery/DroneImageryAnalytics.pm');
    my $compact_start=index($source,'                my $compact_native_summaries=dclone(');
    my $compact_end=index($source,'                eval {',$compact_start);
    die 'Actual compact-summary producer boundaries missing' if $compact_start<0 || $compact_end<0;
    my $compact_native_summaries=eval substr($source,$compact_start,$compact_end-$compact_start)."\n\$compact_native_summaries;"; ## no critic (ProhibitStringyEval) -- Execute the owning source fragment in this regression test; errors are checked below.
    die $@ if $@;
    my $env_varcomps=[{statistics_select=>'Native persistence fixture',type=>'One representation',native_variance_archive=>$descriptor,map {$_=>{native_variance_summary=>$compact_native_summaries->{stages}{$_}}} keys %{$compact_native_summaries->{stages}}}];
    my $averages=SGN::Controller::AJAX::DroneImagery::DroneImageryAnalytics::_native_variance_averages($env_varcomps);
    my %avg_varcomps=%{$averages->{values}};my @avg_varcomps_display=@{$averages->{display}};
    my ($protocol_result_summary,$protocol_result_summary_id);my $statistics_select=($summary->{covariance_source} eq 'supplied' ? 'blupf90':'airemlf90').'_grm_random_regression_'.lc($summary->{time_scale}).'_blups';my $statistics_select_original=$statistics_select;my $number_iterations=1;my $env_iterations={};my $env_corr_res={};my (%trait_name_encoder,%trait_to_time_map,%avg_cross_validation,@avg_cross_validation_display);my $perform_cv=0;
    my $a=index($source,'    my $q_save_res =');my $b=index($source,'    foreach my $f (@$spatial_effects_plots)',$a);
    die 'Owning summary persistence boundaries missing' if $a<0 || $b<0;
    $schema->txn_do(sub {eval substr($source,$a,$b-$a);die $@ if $@;}); ## no critic (ProhibitStringyEval) -- Execute the owning source fragment in this regression test; errors are checked below.
    # Execute the actual standard archive/link block on this committed private
    # experiment so independent metadata/phenome connections see its FK owner.
    my ($saved_before_failure)=$dbh->selectrow_array('SELECT value FROM nd_protocolprop WHERE nd_protocol_id=? AND type_id=?',undef,$analytics_protocol_id,$protocolprop_result_type_cvterm_id);
    my $failure_context=bless({config=>{archive_path=>'/proc/sgn_summary_failure_'.$$}},'NativeSummaryArchiveContext');
    my $failed=_archive_analytics_result($failure_context,$archive_file,'native_rr_variance_summary_v2','2031-01-01_10:00:00',41,'curator',$analytics_protocol_id);
    ok(!defined($failed),'real private unwritable archive returns no false success');
    is_deeply([@{$failure_context->stash->{rest}}{qw(analytics_protocol_id summary_saved archive_failed)}],[$analytics_protocol_id,1,1],'controlled archive failure refers to the actually saved private protocol');
    my ($saved_after_failure)=$dbh->selectrow_array('SELECT value FROM nd_protocolprop WHERE nd_protocol_id=? AND type_id=?',undef,$analytics_protocol_id,$protocolprop_result_type_cvterm_id);
    is($saved_after_failure,$saved_before_failure,'failed archive preserves actual saved summary/history bytes');
    my $raw_bytes=read_file($archive_file,binmode=>':raw');
    my $metadata_schema=$fixture->metadata_schema;
    my $phenome_schema=$fixture->phenome_schema;
    my $c=bless({config=>{archive_path=>$archive_dir,basepath=>$archive_dir}},'NativeSummaryArchiveContext');
    my ($user_id,$user_role,$timestamp)=(41,'curator','2031-01-01_10:00:00');
    my $spatial_effects_files_store=[[$archive_file,'native_rr_variance_summary_v2']];
    my $h2=$dbh->prepare('UPDATE nd_protocolprop SET value=? WHERE nd_protocolprop_id=?');
    $a=index($source,'    my $native_archive_link_updated=0;');
    $b=index($source,'    $c->stash->{rest} = {',$a);
    die 'Owning standard archive boundaries missing' if $a<0 || $b<0;
    my $archived=eval 'sub {'.substr($source,$a,$b-$a).';return undef;}->()'; ## no critic (ProhibitStringyEval) -- Execute the owning source fragment in this regression test; errors are checked below.
    push @owned_files,$descriptor->{file_id} if $descriptor->{file_id};
    die $@ if $@;die $archived->{error} if ref($archived)eq'HASH';
    ok($descriptor->{file_id},'actual standard uploader assigns the per-unit summary metadata file ID');
    my ($stored)=$dbh->selectrow_array('SELECT value FROM nd_protocolprop WHERE nd_protocol_id=? AND type_id=?',undef,$analytics_protocol_id,$protocolprop_result_type_cvterm_id);
    my $rows=decode_json($stored);
    is(scalar(@$rows),2,'actual owning persistence appends a new result without replacing history');
    is_deeply($rows->[0],$legacy,'original invalid historical raw result remains byte-equivalent data');
    is($rows->[1]{variance_summary_version},2,'corrected result is explicitly versioned');
    is_deeply($rows->[1]{env_varcomps}[0]{original}{native_variance_summary},$compact_native_summaries->{stages}{original},'compact reference IDs, date curve, definition and printed diagnostic survive PostgreSQL JSON');
    ok(!grep({exists($_->{units})}@{$rows->[1]{env_varcomps}[0]{original}{native_variance_summary}{by_time}}),'per-unit-by-date detail is archived rather than duplicated in DB');
    is($rows->[1]{env_varcomps}[0]{native_variance_archive}{file_id},$descriptor->{file_id},'actual second persistence write retains metadata file link');
    my $client=Test::WWW::Mechanize->new(timeout=>60);
    $client->post("$base/ajax/user/login",[username=>'janedoe',password=>'secretpw',goto_url=>'/']);
    $client->get("$base/analytics_protocols/$analytics_protocol_id");
    is($client->status,200,'actual authenticated protocol detail GET succeeds');
    like($client->content,qr/native-variance-by-date/,'actual saved-result reader and Mason render the versioned date table');
    like($client->content,qr/Legacy native random-regression summary/,'same page identifies retained old summary');
    unlike($client->content,qr/h2_coeff_1.*0\.949690/,'old false coefficient H2 is not silently shown as corrected output');
    like($client->content,qr/\Q$summary->{by_time}[0]{time} $summary->{time_scale}\E/,'actual numeric date retains its time scale through DB and actual GET');
    like($client->content,qr/broad-sense genotypic H2/,'qualified biological quantity label survives readback');
    if (@{$summary->{residual}{printed_se_for_R} || []}) {like($client->content,qr/Native printed.*SE for R/,'printed native diagnostic is shown under a separate definition');}
    like($client->content,qr/Download archived per-plot date variance summary/,'actual metadata-linked artifact is visible on the saved summary');
    $client->get($base.$descriptor->{download_url});
    is($client->status,200,'actual existing artifact download route succeeds');
    is($client->content,$raw_bytes,'actual artifact download preserves exact JSON bytes');
    my ($metadata_md5)=$dbh->selectrow_array('SELECT md5checksum FROM metadata.md_files WHERE file_id=?',undef,$descriptor->{file_id});
    is($metadata_md5,md5_hex($raw_bytes),'archived metadata MD5 matches actual downloaded bytes');
    is_deeply(decode_json($client->content)->{stages}{original},$summary,'archived download retains the full per-unit/reference/covariance result');
    1;
};my $error=$@;my $clean=eval {cleanup();1};my $cleanup_error=$@;
ok($all,'owning persistence and HTTP case completed') or diag($error);
ok($clean,'only exact owned protocol/optional vocabulary IDs removed') or diag($cleanup_error);
done_testing;
