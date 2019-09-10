
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


print "Password for $opt_H / $opt_D: \n";
my $pw = (<STDIN>);
chomp($pw);

my $delete_merged_stock = $opt_x;

print STDERR "Note: -x: Deleting stocks that have been merged into other stocks.\n";

print STDERR "Connecting to database...\n";
my $dsn = 'dbi:Pg:database='.$opt_D.";host=".$opt_H.";port=5432";

my $dbh = DBI->connect($dsn, "postgres", $pw, { AutoCommit => 0, RaiseError=>1 });

print STDERR "Connecting to DBI schema...\n";
my $bcs_schema = Bio::Chado::Schema->connect($dsn, "postgres", $pw);

my $s = CXGN::DB::Schemas->new({ dbh => $dbh });
my $schema = $s->bcs_schema();
my $file = shift;

open(my $F, "<", $file) || die "Can't open file $file.\n";

my $header = <$F>;
print STDERR "Skipping header line $header\n";
eval { 
    while (<$F>) { 
        print STDERR "Read line: $_\n";
	chomp;
	my ($merge_stock_name, $good_stock_name) = split /\t/;
	print STDERR "bad name: $merge_stock_name, good name: $good_stock_name\n";
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
	
	my $good_stock = CXGN::Stock->new( { schema => $schema, stock_id => $stock_row->stock_id });
	my $merge_stock = CXGN::Stock->new( { schema => $schema, stock_id => $merge_row->stock_id });
	
	print STDERR "Merging stock $merge_stock_name into $good_stock_name... ";
	$good_stock->merge($merge_stock->stock_id(), $delete_merged_stock);
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
