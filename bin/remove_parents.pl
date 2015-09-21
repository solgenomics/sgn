
use strict;
use Getopt::Std;
use DBI;
use Bio::Chado::Schema;

our ($opt_H, $opt_D);
getopts('H:D:');

my $file = shift;

print "Password for $opt_H / $opt_D: \n";
my $pw = <>;
chomp($pw);

print STDERR "Connecting to database...\n";
my $dsn = 'dbi:Pg:database='.$opt_D.";host=".$opt_H.";port=5432";

my $dbh = DBI->connect($dsn, "postgres", $pw);

print STDERR "Connecting to DBI schema...\n";
my $bcs_schema = Bio::Chado::Schema->connect($dsn, "postgres", $pw);
    
my $female_parent_type_id = $bcs_schema->resultset("Cv::Cvterm")->find( { name => "female_parent" })->cvterm_id();

my $male_parent_type_id = $bcs_schema->resultset("Cv::Cvterm")->find( { name=> "male_parent" })->cvterm_id();

my $total_count = 0;

open(my $F, "<", $file) || die " Can't open file $file\n";
while (<$F>) { 
    chomp;
    
    my $stock = $_;
    $stock =~ s/\r//g;
    if (!$stock) { 
	next();
    }

    print STDERR "Processing $stock\n";

    my $stock_row = $bcs_schema->resultset("Stock::Stock")->find( { uniquename => $stock });
    
    if (!$stock_row) { 
	print STDERR "Could not find stock $stock. Skipping...\n";
	next;
    }


    my $parent_rs = $bcs_schema->resultset("Stock::StockRelationship")->search( { object_id => $stock_row->stock_id(), type_id => { -in => [ $female_parent_type_id, $male_parent_type_id] } });

    print STDERR "Found ".$parent_rs->count()." parents for stock $stock\n";

    while (my $p = $parent_rs->next()) { 
	print STDERR "Removing parent with id ".$p->subject_id()."...\n";
	$p->delete();
	$total_count++;
    }
}

print STDERR "Done. Total relationships deleted: $total_count.\n";
	
    

