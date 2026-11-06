use strict;
use warnings;
use lib 't/lib';
use Test::More;
use Test::WWW::Mechanize;
use JSON qw(decode_json);
use SGN::Test::Fixture;
use SGN::Model::Cvterm;
use CXGN::Trial::TrialCreate;
use CXGN::Trial::TrialLayout;

# Exercise the real native property routes; only committed private IDs are used.
my $fixture=SGN::Test::Fixture->new;
my $schema=$fixture->bcs_schema;
my $dbh=$schema->storage->dbh;
my $base='http://localhost:3010';
my $prefix='audit_layout_property_'.$$;
my ($trial,$plot,$phenotype_id);
sub term {SGN::Model::Cvterm->get_cvterm_row($schema,@_)->cvterm_id}
sub rows {
    my ($name)=@_;
    return $schema->resultset('Stock::Stockprop')->search({stock_id=>$plot,type_id=>term($name,'stock_property')},{order_by=>'rank'});
}
sub cached_block {
    my $layout=CXGN::Trial::TrialLayout->new({schema=>$schema,trial_id=>$trial,experiment_type=>'field_layout'})->get_design;
    return (values %$layout)[0]{block_number};
}
sub result {my ($client)=@_;return eval {decode_json($client->content)} || {error=>'Response is not JSON',http_status=>$client->status}}
sub cleanup {
    return if !$trial;
    $schema->txn_do(sub {
        my $experiments=$dbh->selectcol_arrayref('SELECT nd_experiment_id FROM nd_experiment_project WHERE project_id=?',undef,$trial);
        $dbh->do('DELETE FROM phenotype WHERE phenotype_id=?',undef,$phenotype_id) if $phenotype_id;
        $dbh->do('DELETE FROM nd_experiment WHERE nd_experiment_id=ANY(?)',undef,$experiments) if @$experiments;
        $dbh->do('DELETE FROM phenome.stock_owner WHERE stock_id=?',undef,$plot) if $plot;
        $dbh->do('DELETE FROM stock WHERE stock_id=?',undef,$plot) if $plot;
        $dbh->do('DELETE FROM phenome.project_owner WHERE project_id=?',undef,$trial);
        $dbh->do('DELETE FROM project WHERE project_id=?',undef,$trial);
    });
    $dbh->do('SELECT refresh_materialized_phenotype_jsonb_table()');
}
my $ran=eval {
    my $created=CXGN::Trial::TrialCreate->new({chado_schema=>$schema,dbh=>$dbh,owner_id=>41,operator=>'janedoe',program=>'test',trial_location=>'test_location',trial_name=>$prefix,trial_description=>'Private native property-route integrity qualification',trial_year=>2031,design_type=>'RCBD',design=>{1=>{plot_name=>$prefix.'_P1',plot_number=>1,stock_name=>'test_accession1',rep_number=>'01',block_number=>'01',row_number=>1,col_number=>1}}})->save_trial;
    $trial=$created->{trial_id};die 'Private field creation failed' if !$trial;
    $plot=$schema->resultset('Stock::Stock')->find({uniquename=>$prefix.'_P1'})->stock_id;
    my $type=term('phenotyping_experiment','experiment_type');
    my $measurement=$schema->resultset('NaturalDiversity::NdExperiment')->create({type_id=>$type,nd_geolocation_id=>$schema->resultset('NaturalDiversity::NdGeolocation')->first->nd_geolocation_id});
    $measurement->create_related('nd_experiment_projects',{project_id=>$trial});
    $measurement->create_related('nd_experiment_stocks',{stock_id=>$plot,type_id=>$type});
    my $phenotype=$schema->resultset('Phenotype::Phenotype')->create({uniquename=>$prefix.'_measurement',cvalue_id=>70666,observable_id=>70666,value=>0,operator=>'janedoe'});
    $phenotype_id=$phenotype->phenotype_id;
    $measurement->create_related('nd_experiment_phenotypes',{phenotype_id=>$phenotype_id});

    my $client=Test::WWW::Mechanize->new(autocheck=>0);
    $client->post("$base/ajax/user/login",[username=>'janedoe',password=>'secretpw',goto_url=>'/']);
    ok($client->success && !result($client)->{error},'real native session login');
    is(cached_block(),'01','actual native layout starts with exact recorded block01');
    $client->post("$base/stock/prop/add",[stock_id=>$plot,prop_type=>'block',prop=>'30']);
    my $changed=result($client);
    ok(!$changed->{error},'native block property route accepts an authorized metadata update') or diag($changed->{error});
    is(rows('block')->count,1,'native update retains one block property rather than appending another rank');
    is(rows('block')->first->value,'30','actual stored field block changes to the requested tag');
    is(cached_block(),'30','native property edit refreshes the actual layout cache');
    $client->post("$base/stock/prop/add",[stock_id=>$plot,prop_type=>'block',prop=>'0']);
    ok(!result($client)->{error},'native block route accepts literal zero');
    is(rows('block')->first->value,'0','zero is stored exactly');
    $client->post("$base/stock/prop/add",[stock_id=>$plot,prop_type=>'design_replicate',prop=>'0']);
    ok(!result($client)->{error},'native recorded-group edit uses the controlled metadata transaction');
    is(rows('design_replicate')->first->value,'0','native group edit preserves exact zero');
    my $design_id=rows('design_replicate')->first->stockprop_id;
    $client->get("$base/stock/prop/delete?stockprop_id=$design_id");
    ok(!result($client)->{error},'native group clear succeeds');
    is(rows('design_replicate')->count,1,'native group clear preserves explicit missing snapshot presence');
    is(rows('design_replicate')->first->value,undef,'cleared group remains unknown');
    $client->post("$base/stock/prop/add",[stock_id=>$plot,prop_type=>'replicate',prop=>'99']);
    ok(result($client)->{error},'derived field occurrence cannot be edited as a generic property');
    is(rows('replicate')->first->value,1,'refused direct edit preserves occurrence numbering');
    my $block_id=rows('block')->first->stockprop_id;
    my $anonymous=Test::WWW::Mechanize->new(autocheck=>0);
    $anonymous->get("$base/stock/prop/delete?stockprop_id=$block_id");
    my $anonymous_result=result($anonymous);
    ok($anonymous->status<500 && $anonymous_result->{error} && !exists($anonymous_result->{http_status}),'anonymous layout metadata deletion is a controlled JSON refusal');
    is(rows('block')->first->value,'0','anonymous request changes nothing');
    $client->get("$base/stock/prop/delete?stockprop_id=$block_id");
    ok(!result($client)->{error},'authorized native block clear succeeds');
    is(rows('block')->count,0,'block clear does not invent a default group');
    is(cached_block(),undef,'cleared block reads as unknown in the actual layout');
    1;
};
my $error=$@;
my $clean=eval {cleanup();1};my $cleanup_error=$@;
ok($ran,'native property scenarios completed') or diag($error);
ok($clean,'exact-ID private fixture cleanup completed') or diag($cleanup_error);
is($dbh->selectrow_array('SELECT count(*) FROM project WHERE name=?',undef,$prefix),0,'no private property-test project remains') if $clean;
done_testing;
