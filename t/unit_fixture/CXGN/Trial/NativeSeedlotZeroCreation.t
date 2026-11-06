use strict;
use warnings;
use lib 't/lib';
use Test::More;
use JSON qw(encode_json);
use SGN::Test::Fixture;
use SGN::Model::Cvterm;
use CXGN::JSONUtils qw(decode_stored_json);
use CXGN::Trial::TrialCreate;
use CXGN::Trial::TrialLayout;
use CXGN::Stock::Seedlot;
use CXGN::Stock::Seedlot::Transaction;

my $f=SGN::Test::Fixture->new;
my $s=$f->bcs_schema;
my $dbh=$s->storage->dbh;
$s->storage->auto_savepoint(1);
my $prefix='audit_native_seedlot_zero_'.$$;
my $lot_id;
sub term {SGN::Model::Cvterm->get_cvterm_row($s,@_)->cvterm_id}
$s->txn_begin;
my $ok=eval {
    my $accession=$s->resultset('Stock::Stock')->find({uniquename=>'test_accession1'});
    die 'The private literal-zero seedlot fixture name already exists' if $s->resultset('Stock::Stock')->find({uniquename=>'0'});
    my $lot=$s->resultset('Stock::Stock')->create({name=>$prefix.'_lot',uniquename=>'0',type_id=>term('seedlot','stock_type'),organism_id=>$accession->organism_id});
    $lot_id=$lot->stock_id;
    $s->resultset('Stock::StockRelationship')->create({subject_id=>$accession->stock_id,object_id=>$lot->stock_id,type_id=>term('collection_of','stock_relationship')});
    CXGN::Stock::Seedlot::Transaction->new(schema=>$s,from_stock=>[$lot->stock_id,$lot->uniquename],to_stock=>[$lot->stock_id,$lot->uniquename],amount=>100,weight_gram=>50,factor=>1,operator=>'janedoe',timestamp=>'2031-01-01',description=>'Private known opening')->store;
    my %design;
    my @amount=(0,0,10);
    my @weight=(0,5,0);
    for my $i (1..3) {
        $design{$i}={plot_name=>"${prefix}_plot_$i",stock_name=>'test_accession1',plot_number=>$i,rep_number=>0,row_number=>0,col_number=>$i-1,seedlot_name=>$lot->uniquename,num_seed_per_plot=>$amount[$i-1],weight_gram_seed_per_plot=>$weight[$i-1]};
    }
    $design{1}{block_number}=undef;
    $design{2}{block_number}=0;
    my $made=CXGN::Trial::TrialCreate->new({chado_schema=>$s,dbh=>$dbh,owner_id=>41,operator=>'janedoe',program=>'test',trial_location=>'test_location',trial_name=>$prefix,trial_description=>'Native known-zero seed packets and explicit NULL block',trial_year=>2031,design_type=>'CRD',design=>\%design})->save_trial;
    ok($made->{trial_id},'actual native creator stored the three input positions') or die encode_json($made);
    my $layout=CXGN::Trial::TrialLayout->new({schema=>$s,trial_id=>$made->{trial_id},experiment_type=>'field_layout'})->get_design;
    for my $i (1..3) {
        my $stock=$s->resultset('Stock::Stock')->find({uniquename=>"${prefix}_plot_$i"});
        is($layout->{$i}{plot_name},"${prefix}_plot_$i","actual cached entry$i is the addressed physical plot");
        my $packets=$s->resultset('Stock::StockRelationship')->search({subject_id=>$stock->stock_id,object_id=>$lot->stock_id,type_id=>term('seed transaction','stock_relationship')});
        is($packets->count,1,"native plot$i has one original planting transaction");
        my $value=decode_stored_json($packets->first->value);
        is($value->{amount},$amount[$i-1],"native plot$i raw packet preserves known seed count, including zero");
        is($value->{weight_gram},$weight[$i-1],"native plot$i raw packet preserves known grams, including zero");
        is($layout->{$i}{num_seed_per_plot},$amount[$i-1],"native plot$i cached layout retains original count");
        is($layout->{$i}{weight_gram_seed_per_plot},$weight[$i-1],"native plot$i cached layout retains original weight");
        my($block)=$dbh->selectrow_array('SELECT value FROM stockprop WHERE stock_id=? AND type_id=?',undef,$stock->stock_id,term('block','stock_property'));
        if ($i==1) {ok(!defined($block),'explicit input NULL physical block is stored unknown, without default1');ok(!defined($layout->{$i}{block_number}),'cached explicit NULL block remains unknown')}
        elsif ($i==2) {is($block,0,'explicit physical block0 survives native store');is($layout->{$i}{block_number},0,'cached physical block0 survives')}
        else {is($block,1,'omitted block retains the established native default1')}
    }
    my $inventory=CXGN::Stock::Seedlot->new(schema=>$s,seedlot_id=>$lot->stock_id);
    is_deeply([$inventory->get_current_count_property,$inventory->get_current_weight_property],[90,45],'paired cached balances retain known numeric controls');
    is_deeply([$inventory->current_count,$inventory->current_weight],[90,45],'fresh transaction totals agree with numeric controls');
    1;
};
my $error=$@;
$s->txn_rollback;
ok($ok,'actual native seedlot/NULL layout qualification completed and rolled back') or diag($error);
is($dbh->selectrow_array('SELECT count(*) FROM project WHERE name=?',undef,$prefix),0,'no private trial remains');
is($dbh->selectrow_array('SELECT count(*) FROM stock WHERE uniquename LIKE ?',undef,$prefix.'%'),0,'no private plot or seedlot remains');
is($dbh->selectrow_array('SELECT count(*) FROM stock WHERE stock_id=?',undef,$lot_id),0,'the private literal-zero seedlot was rolled back by ID') if $lot_id;
done_testing;
