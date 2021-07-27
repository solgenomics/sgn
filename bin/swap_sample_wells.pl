
=head1 NAME

swap_sample_wells.pl - a script to swap samples in genotyping plates

=head1 DESCRIPTION

perl swap_sample_wells.pl -h host -D database [-t] -f file -p PW

The file should have the following columns, tab delimited, no header:

sample_stock_uniquename   old_well   new_well

Example:

iita-mas-ng-me-0011_G11 G11     H12
...

The script will try to change the well location in the uniquename as well as the properties col_number, row_number, and plot_number (which contains the well location, such as H12)

=head1 AUTHORS

Lukas Mueller and Guillaume Bauchet

=cut



use strict;

use Getopt::Std;
use DBI;
use Bio::Chado::Schema;
use SGN::Model::Cvterm;

our ($opt_H, $opt_D, $opt_p, $opt_f, $opt_t);
getopts('H:D:p:f:t');

my $pw = $opt_p;
chomp($pw);

print STDERR "Connecting to database...\n";
my $dsn = 'dbi:Pg:database='.$opt_D.";host=".$opt_H.";port=5432";

my $dbh = DBI->connect($dsn, "postgres", $pw);

print STDERR "Connecting to DBI schema...\n";
my $schema = Bio::Chado::Schema->connect($dsn, "postgres", $pw);


my $file = $opt_f;

open(my $F, "<", $file) || die "Can't open file $file.\n";

my $guard = $schema->txn_scope_guard();

my $col_number = SGN::Model::Cvterm->get_cvterm_row($schema, 'col_number', 'stock_property')->cvterm_id();
my $row_number = SGN::Model::Cvterm->get_cvterm_row($schema, 'row_number', 'stock_property')->cvterm_id();
my $plot_number = SGN::Model::Cvterm-> get_cvterm_row($schema,'plot number', 'stock_property')->cvterm_id();
my $tissue_sample = SGN::Model::Cvterm->get_cvterm_row($schema, 'tissue_sample', 'stock_type')->cvterm_id();

while (<$F>) {
    chomp;
    my($sample_stock_id, $old_well, $new_well) = split /\t/;

    print STDERR "Working on sample '$sample_stock_id'...\n";
    
    my $old_row = $old_well;
    $old_row =~ s/(\w).*/$1/;

    my $old_col = $old_well;
    $old_col =~ s/.*(\d+)/$1/;

    my $new_row = $new_well;
    $new_row =~ s/(\w).*/$1/;

    my $new_col = $new_well;
    $new_col =~ s/.*(\d+)/$1/;

    my $rs = $schema->resultset("Stock::Stock")->search( { uniquename => $sample_stock_id });

    if ($rs->count() < 1) {
	print STDERR "Sample $sample_stock_id does not exist! Skipping...\n";
	next();
    }
    elsif ($rs->count() > 1) {
	print STDERR "Warning! Several samples named $sample_stock_id exist in the database!\n";
    }

    my $row = $rs->next();
    my $uniquename = $row->uniquename();
    my $old_uniquename = $uniquename;
    my $stock_id = $row->stock_id();
    
    print STDERR "Fixing stock name...\n";
    
    print STDERR "Old uniquename: $uniquename\n";
    $uniquename =~ s/$old_well/\_N\_$new_well/;


    print STDERR "New uniquename: $uniquename\n";
    $row->update( { uniquename => $uniquename, name => $uniquename });


    print STDERR "Fixing col location...\n";

    $rs = $schema->resultset("Stock::Stockprop")->search( { stock_id => $stock_id, type_id => $col_number, value => $old_col });

    if ($rs->count() > 1) {
	print STDERR "More than one col number associated with sample $old_uniquename\n";
    }
    elsif ($rs->count() < 1) {
	print STDERR  "No col number $old_col associated with sample $old_uniquename\n";
    }
    else { 
	$row = $rs->next();
	
	$row->update( { value => $new_col });
    }
    
    print STDERR "Fixing row number...\n";
     $rs = $schema->resultset("Stock::Stockprop")->search( { stock_id => $stock_id, type_id => $row_number, value => $old_row });

    if ($rs->count() > 1) {
	print STDERR "More than one row number associated with sample $old_uniquename\n";
    }
    elsif ($rs->count() < 1) {
	print STDERR  "No row number $old_row associated with sample $old_uniquename\n";
    }

    else { 
	$row = $rs->next();
	
	$row->update( { value => $new_row});
    }
    print STDERR "Fixing well number...\n";
    
    $rs = $schema->resultset("Stock::Stockprop")->search( { stock_id => $stock_id, type_id => $plot_number, value => $old_well });
    
	
    if ($rs->count() > 1) {
	die "More than one well number associated with sample $old_uniquename\n";
    }
    elsif ($rs->count() < 1) {
	die "No well number $old_well associated with sample $old_uniquename\n";
    }

    $row = $rs->next();

    $row->update( { value => $new_well });

    print STDERR "Moved sample $old_uniquename ($old_well, $old_row, $old_col) to new location $uniquename ($new_well, $new_row, $new_col).\n\n";
}

print STDERR "Committing changes... ";

if (!$opt_t ) { $guard->commit();}
else { $guard->rollback(); }

print STDERR "Done!\n";
    
    
    
    
    
