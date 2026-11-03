use strict;
use warnings;
use lib 't/lib';
use Test::More;
use JSON qw(encode_json);
use SGN::Test::Fixture;
use SGN::Model::Cvterm;
use CXGN::Trial::AccessionChange;
use CXGN::Phenotypes::SearchFactory;
use CXGN::Phenotypes::Exact;
use CXGN::Stock;
use CXGN::Phenotypes::Summary;
use CXGN::BreederSearch;
use CXGN::Chado::Stock;
use SGN::Controller::AJAX::Stock;

my $f=SGN::Test::Fixture->new;
my $s=$f->bcs_schema;
my $dbh=$s->storage->dbh;
$s->storage->auto_savepoint(1);
my $prefix='qc_read_policy_final_';
my $trial=$s->resultset('Project::Project')->find({name=>'test_trial'})->project_id;
my @plots=map {$s->resultset('Stock::Stock')->find({uniquename=>"test_trial2$_"})->stock_id} (10,11);
my($trait_a,$trait_b)=(70666,70741);
my $serial=0;
sub term { SGN::Model::Cvterm->get_cvterm_row($s,@_)->cvterm_id }
sub measurement {
    my($plot,$trait,$value,$time)=@_;
    my $type=term('phenotyping_experiment','experiment_type');
    my $e=$s->resultset('NaturalDiversity::NdExperiment')->create({type_id=>$type,nd_geolocation_id=>$s->resultset('NaturalDiversity::NdGeolocation')->first->nd_geolocation_id});
    $e->create_related('nd_experiment_projects',{project_id=>$trial});
    $e->create_related('nd_experiment_stocks',{stock_id=>$plot,type_id=>$type});
    my $p=$s->resultset('Phenotype::Phenotype')->create({uniquename=>$prefix.++$serial,cvalue_id=>$trait,observable_id=>$trait,value=>$value,collect_date=>$time,operator=>'janedoe'});
    $e->create_related('nd_experiment_phenotypes',{phenotype_id=>$p->phenotype_id});
    return $p->phenotype_id;
}
sub search {
    my($engine,$plot,$trait,%args)=@_;
    return CXGN::Phenotypes::SearchFactory->instantiate($engine,{bcs_schema=>$s,data_level=>'plot',trial_list=>[$trial],plot_list=>[$plot],trait_list=>[$trait],%args})->search;
}
sub values_at {
    my(%args)=@_;
    # Exercise exact instants explicitly; native trial-page filters default to calendar days.
    # Native trial-page filters default to calendar days; this helper tests exact instants.
    my($rows)=search('Native',$plots[1],$trait_a,date_range_mode=>'timestamp',include_dateless_items=>0,%args);
    return [sort { $a <=> $b } map {0+$_->{phenotype_value}} grep {defined $_->{phenotype_value}} @$rows];
}
{package QCReadPolicyDbc;sub dbh {$_[0]{dbh}}} ## no critic (Modules::RequireFilenameMatchesPackage) -- This test embeds its named test double beside the assertions.
{package QCReadPolicyContext;
 sub user {undef}
 sub dbic_schema {$_[0]{schema}}
 sub dbc {$_[0]{dbc}}
 sub stash {$_[0]{stash}}
}
my $tx=0;
END {eval{$s->txn_rollback if $tx} if $s;}
$s->txn_begin;$tx=1;
my $ran=eval {
    my $template=$s->resultset('Stock::Stock')->find({uniquename=>'test_accession1'});
    my $private=$s->resultset('Stock::Stock')->create({name=>$prefix.'accession',uniquename=>$prefix.'accession',organism_id=>$template->organism_id,type_id=>$template->type_id});
    CXGN::Trial::AccessionChange->new({schema=>$s,trial_id=>$trial})->apply([{plot_id=>$plots[0],new_stock_id=>$private->stock_id}],{curator=>1,rename_plots=>'none'});
    my $marked=measurement($plots[0],$trait_a,10,'2026-11-02 10:00:00');
    measurement($plots[0],$trait_b,20,'2026-11-02 10:00:00');
    measurement($plots[1],$trait_a,9,'2026-11-02 09:00:00');
    measurement($plots[1],$trait_a,10,'2026-11-02 10:00:00');
    measurement($plots[1],$trait_a,11,'2026-11-02 11:00:00');
    measurement($plots[1],$trait_a,12,undef);
    $dbh->do('SELECT refresh_materialized_phenotype_jsonb_table()');
    my $prop=$s->resultset('Phenotype::Phenotypeprop')->create({phenotype_id=>$marked,type_id=>term('phenotype_outlier','phenotype_property'),value=>encode_json({value=>1}),rank=>0});
    subtest 'Outlier filtering has phenotype granularity in both engines, including live marks' => sub {
        my($native)=search('Native',$plots[0],$trait_b,exclude_phenotype_outlier=>1);
        my @valid=grep {defined $_->{phenotype_value}} @$native;
        is(scalar @valid,1,'Native retains the valid other trait');
        my($fast,$traits)=search('MaterializedViewTable',$plots[0],$trait_b,exclude_phenotype_outlier=>1);
        is(scalar @$fast,1,'fast search retains the same unit');
        is_deeply([map {$_->{trait_id}} @{$fast->[0]{observations}}],[$trait_b],'fast search returns only the requested unmarked trait');
        is($fast->[0]{full_count},1,'filtered unit pagination count is correct');
        my($hidden)=search('MaterializedViewTable',$plots[0],$trait_a,exclude_phenotype_outlier=>1);
        is(scalar @$hidden,0,'requesting only the marked trait gives no unit');
        my($raw)=search('MaterializedViewTable',$plots[0],$trait_a,exclude_phenotype_outlier=>0);
        is(scalar @{$raw->[0]{observations}},1,'explicit unfiltered standard read keeps the source observation');
        $prop->delete;
        my($restored)=search('MaterializedViewTable',$plots[0],$trait_a,exclude_phenotype_outlier=>1);
        is(scalar @{$restored->[0]{observations}},1,'restoration is visible without refreshing cached JSON');
    };
    subtest 'Explicit observation-unit filters stay exact and caller lists stay unchanged' => sub {
        my @ids=($plots[1]);
        my $search=CXGN::Phenotypes::SearchFactory->instantiate('Native',{bcs_schema=>$s,data_level=>'plot',trial_list=>[$trial],plot_list=>\@ids,trait_list=>[$trait_a]});
        my($rows)=$search->search;
        my %found=map {$_->{obsunit_stock_id}=>1} grep {defined($_->{phenotype_value})} @$rows;
        is_deeply([sort keys %found],["$plots[1]"],'a requested plot is not widened to every trial plot');
        is_deeply(\@ids,[$plots[1]],'caller-owned filter array is not mutated');
        is_deeply($search->plot_list,[$plots[1]],'reusable search retains its original explicit filter');
    };
    subtest 'Native independent timestamp bounds preserve complete UTC instants' => sub {
        is_deeply(values_at(start_date=>'2026-11-02T09:30:00Z',end_date=>undef),[10,11],'start-only bound excludes older values');
        is_deeply(values_at(start_date=>undef,end_date=>'2026-11-02T10:30:00Z'),[9,10],'end-only bound excludes newer values');
        is_deeply(values_at(start_date=>'2026-11-02T11:30:00+02:00',end_date=>'2026-11-02T12:30:00+02:00'),[10],'offset interval selects the same UTC instant');
        is_deeply(values_at(start_date=>'2026-11-02',end_date=>'2026-11-02'),[9,10,11],'date-only end includes the whole day');
        is_deeply(values_at(start_date=>'2026-11-02T10:00:00Z',end_date=>'2026-11-02T10:00:00Z'),[10],'explicit timestamp bounds remain exact and inclusive');
        is_deeply(values_at(start_date=>'2026-11-02T09:30:00Z',end_date=>undef,include_dateless_items=>1),[10,11,12],'explicit dateless inclusion remains supported');
        my $ok=eval{values_at(start_date=>'invalid timestamp',end_date=>undef);1};
        ok(!$ok,'invalid timestamp is rejected before querying');
        is(($dbh->selectrow_array('SELECT 1'))[0],1,'invalid bound does not abort the database transaction');
    };
    subtest 'Rejected measurements disappear from exact export and analytical stock routes; source and treatments stay' => sub {
        my $treatment=SGN::Model::Cvterm->get_cvterm_row_from_trait_name($s,'irrigation|EXPERIMENT_TREATMENT:0000001');
        ok($treatment,'fixture provides standard design treatment');
        measurement($plots[0],$treatment->cvterm_id,'yes',undef);
        CXGN::Trial::AccessionChange->new({schema=>$s,trial_id=>$trial})->apply([{plot_id=>$plots[0],rejected=>1,reject_reason=>'read policy test'}],{curator=>1,rename_plots=>'none'});
        my $name=$s->resultset('Stock::Stock')->find($plots[0])->name;
        my $trait=SGN::Model::Cvterm::get_trait_from_cvterm_id($s,$trait_a,'extended');
        my $treatment_name=SGN::Model::Cvterm::get_trait_from_cvterm_id($s,$treatment->cvterm_id,'extended');
        my $exact=CXGN::Phenotypes::Exact->new({bcs_schema=>$s,trial_id=>$trial})->search;
        ok(!exists $exact->{$trait}{$name},'exact measured export omits rejected value');
        is($exact->{$treatment_name}{$name},'yes','exact design treatment stays available');
        my $raw=CXGN::Phenotypes::Exact->new({bcs_schema=>$s,trial_id=>$trial,exclude_rejected=>0})->search;
        is($raw->{$trait}{$name},10,'explicit raw exact read preserves original value');
        for my $stock_id ($plots[0],$s->resultset('Stock::StockRelationship')->find({subject_id=>$plots[0],type_id=>term('plot_of','stock_relationship')})->object_id) {
            my $c=bless {schema=>$s,dbc=>bless({dbh=>$dbh},'QCReadPolicyDbc'),stash=>{stock=>CXGN::Chado::Stock->new($s,$stock_id)}},'QCReadPolicyContext';
            SGN::Controller::AJAX::Stock->get_phenotypes_by_stock_and_trial($c,$trial);
            is(scalar @{$c->stash->{rest}{data}},0,'trial analytical stock table excludes rejected plot and accession values');
            SGN::Controller::AJAX::Stock->get_stock_trait_list($c);
            is(scalar @{$c->stash->{rest}{data}},0,'actual legacy-wrapper trait-list route uses the filtered local analytical model');
        }
        my $valid=bless {schema=>$s,dbc=>bless({dbh=>$dbh},'QCReadPolicyDbc'),stash=>{stock=>CXGN::Chado::Stock->new($s,$plots[1])}},'QCReadPolicyContext';
        SGN::Controller::AJAX::Stock->get_stock_trait_list($valid);
        my($row)=grep {$_->[0]=~m{/cvterm/$trait_a/view}} @{$valid->stash->{rest}{data}};
        ok($row,'valid direct stock performance stays visible');
        is(0+$row->[4],4,'formatted stock observation count is preserved by the shared analytical adapter');
    };
    subtest 'Strict numeric means accept signed zero/exponent values and safely skip comma text' => sub {
        my $base=$s->resultset('Cv::Cvterm')->find($trait_a);
        my $xref=$s->resultset('General::Dbxref')->find($base->dbxref_id);
        my $newxref=$s->resultset('General::Dbxref')->create({db_id=>$xref->db_id,accession=>'numeric-final-'.$$,version=>''});
        my %cv=$base->get_columns;delete $cv{cvterm_id};$cv{name}=$prefix.'numeric';$cv{dbxref_id}=$newxref->dbxref_id;
        my $trait=$s->resultset('Cv::Cvterm')->create(\%cv)->cvterm_id;
        # Deliberately unformatted, so textual comma data is valid stored source
        # data. Analytical means must skip it, not reinterpret a decimal locale.
        measurement($plots[1],$trait,$_,'2026-11-02 10:00:00') for ('-2','0','1e2',' +4 ','12,5');
        my $summary=CXGN::Phenotypes::Summary->new({bcs_schema=>$s,trial_list=>[$trial],trait_list=>[$trait]})->search;
        is(0+$summary->[0][3],25.5,'shared summary includes sign, zero, exponent and ASCII whitespace');
        is($summary->[0][2],4,'comma text does not become a numeric observation');
        my $c=bless {schema=>$s,dbc=>bless({dbh=>$dbh},'QCReadPolicyDbc'),stash=>{stock=>CXGN::Chado::Stock->new($s,$plots[1])}},'QCReadPolicyContext';
        SGN::Controller::AJAX::Stock->get_stock_trait_list($c);
        my($row)=grep {$_->[0]=~m{/cvterm/$trait/view}} @{$c->stash->{rest}{data}};
        is(0+$row->[2],25.5,'actual stock-page mean uses the same numeric grammar');is(0+$row->[4],4,'actual stock-page count uses that grammar');
        SGN::Controller::AJAX::Stock->get_phenotypes_by_stock_and_trial($c,$trial);
        ($row)=grep {$_->[0]=~m{/cvterm/$trait/view}} @{$c->stash->{rest}{data}};
        is(0+$row->[1],25.5,'actual per-trial stock average does not crash on unformatted comma text');is($row->[3],4,'per-trial count excludes text');
        $dbh->do('REFRESH MATERIALIZED VIEW public.materialized_phenoview');
        my $rank=CXGN::BreederSearch->new({dbh=>$dbh})->avg_phenotypes_query($trial,[$trait],[1],[],'false');
        ok(!$rank->{error},'ranking handles text without a failed numeric cast');
        is(0+$rank->{raw_avg_values}[0][1],25.5,'ranking and displayed means agree on scientific notation');
        my($bounded)=CXGN::Phenotypes::SearchFactory->instantiate('Native',{bcs_schema=>$s,data_level=>'plot',trial_list=>[$trial],plot_list=>[$plots[1]],trait_list=>[$trait],phenotype_min_value=>0,phenotype_max_value=>100})->search;
        is_deeply([sort {$a<=>$b} map {0+$_->{phenotype_value}} grep {defined($_->{phenotype_value})} @$bounded],[0,4,100],'zero lower bound is honored and invalid text never reaches a native numeric cast');
    };
    is(($dbh->selectrow_array('SELECT count(*) FROM phenotype WHERE uniquename LIKE ?',undef,$prefix.'%'))[0],$serial,'all original observations still exist');
    1;
};
my $error=$@;$s->txn_rollback;$tx=0;
ok($ran,'QC read scenarios executed and rolled back') or diag($error);
done_testing;