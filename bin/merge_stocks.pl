
use strict;

use Getopt::Std;
use CXGN::DB::InsertDBH;
use CXGN::DB::Schemas;
use CXGN::Chado::Stock;

our($opt_H, $opt_D);
getopt('H:D:');

my $dbh = CXGN::DB::InsertDBH->new( 
    { 
	dbhost => $opt_H,
	dbname => $opt_D 
    });

my $s = CXGN::DB::Schemas->new({ dbh => $dbh});
my $schema = $s->bcs_schema();

my $file = shift;

open(my $F, "<", $file) || die "Can't open file $file.\n";

my $header = <$F>;

while (<$F>) { 
    chomp;
    my ($line_count, $merge_stock_name, $good_stock_name) = split /\t/;
    
    my $stock_row = $schema->resultset("Stock::Stock")->find( { uniquename => $good_stock_name });
    if (!$stock_row) { 
	print STDERR "Stock $good_stock_name not found. Skipping..\n";
	next();
    }

    my $merge_row = $schema->resultset("Stock::Stock")->find( { uniquename => $merge_stock_name });
    if (!$merge_row) { 
	print STDERR "Stock $merge_stock_name not available for merging. Skipping\n";
	next();
    }

    my $good_stock = CXGN::Chado::Stock->new($schema, $stock_id);
    my $merge_stock = CXGN::Chado::STock->new($schema, $merge_id);

    print STDERR "Merging stock $merge_stock_name into $good_stock_name... ";
    $good_stock->merge($merge_stock);
    print STDERR "Done.\n";
}
    
