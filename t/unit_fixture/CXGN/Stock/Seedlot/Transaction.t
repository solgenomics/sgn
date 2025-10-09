use strict;
use warnings;

use Test::More;
use Data::Dumper;
use lib 't/lib';
use SGN::Test::Fixture;
use CXGN::Stock::Seedlot;
use CXGN::Stock::Seedlot::Transaction;
use SGN::Model::Cvterm;
use CXGN::Stock;

# Helper: return true if the transaction has a non-empty timestamp
sub _txn_ts {
    my ($t) = @_;
    my $ts = eval { $t->timestamp } // '';
    return defined $ts && $ts ne '';
}

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;

my $seedlot_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'seedlot', 'stock_type')->cvterm_id();

print STDERR "Creating stock... ";
my $stock = CXGN::Stock->new( schema => $schema );
print STDERR "Done.\n";
print STDERR "Creating dest_seedlot...\n";

my $dest_seedlot = CXGN::Stock::Seedlot->new(
    schema => $schema,
);

print STDERR "Adding a name. etc...\n";
my $test_accession_stock_id1 = $schema->resultset('Stock::Stock')->find({ uniquename => 'test_accession1' })->stock_id;
my $seedlot_breeding_program_name = "test";
my $seedlot_breeding_program_id   = $schema->resultset('Project::Project')->find({ name => $seedlot_breeding_program_name })->project_id();
$dest_seedlot->uniquename("test seedlot");
$dest_seedlot->location_code("XYZ-123");
$dest_seedlot->accession_stock_id($test_accession_stock_id1);
$dest_seedlot->organization_name('bti');
$dest_seedlot->population_name('test seedlot pop');
$dest_seedlot->breeding_program_id($seedlot_breeding_program_id);
my $return = $dest_seedlot->store();
print STDERR Dumper $return;
my $dest_seedlot_id = $return->{seedlot_id};

print STDERR "SEEDLOT ID: $dest_seedlot_id, STOCK_ID " . $dest_seedlot->stock_id() . "\n";

print STDERR "Creating source_seedlot...\n";
my $source_seedlot = CXGN::Stock::Seedlot->new(
    schema => $schema,
);

$source_seedlot->uniquename("test seedlot 2");
$source_seedlot->location_code("ABC-987");
$source_seedlot->accession_stock_id($test_accession_stock_id1);
$source_seedlot->organization_name('bti');
$source_seedlot->population_name('test seedlot pop');
$source_seedlot->breeding_program_id($seedlot_breeding_program_id);
my $return2 = $source_seedlot->store();
my $source_seedlot_id = $return2->{seedlot_id};

print STDERR "Creating transaction 1...\n";
my $trans = CXGN::Stock::Seedlot::Transaction->new(
    schema => $schema,
);
$trans->from_stock([ $source_seedlot_id, $source_seedlot->uniquename, $seedlot_type_id ]);
$trans->to_stock([ $dest_seedlot_id,   $dest_seedlot->uniquename,   $seedlot_type_id ]);
$trans->amount(5);
$trans->timestamp( scalar localtime );
$trans->description('Moving 5 seed from seedlot 2 to seedlot 1');
$trans->operator('janedoe');

my $trans_id = $trans->store();

my $saved_trans = CXGN::Stock::Seedlot::Transaction->new( schema => $schema, transaction_id => $trans_id );
is_deeply($saved_trans->from_stock(), $trans->from_stock(), "saved seed source");
is_deeply($saved_trans->to_stock(),   $trans->to_stock(),   "saved seed dest");
is($saved_trans->amount(),     $trans->amount(),     "saved amount");
is($saved_trans->timestamp(),  $trans->timestamp(),  "saved timestamp");
is($saved_trans->description(),$trans->description(),"saved description");
is($saved_trans->operator(),   $trans->operator(),   "saved operator");

