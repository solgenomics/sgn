
use strict;

use Test::More;
use Data::Dumper;
use lib 't/lib';
use SGN::Test::Fixture;
use CXGN::Seedlot;
use CXGN::Seedlot::Transaction;

my $f = SGN::Test::Fixture->new();

print STDERR "Creating dest_seedlot...\n";

my $dest_seedlot = CXGN::Seedlot->new(
    schema => $f->bcs_schema(),
    );

$dest_seedlot->name("test seedlot");
$dest_seedlot->location_code("XYZ-123");
my $dest_seedlot_id = $dest_seedlot->store();

print STDERR "Creating source_seedlot...\n";
my $source_seedlot = CXGN::Seedlot->new(
    schema => $f->bcs_schema(),
    );

$source_seedlot->name("test seedlot 2");
$source_seedlot->location_code("ABC-987");
my $source_seedlot_id = $source_seedlot->store();

my $trans = CXGN::Seedlot::Transaction->new(
    schema => $f->bcs_schema(),
    );

$trans->source_id($source_seedlot_id);
$trans->seedlot_id($dest_seedlot_id);
$trans->amount(5);

$trans->store();

my $trans2 = CXGN::Seedlot::Transaction->new(
    schema => $f->bcs_schema(),
    );

$trans2->source_id($source_seedlot_id);
$trans2->seedlot_id($dest_seedlot_id);
$trans2->amount(7);

$trans2->store();

my $trans3 = CXGN::Seedlot::Transaction->new(
    schema => $f->bcs_schema(),
    );

$trans3->source_id($dest_seedlot_id);
$trans3->seedlot_id($source_seedlot_id);
$trans3->amount(3);

$trans3->store();




my $seedlot = CXGN::Seedlot->new( schema => $f->bcs_schema(), seedlot_id=> $dest_seedlot_id);

my $transactions = $seedlot->transactions();

print STDERR scalar(@$transactions)." transactions\n";

print STDERR "Amount: ".$transactions->[0]->amount()."\n";

print STDERR "Factor: ".$transactions->[0]->factor()."\n";

print STDERR "Current count: ".$seedlot->current_count()."\n";
