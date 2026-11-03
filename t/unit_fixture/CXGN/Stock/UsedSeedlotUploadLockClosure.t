use strict;
use warnings;
use lib 't/lib';
use Test::More;
use JSON qw(encode_json);
use Bio::Chado::Schema;
use SGN::Test::Fixture;
use SGN::Model::Cvterm;
use CXGN::Trial::TrialCreate;
use CXGN::Trial::TrialLayout;
use CXGN::Stock::Seedlot;
use CXGN::Stock::Seedlot::Transaction;
use SGN::Controller::AJAX::TrialMetadata;
use File::Temp qw(tempdir);
use IO::Select;
use POSIX qw(WNOHANG);
use Time::HiRes qw(time sleep);

# Only the Catalyst request/context objects are supplied by the test. The actual
# controller, file archive/parser, transaction writer and native cache run.
{package UploadClosureUser; sub get_object {$_[0]} sub get_sp_person_id {41} sub get_username {'janedoe'} sub get_user_type {'curator'}} ## no critic (Modules::RequireFilenameMatchesPackage) -- This test embeds its named test double beside the assertions.
{package UploadClosureFile; sub filename {'private-seedlots.csv'} sub tempname {$_[0]{path}}}
{package UploadClosureRequest; sub param {$_[1] eq 'trial_stock_type' ? 'accession' : undef} sub upload {$_[0]{upload}}}
{package UploadClosureContext;
 sub user {bless({},'UploadClosureUser')} sub config {$_[0]{config}} sub stash {$_[0]{stash}}
 sub req {$_[0]{req}} sub dbic_schema {$_[0]{schema}} sub detach {die 'Controller detached: '.JSON::encode_json($_[0]{stash}{rest})}
}
my $f=SGN::Test::Fixture->new;
my $s=$f->bcs_schema;
my $dbh=$s->storage->dbh;
$s->storage->auto_savepoint(1);
my $cfg=$f->config;
my $prefix='audit_used_seedlot_closure_'.$$;
my $directory=tempdir('audit_seedlot_upload_XXXXXX',TMPDIR=>1,CLEANUP=>1);
my (@trials,@plots,$lot,$worker);
sub term {SGN::Model::Cvterm->get_cvterm_row($s,@_)->cvterm_id}
sub cleanup {
    if ($worker) {kill 'TERM',$worker;waitpid($worker,0);$worker=undef}
    eval {$s->txn_rollback} if !$dbh->{AutoCommit};
    my @stocks=(@plots,defined($lot)?$lot:());
    $s->txn_do(sub {
        my $experiments=$dbh->selectcol_arrayref('SELECT nd_experiment_id FROM nd_experiment_project WHERE project_id=ANY(?)',undef,\@trials);
        $dbh->do('DELETE FROM nd_experiment WHERE nd_experiment_id=ANY(?)',undef,$experiments) if @$experiments;
        $dbh->do('DELETE FROM phenome.stock_owner WHERE stock_id=ANY(?)',undef,\@stocks) if @stocks;
        $dbh->do('DELETE FROM stock WHERE stock_id=ANY(?)',undef,\@stocks) if @stocks;
        $dbh->do('DELETE FROM phenome.project_owner WHERE project_id=ANY(?)',undef,\@trials) if @trials;
        $dbh->do('DELETE FROM project WHERE project_id=ANY(?)',undef,\@trials) if @trials;
    });
}
my $ok=eval {
    $s->txn_do(sub {
        for my $i (0..1) {
            my $made=CXGN::Trial::TrialCreate->new({chado_schema=>$s,dbh=>$dbh,owner_id=>41,operator=>'janedoe',program=>'test',trial_location=>'test_location',trial_name=>"${prefix}_study_$i",trial_description=>'Private native legacy multi-layout upload fixture',trial_year=>2031,design_type=>'CRD',design=>{1=>{plot_name=>"${prefix}_plot_$i",stock_name=>'test_accession1',plot_number=>1,rep_number=>1,block_number=>1,row_number=>1,col_number=>1}}})->save_trial;
            die 'Native trial creation failed' if !$made->{trial_id};push @trials,$made->{trial_id};push @plots,$s->resultset('Stock::Stock')->find({uniquename=>"${prefix}_plot_$i"})->stock_id;
        }
        my $field=term('field_layout','experiment_type');
        my($secondary_layout)=$dbh->selectrow_array('SELECT ne.nd_experiment_id FROM nd_experiment ne JOIN nd_experiment_project nep USING(nd_experiment_id) WHERE nep.project_id=? AND ne.type_id=?',undef,$trials[1],$field);
        $s->resultset('NaturalDiversity::NdExperimentStock')->create({nd_experiment_id=>$secondary_layout,stock_id=>$plots[0],type_id=>$field});
        my $accession=$s->resultset('Stock::Stock')->find({uniquename=>'test_accession1'});
        $lot=$s->resultset('Stock::Stock')->create({name=>$prefix.'_lot',uniquename=>$prefix.'_lot',type_id=>term('seedlot','stock_type'),organism_id=>$accession->organism_id})->stock_id;
        $s->resultset('Stock::StockRelationship')->create({subject_id=>$accession->stock_id,object_id=>$lot,type_id=>term('collection_of','stock_relationship')});
        CXGN::Stock::Seedlot::Transaction->new(schema=>$s,from_stock=>[$lot,'lot'],to_stock=>[$lot,'lot'],amount=>100,weight_gram=>50,factor=>1,operator=>'janedoe',timestamp=>'2031-01-01',description=>'Private known opening')->store;
    });
    is($dbh->selectrow_array('SELECT count(DISTINCT nep.project_id) FROM nd_experiment_stock nes JOIN nd_experiment ne USING(nd_experiment_id) JOIN nd_experiment_project nep USING(nd_experiment_id) WHERE nes.stock_id=? AND ne.type_id=?',undef,$plots[0],term('field_layout','experiment_type')),2,'one actual legacy plot directly belongs to both native field layouts');
    my $input="$directory/private-seedlots.csv";
    open(my $csv,'>',$input) or die $!;
    print {$csv} "seedlot_name,plot_name,num_seed_per_plot,weight_gram_seed_per_plot,description\n${prefix}_lot,${prefix}_plot_0,10,5,Private native upload\n";
    close $csv;
    pipe(my $ready_read,my $ready_write) or die $!;
    $s->txn_begin;
    $dbh->selectrow_array('SELECT project_id FROM project WHERE project_id=? FOR UPDATE',undef,$trials[1]);
    $worker=fork();die 'fork failed' if !defined($worker);
    if (!$worker) {
        $dbh->{InactiveDestroy}=1;
        close $ready_read;
        my $child=Bio::Chado::Schema->connect("dbi:Pg:dbname=$cfg->{dbname};host=$cfg->{dbhost}",$cfg->{dbuser},$cfg->{dbpass});
        $child->storage->auto_savepoint(1);
        $child->storage->dbh->do(q{SET statement_timeout='12s'});
        $child->storage->dbh->selectrow_array(q{SELECT set_config('application_name',?,false)},undef,$prefix.'_uploader');
        my $worked=eval {
            local $SIG{ALRM}=sub {die 'upload worker timeout'};alarm 20;
            my %config=(%$cfg,archive_path=>$directory.'/archive');
            my $context=bless({schema=>$child,config=>\%config,req=>bless({upload=>bless({path=>$input},'UploadClosureFile')},'UploadClosureRequest'),stash=>{trial_id=>$trials[0],trial_layout=>CXGN::Trial::TrialLayout->new({schema=>$child,trial_id=>$trials[0],experiment_type=>'field_layout'})}},'UploadClosureContext');
            syswrite($ready_write,'R',1);
            SGN::Controller::AJAX::TrialMetadata->new->trial_used_seedlots_upload($context);
            die 'Actual upload did not succeed: '.encode_json($context->stash->{rest}) if !$context->stash->{rest}{success};
            alarm 0;1;
        };
        print STDERR "Actual planting upload failed: $@\n" if !$worked;
        eval {$child->storage->disconnect};POSIX::_exit($worked?0:1);
    }
    close $ready_write;
    die 'upload worker did not initialize' if !IO::Select->new($ready_read)->can_read(10);
    my $ready;die 'worker readiness missing' if sysread($ready_read,$ready,1)!=1;
    my ($status,$blocked);
    my $deadline=time()+7;
    while(time()<$deadline) {
        my $done=waitpid($worker,WNOHANG);
        if ($done==$worker) {$status=$?;last}
        $dbh->selectrow_array('SELECT pg_stat_clear_snapshot()');
        $blocked=$dbh->selectrow_hashref(q{SELECT query FROM pg_stat_activity WHERE application_name=? AND wait_event_type='Lock'},undef,$prefix.'_uploader');
        last if $blocked;sleep .02;
    }
    ok($blocked,'actual upload waits for the SECOND direct layout project');
    like($blocked?$blocked->{query}:'',qr/SELECT project_id.*FOR UPDATE/is,'the observed wait precedes any packet lot or relationship lock');
    my $lot_unlocked=eval {$dbh->selectrow_array('SELECT stock_id FROM stock WHERE stock_id=? FOR NO KEY UPDATE NOWAIT',undef,$lot);1};
    ok($lot_unlocked,'while waiting for the secondary project, uploader has not locked the lot');
    is($dbh->selectrow_array('SELECT count(*) FROM stock_relationship WHERE subject_id=? AND object_id=? AND type_id=?',undef,$plots[0],$lot,term('seed transaction','stock_relationship')),0,'no planting packet is written before the complete layout closure is locked');
    $s->txn_rollback;
    if (!defined($status)) {local $SIG{ALRM}=sub {die 'waiting for uploader timed out'};alarm 20;waitpid($worker,0);$status=$?;alarm 0}
    $worker=undef;
    is($status,0,'the actual archive/parser/controller/store path succeeds after secondary-project release');
    is($dbh->selectrow_array('SELECT count(*) FROM stock_relationship WHERE subject_id=? AND object_id=? AND type_id=?',undef,$plots[0],$lot,term('seed transaction','stock_relationship')),1,'exactly one original planting packet is committed');
    my $seedlot=CXGN::Stock::Seedlot->new(schema=>$s,seedlot_id=>$lot);
    is_deeply([$seedlot->get_current_count_property,$seedlot->get_current_weight_property],[90,45],'both cached lot quantities agree after the actual upload');
    1;
};
my $error=$@;
my $clean=eval {cleanup();1};my $cleanup_error=$@;
ok($ok,'actual shared-layout upload ordering qualification completed') or diag($error);
ok($clean,'captured private fixture IDs and transaction rows were removed') or diag($cleanup_error);
is($dbh->selectrow_array('SELECT count(*) FROM project WHERE project_id=ANY(?)',undef,\@trials),0,'no private study remains');
done_testing;
