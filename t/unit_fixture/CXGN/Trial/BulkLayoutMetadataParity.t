use strict;
use utf8;
use warnings;
use lib 't/lib';
use Test::More;
use JSON qw(encode_json);
use CXGN::JSONUtils qw(decode_stored_json);
use SGN::Test::Fixture;
use SGN::Model::Cvterm;
use CXGN::Trial::TrialCreate;
use CXGN::Trial::TrialLayout;
use CXGN::Trial::TrialLayout::AbstractLayout;

# The upstream bulk reader must preserve the same stored metadata as the
# generic scalar reader. All rows are private and the whole scenario rolls back.
my $fixture = SGN::Test::Fixture->new;
my $schema = $fixture->bcs_schema;
my $dbh = $schema->storage->dbh;
$schema->storage->auto_savepoint(1);
my $prefix = 'audit_bulk_layout_parity_'.$$;
sub term { SGN::Model::Cvterm->get_cvterm_row($schema, @_)->cvterm_id }
my $transaction_open = 0;
END { eval { $schema->txn_rollback if $transaction_open } if $schema }
$schema->txn_begin;
$transaction_open = 1;
my $ran = eval {
    my $accession = $schema->resultset('Stock::Stock')->find({uniquename=>'test_accession1'});
    my $lot = $schema->resultset('Stock::Stock')->create({
        name=>$prefix.'_lot', uniquename=>$prefix.'_lot',
        type_id=>term('seedlot', 'stock_type'), organism_id=>$accession->organism_id,
    });
    $schema->resultset('Stock::StockRelationship')->create({
        subject_id=>$accession->stock_id, object_id=>$lot->stock_id,
        type_id=>term('collection_of', 'stock_relationship'),
    });
    my @group = ('0', '01', undef);
    my %design;
    for my $number (1..3) {
        $design{$number} = {
            plot_name=>"${prefix}_P$number", plot_number=>$number,
            stock_name=>'test_accession1', rep_number=>$group[$number-1],
            design_rep_number=>$group[$number-1], block_number=>$group[$number-1],
            range_number=>$group[$number-1], row_number=>0, col_number=>$number-1,
        };
    }
    @{$design{1}}{qw(seedlot_name num_seed_per_plot weight_gram_seed_per_plot)} = ($lot->uniquename, 0, 0);
    my $created = CXGN::Trial::TrialCreate->new({
        chado_schema=>$schema, dbh=>$dbh, owner_id=>41, operator=>'janedoe',
        program=>'test', trial_location=>'test_location', trial_name=>$prefix,
        trial_description=>'Rollback-only bulk/scalar layout metadata parity',
        trial_year=>2031, design_type=>'CRD', design=>\%design,
    })->save_trial;
    die 'Native trial creation failed: '.encode_json($created) if !$created->{trial_id};
    my @plots = map { $schema->resultset('Stock::Stock')->find({uniquename=>"${prefix}_P$_"}) } 1..3;
    for my $property ([$plots[1], 'not_planted', 1], [$plots[2], 'rejected', 1], [$plots[2], 'reject_reason', 'reader parity fixture']) {
        $property->[0]->create_related('stockprops', {
            type_id=>term($property->[1], 'stock_property'), value=>$property->[2], rank=>0,
        });
    }
    # Qualify the actual object written by Transaction, then both documented
    # database encodings. Byte-upgraded JSON is not a nested JSON string.
    my $packet = $schema->resultset('Stock::StockRelationship')->find({
        subject_id=>$plots[0]->stock_id, object_id=>$lot->stock_id,
        type_id=>term('seed transaction', 'stock_relationship'),
    });
    die 'Private native packet missing' if !$packet;
    my ($native_text)=$dbh->selectrow_array('SELECT value FROM stock_relationship WHERE stock_relationship_id=?',undef,$packet->stock_relationship_id);
    my $native_packet=decode_stored_json($native_text);
    is(ref($native_packet),'HASH','actual native Transaction writer stores one JSON object');
    is_deeply([@{$native_packet}{qw(amount weight_gram)}],[0,0],'actual writer preserves both known zero quantities');
    my $stored_packet={amount=>0,weight_gram=>0,factor=>1,operator=>'Оператор é',description=>'Пакет, "перевірено"',input_history=>{row=>0,label=>'001'}};
    for my $storage (qw(octets characters)) {
        my $encoded=$storage eq 'octets' ? encode_json($stored_packet) : JSON->new->encode($stored_packet);
        $packet->update({value=>$encoded});
        my ($roundtrip)=$dbh->selectrow_array('SELECT value FROM stock_relationship WHERE stock_relationship_id=?',undef,$packet->stock_relationship_id);
        is_deeply(decode_stored_json($roundtrip),$stored_packet,"$storage encoding passes a real PostgreSQL object round trip");
        my $layout = CXGN::Trial::TrialLayout->new({schema=>$schema, trial_id=>$created->{trial_id}, experiment_type=>'field_layout'});
        ok($layout->can('retrieve_plot_info') == \&CXGN::Trial::TrialLayout::AbstractLayout::retrieve_plot_info,
            'ordinary phenotyping layout uses the upstream bulk-dispatch path');
        my $bulk = $layout->generate_and_cache_layout;
        my %scalar;
        $layout->retrieve_plot_info($_, \%scalar) for @{$layout->_get_plots};
        my @fields = qw(plot_name plot_id accession_name accession_id plot_number block_number row_number col_number rep_number range_number design_rep_number design_replicate_recorded accession_occurrence_ready not_planted rejected reject_reason seedlot_name num_seed_per_plot weight_gram_seed_per_plot);
        for my $number (1..3) {
            is_deeply(
                [map {exists($bulk->{$number}{$_}) ? [1, $bulk->{$number}{$_}] : [0]} @fields],
                [map {exists($scalar{$number}{$_}) ? [1, $scalar{$number}{$_}] : [0]} @fields],
                "bulk and scalar readers preserve all addressed metadata for position$number",
            );
        }
        is($bulk->{1}{row_number}, '0', 'bulk reader preserves numeric-zero physical coordinate');
        is($bulk->{1}{block_number}, '0', 'bulk reader preserves numeric-zero physical block');
        is($bulk->{2}{design_rep_number}, '01', 'bulk reader preserves exact recorded group text');
        ok(!defined($bulk->{3}{design_rep_number}), 'recorded unknown group remains unknown');
        is($bulk->{3}{accession_occurrence_ready}, 1, 'whole-field operational cutover remains visible');
        is_deeply([map {$bulk->{$_}{rep_number}} 1..3], [1,2,3], 'operational occurrence numbering is separate from design groups');
        is_deeply([$bulk->{1}{num_seed_per_plot}, $bulk->{1}{weight_gram_seed_per_plot}], [0,0], "$storage retains both known zero packet quantities");
        is($bulk->{1}{seed_transaction_operator},$stored_packet->{operator},"$storage preserves non-ASCII operator text");
        my $cached=CXGN::Trial::TrialLayout->new({schema=>$schema,trial_id=>$created->{trial_id},experiment_type=>'field_layout'})->get_design;
        for my $number (1..3) {
            is_deeply([map {exists($cached->{$number}{$_}) ? [1,$cached->{$number}{$_}] : [0]} @fields],
                [map {exists($bulk->{$number}{$_}) ? [1,$bulk->{$number}{$_}] : [0]} @fields],
                "$storage cached JSON retains the addressed metadata at position$number");
        }
        ok($bulk->{2}{not_planted} && $bulk->{3}{rejected}, 'bulk cache retains the independent plot flags');
    }
    1;
};
my $error = $@;
$schema->txn_rollback;
$transaction_open = 0;
ok($ran, 'private parity scenario completed and rolled back') or diag($error);
is($dbh->selectrow_array('SELECT count(*) FROM project WHERE name=?', undef, $prefix), 0, 'private trial removed');
is($dbh->selectrow_array('SELECT count(*) FROM stock WHERE uniquename LIKE ?', undef, $prefix.'%'), 0, 'private units and seedlot removed');
done_testing;