# checking seedlots after transaction
my $source_seedlot_after_trans1 = CXGN::Stock::Seedlot->new(
    schema    => $schema,
    seedlot_id => $source_seedlot_id
);
is($source_seedlot_after_trans1->current_count,    -5,                      "check current count is correct");
is($source_seedlot_after_trans1->uniquename,       $source_seedlot->uniquename, "check uniquename is saved");
is($source_seedlot_after_trans1->location_code,    $source_seedlot->location_code, "check location is saved");
is($source_seedlot_after_trans1->organization_name,$source_seedlot->organization_name, "check organization is saved");
is($source_seedlot_after_trans1->population_name,  $source_seedlot->population_name, "check population is saved");
is_deeply($source_seedlot_after_trans1->accession, [ $test_accession_stock_id1, 'test_accession1' ], "check accession is saved");
is($source_seedlot_after_trans1->breeding_program_name, $seedlot_breeding_program_name, "seedlot and breeding program ok");
is($source_seedlot_after_trans1->breeding_program_id,   $source_seedlot->breeding_program_id, "seedlot and breeding program id are ok");

my $dest_seedlot_after_trans1 = CXGN::Stock::Seedlot->new(
    schema    => $schema,
    seedlot_id => $dest_seedlot_id
);
print STDERR "Creating seedlot transaction 1 \n";
is($dest_seedlot_after_trans1->current_count,    5,                       "check current count is correct");
is($dest_seedlot_after_trans1->uniquename,       $dest_seedlot->uniquename, "check uniquename is saved");
is($dest_seedlot_after_trans1->location_code,    $dest_seedlot->location_code, "check location is saved");
is($dest_seedlot_after_trans1->organization_name,$dest_seedlot->organization_name, "check organization is saved");
is($dest_seedlot_after_trans1->population_name,  $dest_seedlot->population_name, "check population is saved");
is_deeply($dest_seedlot_after_trans1->accession, [ $test_accession_stock_id1, 'test_accession1' ], "check accession is saved");
is($dest_seedlot_after_trans1->breeding_program_name, $seedlot_breeding_program_name, "seedlot and breeding program ok");
is($dest_seedlot_after_trans1->breeding_program_id,   $dest_seedlot->breeding_program_id, "seedlot and breeding program id are ok");

print STDERR "Creating transaction 2...\n";
my $trans2 = CXGN::Stock::Seedlot::Transaction->new(
    schema => $f->bcs_schema(),
);
$trans2->from_stock([ $source_seedlot_id, $source_seedlot->uniquename, $seedlot_type_id ]);
$trans2->to_stock([ $dest_seedlot_id,   $dest_seedlot->uniquename,   $seedlot_type_id ]);
$trans2->amount(7);
$trans2->timestamp( scalar localtime );
$trans2->description('Moving 7 seed from seedlot 2 to seedlot 1');
$trans2->operator('janedoe');

my $trans_id_2 = $trans2->store();

print STDERR "Creating transaction 3...\n";
my $trans3 = CXGN::Stock::Seedlot::Transaction->new(
    schema => $f->bcs_schema(),
);
$trans3->to_stock([ $source_seedlot_id, $source_seedlot->uniquename, $seedlot_type_id ]);
$trans3->from_stock([ $dest_seedlot_id,   $dest_seedlot->uniquename,   $seedlot_type_id ]);
$trans3->timestamp( scalar localtime );
$trans3->description('Moving 3 seed from seedlot 1 to seedlot 2');
$trans3->operator('janedoe');
$trans3->amount(3);

my $trans_id_3 = $trans3->store();

# checking seedlots after transaction
my $source_seedlot_after_trans3 = CXGN::Stock::Seedlot->new(
    schema    => $schema,
    seedlot_id => $source_seedlot_id
);
is($source_seedlot_after_trans3->current_count,    -9,                         "check current count is correct");
is($source_seedlot_after_trans3->uniquename,       $source_seedlot->uniquename, "check uniquename is saved");
is($source_seedlot_after_trans3->location_code,    $source_seedlot->location_code, "check location is saved");
is($source_seedlot_after_trans3->organization_name,$source_seedlot->organization_name, "check organization is saved");
is($source_seedlot_after_trans3->population_name,  $source_seedlot->population_name, "check population is saved");
is_deeply($source_seedlot_after_trans3->accession, [ $test_accession_stock_id1, 'test_accession1' ], "check accession is saved");
is($source_seedlot_after_trans3->breeding_program_name, $seedlot_breeding_program_name);
is($source_seedlot_after_trans3->breeding_program_id,   $source_seedlot->breeding_program_id);

