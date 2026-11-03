use strict;
use warnings;
use lib 't/lib';
use Test::More;
use SGN::Test::Fixture;
use SGN::Model::Cvterm;
use CXGN::Trial::TrialCreate;
use CXGN::Trial::AccessionChange;
use CXGN::Trial::DesignReplication;

my $fixture=SGN::Test::Fixture->new;
my $schema=$fixture->bcs_schema;
my $dbh=$schema->storage->dbh;
$schema->storage->auto_savepoint(1);
my $prefix='audit_child_counter_context_'.$$;
my %terms;
sub term {
    my ($name,$cv)=@_;
    return $terms{"$cv/$name"} ||= SGN::Model::Cvterm->get_cvterm_row($schema,$name,$cv)->cvterm_id;
}
sub property {
    my ($id,$name)=@_;
    my $row=$schema->resultset('Stock::Stockprop')->find({stock_id=>$id,type_id=>term($name,'stock_property'),rank=>0});
    return $row ? $row->value:undef;
}
my ($trial,$experiment,$germplasm);
sub child {
    my ($name,$parents,$raw_counter,$has_block,$raw_block)=@_;
    my $stock=$schema->resultset('Stock::Stock')->create({name=>"${prefix}_$name",uniquename=>"${prefix}_$name",organism_id=>$germplasm->organism_id,type_id=>term('tissue_sample','stock_type')});
    for my $parent (@$parents,$germplasm->stock_id) {
        $stock->create_related('stock_relationship_subjects',{object_id=>$parent,type_id=>term('tissue_sample_of','stock_relationship')});
    }
    $stock->create_related('nd_experiment_stocks',{nd_experiment_id=>$experiment,type_id=>term('field_layout','experiment_type')});
    $stock->create_related('stockprops',{type_id=>term('replicate','stock_property'),value=>$raw_counter,rank=>0}) if defined($raw_counter);
    $stock->create_related('stockprops',{type_id=>term('block','stock_property'),value=>$raw_block,rank=>0}) if $has_block;
    return $stock->stock_id;
}
my $active=0;
END {eval {$schema->txn_rollback if $active} if $schema}
$schema->txn_begin;$active=1;
my $ran=eval {
    $germplasm=$schema->resultset('Stock::Stock')->find({uniquename=>'test_accession1'});
    my @names=qw(test_accession1 test_accession1 test_accession2);
    my @blocks=('0','01','9');
    my %layout=map {my $n=$_;($n=>{plot_name=>"${prefix}_P$n",plot_number=>$n,stock_name=>$names[$n-1],rep_number=>$n,block_number=>$blocks[$n-1],row_number=>1,col_number=>$n})} 1..3;
    my $created=CXGN::Trial::TrialCreate->new({chado_schema=>$schema,dbh=>$dbh,owner_id=>41,operator=>'janedoe',program=>'test',trial_location=>'test_location',trial_name=>$prefix,trial_description=>'Rollback-only field child context qualification',trial_year=>2031,design_type=>'RCBD',design=>\%layout})->save_trial;
    $trial=$created->{trial_id};die 'Native field creation failed' if !$trial;
    my @plots=map {$schema->resultset('Stock::Stock')->find({uniquename=>"${prefix}_P$_"})->stock_id} 1..3;
    ($experiment)=$dbh->selectrow_array('SELECT ne.nd_experiment_id FROM nd_experiment ne JOIN nd_experiment_project nep USING(nd_experiment_id) WHERE nep.project_id=? AND ne.type_id=?',undef,$trial,term('field_layout','experiment_type'));
    my $single=child('single',[$plots[0]],undef,0,undef);
    my $pooled=child('pooled',[@plots[0,1]],77,1,99);
    my $orphan=child('orphan',[],77,1,99);
    my $states=CXGN::Trial::DesignReplication::read($schema,[$single,$pooled,$orphan]);
    is($states->{$single}{block},'0','legacy single-parent tissue without its own block inherits exact physical zero');
    is($states->{$single}{block_recorded},0,'resolved inheritance does not invent a stored legacy block row');
    is($states->{$single}{occurrence},1,'single field child resolves the current parent occurrence');
    is($states->{$single}{occurrence_raw},undef,'originally missing stored counter stays inspectable');
    is($states->{$single}{occurrence_ready},1,'one normalized field parent establishes the occurrence domain');
    for my $id ($pooled,$orphan) {
        is($states->{$id}{block},undef,'ambiguous or missing plot sources have no guessed physical block');
        is($states->{$id}{block_raw},99,'raw local legacy metadata remains inspectable');
        is($states->{$id}{occurrence},undef,'a local legacy label is not a field occurrence without exactly one plot source');
        is($states->{$id}{occurrence_raw},77,'raw pooled/orphan label is preserved for inspection');
        is($states->{$id}{occurrence_ready},0,'project cutover alone does not make an ambiguous child counter ready');
    }
    my $target=$schema->resultset('Stock::Stock')->find({uniquename=>'test_accession3'})->stock_id;
    CXGN::Trial::AccessionChange->new({schema=>$schema,trial_id=>$trial})->apply([{plot_id=>$plots[2],new_stock_id=>$target}],{rename_plots=>'none',curator=>1});
    is(property($plots[0],'replicate'),1,'unrelated correction leaves the source plot occurrence unchanged');
    is(property($single,'replicate'),1,'normalization repairs a missing descendant row even when resolved inheritance already matched');
    is(property($pooled,'replicate'),undef,'normalization clears the pooled arbitrary local occurrence');
    is(property($orphan,'replicate'),77,'unknown orphan provenance is not rewritten or assigned to an arbitrary plot');
    my $after=CXGN::Trial::DesignReplication::read($schema,[$single,$pooled,$orphan]);
    is($after->{$single}{occurrence_raw},1,'stored and resolved single-parent counter now agree');
    is($after->{$orphan}{occurrence_ready},0,'unchanged orphan raw metadata is still not publicly advertised as a field counter');
    my $other=CXGN::Trial::TrialCreate->new({chado_schema=>$schema,dbh=>$dbh,owner_id=>41,operator=>'janedoe',program=>'test',trial_location=>'test_location',trial_name=>$prefix.'_other',trial_description=>'Independent field namespace',trial_year=>2031,design_type=>'RCBD',design=>{1=>{plot_name=>$prefix.'_other_P1',plot_number=>1,stock_name=>'test_accession2',rep_number=>1,block_number=>3,row_number=>1,col_number=>1}}})->save_trial;
    die 'Second native field creation failed' if !$other->{trial_id};
    my ($other_experiment)=$dbh->selectrow_array('SELECT ne.nd_experiment_id FROM nd_experiment ne JOIN nd_experiment_project nep USING(nd_experiment_id) WHERE nep.project_id=? AND ne.type_id=?',undef,$other->{trial_id},term('field_layout','experiment_type'));
    my $shared=child('shared',[$plots[0]],77,1,99);
    $schema->resultset('NaturalDiversity::NdExperimentStock')->create({stock_id=>$shared,nd_experiment_id=>$other_experiment,type_id=>term('field_layout','experiment_type')});
    my $shared_state=CXGN::Trial::DesignReplication::read($schema,[$shared])->{$shared};
    is($shared_state->{occurrence_ready},0,'a child shared by two field namespaces cannot advertise one occurrence');
    my $before=$dbh->selectall_arrayref('SELECT stockprop_id,stock_id,type_id,value,rank FROM stockprop WHERE stock_id=ANY(?) ORDER BY stockprop_id',undef,[@plots,$single,$pooled,$orphan,$shared]);
    my $original_stock=$schema->resultset('Stock::Stock')->find({uniquename=>'test_accession2'})->stock_id;
    my $saved=eval {CXGN::Trial::AccessionChange->new({schema=>$schema,trial_id=>$trial})->apply([{plot_id=>$plots[2],new_stock_id=>$original_stock}],{rename_plots=>'none',curator=>1});1};
    ok(!$saved,'normalization refuses a descendant shared by multiple field studies');
    like($@,qr/belongs to multiple field layouts/,'the refusal explains which namespace must be reviewed');
    is_deeply($dbh->selectall_arrayref('SELECT stockprop_id,stock_id,type_id,value,rank FROM stockprop WHERE stock_id=ANY(?) ORDER BY stockprop_id',undef,[@plots,$single,$pooled,$orphan,$shared]),$before,'namespace refusal does not clear or rewrite any original local metadata');

    1;
};
my $error=$@;
$schema->txn_rollback;$active=0;
ok($ran,'field child context scenarios completed and rolled back') or diag($error);
is($schema->resultset('Project::Project')->search({name=>$prefix})->count,0,'no private trial remains');
done_testing;
