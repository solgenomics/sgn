
=head1 NAME

delete_stocks.pl - delete stocks from a cxgn database

=head1 DESCRIPTION

perl delete_stocks.pl -H [host] -D [dbname] [-s accession ] -t (for testing) file

where the file is a text file containing  a list of uniquenames specifying the stocks to be deleted, one per line.

The script will check now if the stock has any associated experiments and not delete such accessions.

The parameter -s specifies the type of stock (accession, tissue_sample, or plant) to be deleted.

The default is "accession".

Note that the script cannot delete plots, subplots, crosses or families. This is because these data types are managed on a trial or cross level and should not be individually modified.

If the -t flag is provided, the changes will be rolled back in the database.

Note that it may be possible that some stocks have additional connections, such as images, that this script does not delete yet, and so won't be able to delete those stocks.

The file is a text file containing one accession name per line. There is no header line.

=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>

=cut

use strict;
use Getopt::Std;
use DBI;
use Bio::Chado::Schema;
use CXGN::Phenome::Schema;
use CXGN::Stock;
use CXGN::Stock::Plot;

our ($opt_H, $opt_D, $opt_t, $opt_s, $opt_p);

getopts('H:D:s:tp:');

my $stock_type = $opt_s || "accession";

if ($stock_type eq 'plot' || $stock_type eq 'subplot' || $stock_type eq 'cross' || $stock_type eq 'family' ) {
    print STDERR "This script cannot delete plots or subplots. They have to be managed through the trial or cross interface.\n";
    exit();
}

my $file = shift;

my $pw;

if (! $opt_p) { 
    print "Password for $opt_H / $opt_D: \n";
    $pw = <>;
    chomp($pw);
}
else { $pw = $opt_p; }

print STDERR "Connecting to database...\n";
my $dsn = 'dbi:Pg:database='.$opt_D.";host=".$opt_H.";port=5432";

my $dbh = DBI->connect($dsn, "postgres", $pw);

print STDERR "Connecting to DBI schema...\n";
my $bcs_schema = Bio::Chado::Schema->connect($dsn, "postgres", $pw);
my $phenome_schema = CXGN::Phenome::Schema->connect($dsn, "postgres", $pw,  { on_connect_do => ['set search_path to public,phenome;'] });
    
my $stock_count = 0;
my $deleted_stock_count = 0;
my $stock_owner_count = 0;
my $missing_stocks = 0;

my $cv_id = $bcs_schema->resultset("Cv::Cv")->find( { name => 'stock_type' } )->cv_id();
my $stock_type_cvterm_id = $bcs_schema->resultset("Cv::Cvterm")->find( { name => $stock_type, cv_id=> $cv_id })->cvterm_id();

open(my $F, "<", $file) || die " Can't open file $file\n";

while (<$F>) { 
    chomp;
    
    my $stock_name = $_;
    $stock_name =~ s/\r//g;
    if (!$stock_name) { 
	next();
    }

    $stock_count++;

    print STDERR "Processing $stock_name\n";

    my $stock_row = $bcs_schema->resultset("Stock::Stock")->find( { uniquename => $stock_name, type_id => $stock_type_cvterm_id });
    
    if (!$stock_row) { 
	print STDERR "Could not find stock $stock_name of type $stock_type. Skipping...\n";
	$missing_stocks++;
	next;
    }
    
    my $stock_id = $stock_row->stock_id();
    
    my $stock = CXGN::Stock->new( { schema => $bcs_schema, stock_id => $stock_id });

    # check if stock has associated trials, refuse to delete if yes
    #
    my @trials = $stock->get_trials();

    if (@trials > 0) {
	print STDERR "Stock $stock_name cannot be deleted because it is associated with trials ".join(", ", map { $_->[1] } @trials).". Skipping...\n";

	next();
    }
    
    if (! $opt_t) { 
	eval { 
	    $stock->hard_delete();
	};
	if ($@) { 
	    print STDERR "Could not delete entry for stock $stock because of: $@\n";
	}
	else {
	    print STDERR "Successfully deleted stock $stock_name\n";
	    $deleted_stock_count++;
	}
    }
}

print STDERR "Done. Total stocks deleted: $deleted_stock_count of $stock_count stocks, and removed $stock_owner_count owner relationships. Stocks not found: $missing_stocks\n";
	
    