my @transactions;
foreach my $t (@{ $source_seedlot_after_trans3->transactions() }) {
    ok(_txn_ts($t), "check timestamps saved");
    ok($t->transaction_id, "check transcation ids");
    push @transactions, [ $t->from_stock()->[1], $t->to_stock()->[1], $t->factor() * $t->amount(), $t->operator, $t->description ];
}
is_deeply(
    \@transactions,
    [
        [ 'test seedlot',   'test seedlot 2',  3,  'janedoe', 'Moving 3 seed from seedlot 1 to seedlot 2' ],
        [ 'test seedlot 2', 'test seedlot',   -7, 'janedoe', 'Moving 7 seed from seedlot 2 to seedlot 1' ],
        [ 'test seedlot 2', 'test seedlot',   -5, 'janedoe', 'Moving 5 seed from seedlot 2 to seedlot 1' ],
    ],
    "check source seedlot transactions"
);

my $dest_seedlot_after_trans3 = CXGN::Stock::Seedlot->new(
    schema    => $schema,
    seedlot_id => $dest_seedlot_id
);
is($dest_seedlot_after_trans3->current_count,    9,                        "check current count is correct");
is($dest_seedlot_after_trans3->uniquename,       $dest_seedlot->uniquename, "check uniquename is saved");
is($dest_seedlot_after_trans3->location_code,    $dest_seedlot->location_code, "check location is saved");
is($dest_seedlot_after_trans3->organization_name,$dest_seedlot->organization_name, "check organization is saved");
is($dest_seedlot_after_trans3->population_name,  $dest_seedlot->population_name, "check population is saved");
is_deeply($dest_seedlot_after_trans3->accession, [ $test_accession_stock_id1, 'test_accession1' ], "check accession is saved");
is($dest_seedlot_after_trans3->breeding_program_name, $seedlot_breeding_program_name);
is($dest_seedlot_after_trans3->breeding_program_id,   $dest_seedlot->breeding_program_id);

my @transactions2;
foreach my $t (@{ $dest_seedlot_after_trans3->transactions() }) {
    ok(_txn_ts($t), "check timestamps saved");
    ok($t->transaction_id, "check transcation ids");
    push @transactions2, [ $t->from_stock()->[1], $t->to_stock()->[1], $t->factor() * $t->amount(), $t->operator, $t->description ];
}
is_deeply(
    \@transactions2,
    [
        [ 'test seedlot',   'test seedlot 2', -3, 'janedoe', 'Moving 3 seed from seedlot 1 to seedlot 2' ],
        [ 'test seedlot 2', 'test seedlot',   7, 'janedoe', 'Moving 7 seed from seedlot 2 to seedlot 1' ],
        [ 'test seedlot 2', 'test seedlot',   5, 'janedoe', 'Moving 5 seed from seedlot 2 to seedlot 1' ],
    ],
    'check transactions of dest_seedlot'
);

# test editing transaction 3 from test seedlot page
my $edit_trans3 = CXGN::Stock::Seedlot::Transaction->new(
    schema         => $f->bcs_schema(),
    transaction_id => $trans_id_3,
    seedlot_id     => $dest_seedlot_id
);
$edit_trans3->to_stock([ $source_seedlot_id, $source_seedlot->uniquename, $seedlot_type_id ]);
$edit_trans3->from_stock([ $dest_seedlot_id,   $dest_seedlot->uniquename,   $seedlot_type_id ]);
$edit_trans3->timestamp( scalar localtime );
$edit_trans3->description('Moving 5 seed from seedlot 1 to seedlot 2');
$edit_trans3->operator('janedoe');
$edit_trans3->amount(5);

my $edit_trans_id = $edit_trans3->store();
is($edit_trans_id, $trans_id_3);

my $test_seedlot_after_editing = CXGN::Stock::Seedlot->new(
    schema    => $schema,
    seedlot_id => $dest_seedlot_id
);
is($test_seedlot_after_editing->current_count, 7);

# Deleting transaction 3
print STDERR "Deleting transaction 3...\n";
my $saved_trans3 = CXGN::Stock::Seedlot::Transaction->new( schema => $schema, transaction_id => $trans_id_3 );
$saved_trans3->delete_transaction();

