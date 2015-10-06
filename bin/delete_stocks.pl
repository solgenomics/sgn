
# delete_stocks.pl -H [host] -D [dbname] -t (for testing only - no deletion takes place).

use strict;
use Getopt::Std;
use DBI;
use Bio::Chado::Schema;
use CXGN::Phenome::Schema;

our ($opt_H, $opt_D, $opt_t);
getopts('H:D:t');

my $file = shift;

print "Password for $opt_H / $opt_D: \n";
my $pw = <>;
chomp($pw);

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

open(my $F, "<", $file) || die " Can't open file $file\n";

while (<$F>) { 
    chomp;
    
    my $stock = $_;
    $stock =~ s/\r//g;
    if (!$stock) { 
	next();
    }

    $stock_count++;

    print STDERR "Processing $stock\n";

    my $stock_row = $bcs_schema->resultset("Stock::Stock")->find( { uniquename => $stock });
    
    if (!$stock_row) { 
	print STDERR "Could not find stock $stock. Skipping...\n";
	$missing_stocks++;
	next;
    }

    my $owner_rs = $phenome_schema->resultset("StockOwner")->search( { stock_id => $stock_row->stock_id() });
    if ($owner_rs->count() > 1) { 
	print STDERR "Weird. $stock has more than one owner.\n";
    }

    my $subject_relationship_rs = $bcs_schema->resultset("Stock::StockRelationship")->search( { object_id => $stock_row->stock_id() });

    while (my $r = $subject_relationship_rs->next()) { 
	print STDERR "Found object relationship with stock ".$r->subject_id()." of type ".$r->type_id()."\n";
    }
    
    my $object_relationship_rs = $bcs_schema->resultset("Stock::StockRelationship")->search( { subject_id => $stock_row->stock_id() });
    while (my $r = $object_relationship_rs->next()) { 
	print STDERR "Found subject relationship with stock ".$r->object_id()." of type ".$r->type_id()."\n";
    }

    while (my $owner_row = $owner_rs->next()) { 
	
	if (! $opt_t) {
	    eval { 
		print STDERR "Removing stockowner (".$owner_row->stock_id().")...\n";
		$owner_row->delete();
	    };
	    if ($@) { 
		print STDERR "Could not delete owner of stock $stock because of: $@\stock";
	    }
	}
	
	$stock_owner_count++;
    }
    
    if (! $opt_t) { 
	eval { 
	    $stock_row->delete();
	};
	if ($@) { 
	    print STDERR "Could not delete entry for stock $stock because of: $@\n";
	}
	else { 
	    $deleted_stock_count++;
	}
    }
}

print STDERR "Done. Total stocks deleted: $deleted_stock_count of $stock_count stocks, and removed $stock_owner_count owner relationships. Stocks not found: $missing_stocks\n";
	
    

