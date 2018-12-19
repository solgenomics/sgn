
=head1 NAME

merge_stocks.pl - merge stocks using a file with stocks to merge

=head1 DESCRIPTION

merge_stocks.pl -H [database host] -D [database name]  [ -x ] mergefile.txt

Options:

 -H the database host
 -D the database name
 -x flag; if present, delete the empty remaining accession

mergefile.txt: A file with three columns:  bad name, good name.

All the metadata of bad name will be transferred to good name.
If -x is used, stock with name bad name will be deleted.

=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>

=cut

use strict;

use Getopt::Std;
use CXGN::DB::InsertDBH;
use CXGN::DB::Schemas;
use CXGN::Stock;

our($opt_H, $opt_D, $opt_x);
getopts('H:D:x');

my $dbh = CXGN::DB::InsertDBH->new( 
    { 
	dbhost => $opt_H,
	dbname => $opt_D ,
	dbargs => { 
	    AutoCommit => 0,
	    RaiseError => 1,
	    limit_dialect => 'LimitOffset',
	}
    });

my $delete_merged_stock = $opt_x;

print STDERR "Note: -x: Deleting stocks that have been merged into other stocks.\n";

my $s = CXGN::DB::Schemas->new({ dbh => $dbh });
my $schema = $s->bcs_schema();
my $file = shift;

open(my $F, "<", $file) || die "Can't open file $file.\n";

my $header = <$F>;

eval { 
    while (<$F>) { 
	chomp;
	my ($merge_stock_name, $good_stock_name) = split /\t/;
	
	my $stock_row = $schema->resultset("Stock::Stock")->find( { uniquename => $good_stock_name } );
	if (!$stock_row) { 
	    print STDERR "Stock $good_stock_name not found. Skipping...\n";
	    
	    next();
	}
	
	my $merge_row = $schema->resultset("Stock::Stock")->find( { uniquename => $merge_stock_name } );
	if (!$merge_row) { 
	    print STDERR "Stock $merge_stock_name not available for merging. Skipping\n";
	    next();
	}
	
	my $good_stock = CXGN::Chado::Stock->new($schema, $stock_row->stock_id);
	my $merge_stock = CXGN::Chado::Stock->new($schema, $merge_row->stock_id);
	
	print STDERR "Merging stock $merge_stock_name into $good_stock_name... ";
	$good_stock->merge($merge_stock->get_stock_id(), $delete_merged_stock);
	print STDERR "Done.\n";
    }
    
};
if ($@) { 
    print STDERR "An ERROR occurred ($@). Rolling back changes...\n";
    $dbh->rollback();
}
else { 
    print STDERR "Script is done. Committing... ";
    $dbh->commit();
    print STDERR "Done.\n";
}
