
use strict;

use Getopt::Std;
use DBI;
use Bio::Chado::Schema;
use SGN::Model::Cvterm;

our ($opt_H, $opt_D);
getopts('H:D:');

print "Password for $opt_H / $opt_D: \n";
my $pw = <>;
chomp($pw);

print STDERR "Connecting to database...\n";
my $dsn = 'dbi:Pg:database='.$opt_D.";host=".$opt_H.";port=5432";

my $dbh = DBI->connect($dsn, "postgres", $pw);

print STDERR "Connecting to DBI schema...\n";
my $bcs_schema = Bio::Chado::Schema->connect($dsn, "postgres", $pw);


my $file = shift;

open(my $F, "<", $file) || die "Can't open file $file.\n";

my $col_number = SGN::Model::Cvterm->get_cvterm_row('col_number')->cvterm_id();
my $row_number = SGN::Model::Cvterm->get_cvterm_row('row_number')->cvterm_id();
my $plot_number = SGN::Model::Cvterm-> get_cvterm_row('plot number')->cvterm_id();
my $tissue_sample = SGN::Model::Cvterm->get_cvterm_row('tissue_sample')->cvterm_id();

while (<$F>) {
    chomp;
    my($sample_stock_id, $old_well, $new_well) = split /\t/;

    print STDERR "Working on sample $sample_stock_id...\n";
    
    my $old_row = $old_well;
    $old_row =~ /(\w).*/$1/;

    my $old_col = $old_well;
    $old_col =~ /*.(\d)/$1/;

    my $new_row = $new_well;
    $new_row =~ /(\w).*/$1/;

    my $new_col = $new_well;
    $new_col =~ /.*(\d)/$1/;

    my $rs = $schema->resultset("Stock::Stock")->search( { uniquename => $sample_stock_id });

    if ($rs->count() != 1) {
	print STDERR "Sample $sampel_stock_id does not exist! Skipping...\n";
	next();
    }

    my $row = $rs->next();
    my $uniquename = $row->uniquename();
    my $old_uniquename = $uniquename;
    my $stock_id = $row->stock_id();
    
    print STDERR "Fixing stock name...\n";
    
    print STDERR "Old uniquename: $uniquename\n";
    $uniquename =~ s/$old_well/$new_well/;

    print STDERR "New uniquename: $uniquename\n";
    $row->update( { uniquename => $uniquename, name => $uniquename });


    print STDERR "Fixing well location...\n";

    $rs = $schema->resultset("Stock::Stockprop")->search( { stock_id => $stock_id, type_id => $col_number, value => $old_col });

    if ($rs->count() > 1) {
	die "More than one col number associated with sample $uniquename\n";
    }
    elsif ($rs->count() < 1) {
	die "No col number $old_col associated with sample $uniquename\n";
    }

    $row = $rs->next();

    $row->update( { value => $new_col});


    print STDERR "Fixing row number...\n";
     $rs = $schema->resultset("Stock::Stockprop")->search( { stock_id => $stock_id, type_id => $row_number, value => $old_row });

    if ($rs->count() > 1) {
	die "More than one row number associated with sample $uniquename\n";
    }
    elsif ($rs->count() < 1) {
	die "No row number $old_row associated with sample $uniquename\n";
    }

    $row = $rs->next();

    $row->update( { value => $new_row});

    print STDERR "Fixing well number...\n";
	
    $rs = $schema->resultset("Stock::Stockprop")->search( { stock_id => $stock_id, type_id => $well_number, value => $old_well });
    
    if ($rs->count() > 1) {
	die "More than one well number associated with sample $uniquename\n";
    }
    elsif ($rs->count() < 1) {
	die "No well number $old_well associated with sample $uniquename\n";
    }

    $row = $rs->next();

    $row->update( { value => $new_well });

    print STDERR "Moved sample $old_uniquename to new location $uniquename.\n\n";
}
    

    
    
    
    
    
