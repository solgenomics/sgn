#!/usr/bin/perl

=head1 NAME

replace_stockprop_values.pl - a bulk script to replace phenotypic values in the database

=head1 SYNOPSIS

replace_stockprop_values.pl -H [dbhost] -D [dbname] -i [infile] <-t>

=head1 COMMAND-LINE OPTIONS

-H host name (required) e.g. "localhost"
-D database name (required) e.g. "cxgn_cassava"
-i path to infile (required)
-s stock type (default plot)
-t (optional) test - do not modify the database.

=head1 DESCRIPTION

This script replaces stockprops in bulk. 

The infile is an Excel file with three columns:

1) the plot_name of the measurement to be replaced
2) in the header, "<stockpropname> old" with the old stockprops in the column
3) the new value, in the header "<stockpropname> new" with the new stockprops
   in the rest of the column

=head1 AUTHORS

 Lukas Mueller (lam87@cornell.edu)

 Adapted from a stock re-assigning script, which is based on other
 scripts, originally by:
 Guillaume Bauchet (gjb99@cornell.edu)
 Nicolas Morales (nm529@cornell.edu)

=cut

use strict;

use Try::Tiny;
use Getopt::Std;
use Data::Dumper;
use Carp qw /croak/ ;
use Pod::Usage;
use Spreadsheet::ParseExcel;
use Spreadsheet::ParseXLSX;
use Bio::Chado::Schema;
use CXGN::DB::InsertDBH;
use SGN::Model::Cvterm;

our ($opt_H, $opt_D, $opt_i, $opt_t, $opt_s);

getopts('H:D:i:ts:');

if (!$opt_H || !$opt_D || !$opt_i) {
    pod2usage(-verbose => 2, -message => "Must provide options -H (hostname), -D (database name), -i (input file)\n");
}

my $dbhost = $opt_H;
my $dbname = $opt_D;
my $stock_type = $opt_s || 'plot';

# Match a dot, extension .xls / .xlsx
my ($extension) = $opt_i =~ /(\.[^.]+)$/;
my $parser;

if ($extension eq '.xlsx') {
	$parser = Spreadsheet::ParseXLSX->new();
}
else {
	$parser = Spreadsheet::ParseExcel->new();
}

my $excel_obj = $parser->parse($opt_i);

my $dbh = CXGN::DB::InsertDBH->new({ 
	dbhost=>$dbhost,
	dbname=>$dbname,
	dbargs => {AutoCommit => 1, RaiseError => 1}
});

my $schema= Bio::Chado::Schema->connect(  sub { $dbh->get_actual_dbh() } );
$dbh->do('SET search_path TO public,sgn');

my $stock_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, $stock_type, "stock_type")->cvterm_id();
print STDERR "Retrieved plot cvterm id of $stock_cvterm_id\n";

my $worksheet = ( $excel_obj->worksheets() )[0]; #support only one worksheet

my $stockprop_name_old = $worksheet->get_cell(0, 1)->value();
my $stockprop_name_new = $worksheet->get_cell(0, 2)->value();


$stockprop_name_old =~ s/ old//g;

$stockprop_name_new =~ s/ new//g;

if ($stockprop_name_old ne $stockprop_name_new) {
    die "The old and new stockprop names don't match. Please correct this and try again.";
}

print STDERR "Working with stockprop called $stockprop_name_new ...\n";
my $stockprop_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, $stockprop_name_new, "stock_property");

if (! $stockprop_cvterm) {
    die "The cvterm $stockprop_name_new does not exist as a stockprop in this database. Please use another stock property";
}

my $stockprop_cvterm_id = $stockprop_cvterm->cvterm_id();

my ( $row_min, $row_max ) = $worksheet->row_range();
my ( $col_min, $col_max ) = $worksheet->col_range();

my $coderef = sub {

    print STDERR "Parsing file ...\n";
    for my $row ( 1 .. $row_max ) {

	my $plot_name = $worksheet->get_cell($row, 0)->value();
	my $old_values = $worksheet->get_cell($row, 1)->value();
    	my $new_values = $worksheet->get_cell($row,2)->value();

    	my $plot_row = $schema->resultset('Stock::Stock')->find({ uniquename => $plot_name, type_id => $stock_cvterm_id });

	if (! $plot_row) { 
	    print STDERR "Warning! Plot with uniquename $plot_name was not found in the database.\n";
	    next();
	}
	else {
	    print STDERR "FOUND PLOT $plot_name... OLD VALUES: $old_values. NEW VALUES: $new_values\n";
	}
	
	my @old_notes = split /\t/, $old_values;
	my @new_notes = split /\t/, $new_values;

	print STDERR "OLD NOTES: ".Dumper(\@old_notes);
	
	for (my $i =0; $i < @old_notes; $i++) {


	    my $old_value = $old_notes[$i];

	    print STDERR "Working with note $old_value\n";
	    
	    my $q = "select stockprop.stockprop_id, stockprop.value from stock join stockprop using(stock_id) where stock.uniquename=? and stockprop.type_id=? and value=?";
	    
	    my $h = $dbh->prepare($q);
	    $h->execute($plot_name, $stockprop_cvterm_id, $old_value);

	    my @rows = ();
	
	    while (my ($phenotype_id, $db_value) = $h->fetchrow_array()) { 
		push @rows, [ $phenotype_id, $db_value ];
	    }

	    my $found_old_value = 0;
	    my $stockprop_id;
	    
	    foreach my $r (@rows) {
		if ($r->[1] eq $old_value) {
		    $stockprop_id = $r->[0];
		    $found_old_value =1;
		}
	    }
	    
	    if ($found_old_value) {
		print STDERR "FOUND OLD VALUE $old_value.\n";
	    }
	    else {
		print STDERR "DID NOT FIND OLD VALUE $old_value IN DATABASE.\n";
	    }
	    
	    if ( (@rows > 1) && (!$found_old_value) ) {
		print STDERR "MULTIPLE NOTES ARE ASSOCIATED WITH PLOT $plot_name AND TRAIT VARIABLE $stockprop_name_new\n";
		
	    }

	    #update stock_relationship row with new object_id...
	    my $uq = "UPDATE stockprop set value=? where stockprop_id=?";
	    
	    my $uh = $dbh->prepare($uq);
	    
	    if ($found_old_value)  {
		print STDERR "UPDATING WITH VALUE $new_notes[$i]\n";
		$uh->execute($new_notes[$i], $stockprop_id);
	    }
	    else {
		print STDERR "NOT UPDATING, AS OLD VALUE NOT FOUND.\n";
	    }
	}
    }
};


my $transaction_error;
try {
    if ($opt_t) {  die "opt t : not saving!\n";}
    $schema->txn_do($coderef);
} catch {
    $transaction_error =  $_;
};

if ($transaction_error) {
    print STDERR "Transaction error storing terms: $transaction_error\n";
} else {
    print STDERR "Script Complete.\n";
}
