
=head1 NAME

merge_stocks.pl - merge stocks using a file with stocks to merge

=head1 DESCRIPTION

merge_stocks.pl -H [database host] -D [database name]  [ -x ] mergefile.txt

Options:

 -H the database host
 -D the database name
 -x flag; if present, delete the empty remaining accession
 -P password

mergefile.txt: A tab-separated file with two columns. Include the following header as the first line: bad name  good name

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


our($opt_H, $opt_D, $opt_x, $opt_P);
getopts('H:D:xP:');

my $pw = $opt_P;

if (! $pw) { 
    print "Password for $opt_H / $opt_D: \n";
    $pw = (<STDIN>);
    chomp($pw);
}

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

my @merged_stocks_to_delete = ();
my @merge_errors = ();

print STDERR "Skipping header line $header\n";
eval {
    while (<$F>) {
        print STDERR "Read line: $_\n";
	chomp;
	my ($merge_stock_name, $good_stock_name) = split /\t/;
	print STDERR "bad name: $merge_stock_name, good name: $good_stock_name\n";

	# for now, only allow accessions to be merged!
	my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();

	print STDERR "Working with accession type id of $accession_type_id...\n";
	
	my $stock_row = $schema->resultset("Stock::Stock")->find( { uniquename => $good_stock_name, type_id=>$accession_type_id } );
	if (!$stock_row) {
	    print STDERR "Stock $good_stock_name (of type accession) not found. Skipping...\n";

	    next();
	}

	my $merge_row = $schema->resultset("Stock::Stock")->find( { uniquename => $merge_stock_name, type_id => $accession_type_id  } );
	if (!$merge_row) {
	    print STDERR "Stock $merge_stock_name (of type accession) not available for merging. Skipping\n";
	    next();
	}

	my $good_stock = CXGN::Stock->new( { schema => $schema, stock_id => $stock_row->stock_id });
	my $merge_stock = CXGN::Stock->new( { schema => $schema, stock_id => $merge_row->stock_id });

	print STDERR "Merging stock $merge_stock_name into $good_stock_name... ";
	my $merge_error = $good_stock->merge($merge_stock->stock_id());

	if ( $merge_error ) {
		push @merge_errors, "ERROR: Could not merge $merge_stock_name into $good_stock_name [$merge_error]";
		next();
	}

	if ($delete_merged_stock) {
	    push @merged_stocks_to_delete, $merge_stock->stock_id();
	}
	
	print STDERR "Done.\n";
    }


    if ($delete_merged_stock) {
	print STDERR "Delete merged stocks ( -x option)...\n";
	foreach my $remove_stock_id (@merged_stocks_to_delete) {
	    my $q = "delete from phenome.stock_owner where stock_id=?";
	    my $h = $dbh->prepare($q);
	    $h->execute($remove_stock_id);

	    $q = "delete from phenome.stock_image where stock_id=?";
	    $h = $dbh->prepare($q);
	    $h->execute($remove_stock_id);
	    
	    my $row = $schema->resultset('Stock::Stock')->find( { stock_id => $remove_stock_id });
	    print STDERR "Deleting stock ".$row->uniquename." (id=$remove_stock_id)\n";
	    $row->delete();
	}
	print STDERR "Done with deletions.\n";
    }

};
if ($@) {
    print STDERR "An ERROR occurred ($@). Rolling back changes...\n";
    $dbh->rollback();
}
else {
    print STDERR "Script is done. Committing... ";
    $dbh->commit();

	if ( scalar(@merge_errors) > 0 ) {
		print STDERR "WARNING: THE FOLLOWING STOCKS COULD NOT BE MERGED!\n";
		foreach (@merge_errors) {
			print STDERR "$_\n";
		}
	}
    print STDERR "Done.\n";
}
