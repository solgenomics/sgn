
use strict;

use Test::More;
use Data::Dumper;
use lib 't/lib';
use SGN::Test::Fixture;
use CXGN::Seedlot;
use CXGN::Seedlot::Transaction;

my $f = SGN::Test::Fixture->new();

print STDERR "Creating stock... ";
my $stock = CXGN::Stock->new( schema => $f->bcs_schema() );
print STDERR "Done.\n";
print STDERR "Creating dest_seedlot...\n";

my $dest_seedlot = CXGN::Seedlot->new(
    schema => $f->bcs_schema(),
    );

print STDERR "Adding a name. etc...\n";
$dest_seedlot->uniquename("test seedlot");
$dest_seedlot->location_code("XYZ-123");
my $dest_seedlot_id = $dest_seedlot->store();

print "SEEDLOT ID: $dest_seedlot_id, STOCK_ID ".$dest_seedlot->stock_id()."\n";

print STDERR "Creating source_seedlot...\n";
my $source_seedlot = CXGN::Seedlot->new(
    schema => $f->bcs_schema(),
    );

$source_seedlot->uniquename("test seedlot 2");
$source_seedlot->location_code("ABC-987");
my $source_seedlot_id = $source_seedlot->store();

print STDERR "Creating transaction 1...\n";
my $trans = CXGN::Seedlot::Transaction->new(
    schema => $f->bcs_schema(),
    );

$trans->source_id($source_seedlot_id);
$trans->seedlot_id($dest_seedlot_id);
$trans->amount(5);

my $trans_id = $trans->store();

my $saved_trans = CXGN::Seedlot::Transaction->new(schema=>$f->bcs_schema(), transaction_id => $trans_id);

is($saved_trans->source_id(), $trans->source_id(), "saved seed source");
is($saved_trans->amount(), $trans->amount(), "saved amount");

print STDERR "Creating transaction 2...\n";
my $trans2 = CXGN::Seedlot::Transaction->new(
    schema => $f->bcs_schema(),
    );

$trans2->source_id($source_seedlot_id);
$trans2->seedlot_id($dest_seedlot_id);
$trans2->amount(7);

$trans2->store();

print STDERR "Creating transaction 3...\n";
my $trans3 = CXGN::Seedlot::Transaction->new(
    schema => $f->bcs_schema(),
    );

$trans3->source_id($dest_seedlot_id);
$trans3->seedlot_id($source_seedlot_id);
$trans3->amount(3);

$trans3->store();

my $seedlot = CXGN::Seedlot->new( schema => $f->bcs_schema(), seedlot_id=> $dest_seedlot_id);
is($seedlot->seedlot_id(), $dest_seedlot_id, "saved seedlot source_id");

print STDERR "TYPE_ID: ".$seedlot->type_id()."\n";

my $transactions = $seedlot->transactions();

print STDERR scalar(@$transactions)." transactions\n";

print STDERR "Amount: ".$transactions->[0]->amount()."\n";

print STDERR "Factor: ".$transactions->[0]->factor()."\n";

print STDERR "Current count: ".$seedlot->current_count()."\n";

done_testing();
