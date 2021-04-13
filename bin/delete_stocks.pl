
=head1 NAME

delete_stocks.pl - delete stocks from a cxgn database

=head1 DESCRIPTION

perl delete_stocks.pl -H [host] -D [dbname] -t (for testing) file

where the file contains a list of uniquenames specifying the stocks to be deleted, one per line.

If the -t flag is provided, the changes will be rolled back in the database.

Note that it may be possible that some stocks have additional connections, such as images, that this script does not delete yet, and so won't be able to delete those stocks.

=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>

=cut

use strict;
use Getopt::Std;
use DBI;
use Bio::Chado::Schema;
use SGN::Model::Cvterm;
use CXGN::Phenome::Schema;

our ($opt_H, $opt_D, $opt_s, $opt_t);
getopts('H:D:ts:');

my $file = shift;

print "Password for $opt_H / $opt_D: \n";
my $pw = <>;
chomp($pw);

my $stock_type = $opt_s || 'accession';
print STDERR "Working with stock_type $stock_type\n";


print STDERR "Connecting to database...\n";
my $dsn = 'dbi:Pg:database='.$opt_D.";host=".$opt_H.";port=5432";

my $dbh = DBI->connect($dsn, "postgres", $pw);

print STDERR "Connecting to DBI schema...\n";
my $bcs_schema = Bio::Chado::Schema->connect($dsn, "postgres", $pw);
my $phenome_schema = CXGN::Phenome::Schema->connect($dsn, "postgres", $pw,  { on_connect_do => ['set search_path to public,phenome;'] });

my $stock_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, $stock_type, 'stock_type')->cvterm_id();
    
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

    my $stock_row = $bcs_schema->resultset("Stock::Stock")->find( { uniquename => $stock , type_id => $stock_type_id });
    
    if (!$stock_row) { 
	print STDERR "Could not find stock $stock of type $stock_type. Skipping...\n";
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
	
    