# Checking seedlots after transaction deletion
# Checking source seedlot after transaction deletion
print STDERR "Checking source seedlot after deletion...\n";
my $source_seedlot_after_trans3_delete = CXGN::Stock::Seedlot->new(
    schema    => $schema,
    seedlot_id => $source_seedlot_id
);
is($source_seedlot_after_trans3_delete->current_count,    -12,                        "check current count is correct");
is($source_seedlot_after_trans3_delete->uniquename,       $source_seedlot->uniquename, "check uniquename is saved");
is($source_seedlot_after_trans3_delete->location_code,    $source_seedlot->location_code, "check location is saved");
is($source_seedlot_after_trans3_delete->organization_name,$source_seedlot->organization_name, "check organization is saved");
is($source_seedlot_after_trans3_delete->population_name,  $source_seedlot->population_name, "check population is saved");
is_deeply($source_seedlot_after_trans3_delete->accession, [ $test_accession_stock_id1, 'test_accession1' ], "check accession is saved");
is($source_seedlot_after_trans3_delete->breeding_program_name, $seedlot_breeding_program_name);
is($source_seedlot_after_trans3_delete->breeding_program_id,   $source_seedlot->breeding_program_id);

my @transactions3;
foreach my $t (@{ $source_seedlot_after_trans3_delete->transactions() }) {
    ok(_txn_ts($t), "check timestamps saved");
    ok($t->transaction_id, "check transaction ids");
    push @transactions3, [ $t->from_stock()->[1], $t->to_stock()->[1], $t->factor() * $t->amount(), $t->operator, $t->description ];
}
print STDERR "Source seedlot transactions...\n";
print STDERR Dumper \@transactions3;
is_deeply(
    \@transactions3,
    [
        [ 'test seedlot 2', 'test seedlot', -7, 'janedoe', 'Moving 7 seed from seedlot 2 to seedlot 1' ],
        [ 'test seedlot 2', 'test seedlot', -5, 'janedoe', 'Moving 5 seed from seedlot 2 to seedlot 1' ],
    ],
    "check source seedlot transactions after transaction 3 deletion"
);

# Checking destination seedlot after transaction deletion
print STDERR "Checking destination seedlot after deletion...\n";
my $dest_seedlot_after_trans3_delete = CXGN::Stock::Seedlot->new(
    schema    => $schema,
    seedlot_id => $dest_seedlot_id
);
is($dest_seedlot_after_trans3_delete->current_count,    12,                       "check current count is correct");
is($dest_seedlot_after_trans3_delete->uniquename,       $dest_seedlot->uniquename, "check uniquename is saved");
is($dest_seedlot_after_trans3_delete->location_code,    $dest_seedlot->location_code, "check location is saved");
is($dest_seedlot_after_trans3_delete->organization_name,$dest_seedlot->organization_name, "check organization is saved");
is($dest_seedlot_after_trans3_delete->population_name,  $dest_seedlot->population_name, "check population is saved");
is_deeply($dest_seedlot_after_trans3_delete->accession, [ $test_accession_stock_id1, 'test_accession1' ], "check accession is saved");
is($dest_seedlot_after_trans3_delete->breeding_program_name, $seedlot_breeding_program_name);
is($dest_seedlot_after_trans3_delete->breeding_program_id,   $dest_seedlot->breeding_program_id);

my @transactions4;
foreach my $t (@{ $dest_seedlot_after_trans3_delete->transactions() }) {
    ok(_txn_ts($t), "check timestamps saved");
    ok($t->transaction_id, "check transaction ids");
    push @transactions4, [ $t->from_stock()->[1], $t->to_stock()->[1], $t->factor() * $t->amount(), $t->operator, $t->description ];
}
print STDERR "Destination seedlot transactions...\n";
print STDERR Dumper \@transactions4;
is_deeply(
    \@transactions4,
    [
        [ 'test seedlot 2', 'test seedlot', 7, 'janedoe', 'Moving 7 seed from seedlot 2 to seedlot 1' ],
        [ 'test seedlot 2', 'test seedlot', 5, 'janedoe', 'Moving 5 seed from seedlot 2 to seedlot 1' ],
    ],
    'check transactions of dest_seedlot after transaction 3 deletion'
);

# clean up data and done testing
eval {
    $f->clean_up_db();
    1;
} or do {
    diag "clean_up_db() failed: $@";
};

done_testing();
