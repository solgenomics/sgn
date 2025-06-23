#!/usr/bin/perl

=head1 NAME

update_stock_props.pl - update stock props 

=head1 DESCRIPTION

update_stock_props -H [database host] -D [database name] -s plots update_stock_prop_file.xlsx

Options:

 -H the database host
 -D the database name
 -s stock_type (default plot)
update_stock_prop_file.xlsx: a file with three columns: 
 stock_name
 <stock_attribute> old
 <stock_attribute> new

The script will remove the new and old extension from the stockprop names in the headers, compare if they are the same, and then start replacing the values in the old column with the values in the new column for each stock_name.

=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu.

=cut

use strict;
use warnings;
use Bio::Chado::Schema;
use Getopt::Std;
use SGN::Model::Cvterm;
use CXGN::DB::InsertDBH;
use Spreadsheet::ParseExcel;
use Spreadsheet::ParseXLSX;

our ($opt_H, $opt_D);
getopts("H:D:s");

my $dbhost = $opt_H;
my $dbname = $opt_D;
my $stock_type = $opt_s || 'plot';

my $file = shift;
my @traits;
my @formulas;
my @array_ref;

my $dbh = CXGN::DB::InsertDBH->new(
    {
	dbhost=>"$dbhost",
	dbname=>"$dbname",
	dbargs => {
	    AutoCommit => 1,
	    RaiseError => 1,
	}
    } );

my $schema= Bio::Chado::Schema->connect( sub { $dbh->get_actual_dbh() });

my $formula_cvterm = $schema->resultset("Cv::Cvterm")->create_with({
	name => "formula",
	cv   => "cvterm_property",
});

my $type_id = $formula_cvterm->cvterm_id();

# Match a dot, extension .xls / .xlsx
#
my ($extension) = $file =~ /(\.[^.]+)$/;
my $parser;

if ($extension eq '.xlsx') {
    $parser = Spreadsheet::ParseXLSX->new();
}
else {
    $parser = Spreadsheet::ParseExcel->new();
}

#try to open the excel file and report any errors
my $excel_obj = $parser->parse($file);

if ( !$excel_obj ) {
    die "Input file error: ".$parser->error()."\n";
}

my $worksheet = ( $excel_obj->worksheets() )[0]; #support only one worksheet
my ( $row_min, $row_max ) = $worksheet->row_range();
my ( $col_min, $col_max ) = $worksheet->col_range();

if (($col_max - $col_min)  < 1 || ($row_max - $row_min) < 1 ) { #must have header and at least one row of phenotypes
    die "Input file error: spreadsheet is missing header\n";
}

# read header line
#
my ($stock_name, $cvterm_old, $cvterm_new);

if ($worksheet->get_cell(0,0)) {
    $stock_name  = $worksheet->get_cell(0,0)->value();
}

if ($worksheet->get_cell(0,1)) { 
    $cvterm_old = $worksheet->get_cell(0,1)->value();
    $cvterm_old =~ s/(.*)\_old/$1/g;
    if (! $cvterm_old) { die "cvterm needs to be cvterm with _old extension in old column"; }
}

if ($worksheet->get_cell(0,2)) {
    $cvterm_new = $worksheet->get_cell(0,2)->value();
    $cvterm_new =~ s/(.*)\_new/$1/g;
    if (! $cvterm_new) { die "cvterm needs to be cvterm with _new extension in old column"; }
}

if ($cvterm_new ne $cvterm_old) {
    die "cvterm_new must be the same as cvterm_old without the extension, currently $cvterm_new vs $cvterm_old";
}

print STDERR "Working with stock property $cvterm_new\n";
my $stock_type_row = SGN::Model::Cvterm-get_cvterm_row($schema, $stock_type, 'stock_property');

if (! $stock_type_row) {
    die "Stock type $stock_type does not exist. Please correct.";
}
my $stock_type_id = $stock_type_row->cvterm_id();

my $cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, $cvterm_new, 'stock_property')->cvterm_id();


# read data lines
#
my ($cvterm_new_value, $cvterm_old_value);

for (my $n=1; $n<=$row_max; $n++) {

    if ($worksheet->get_cell($n,0)) {
	$stock_name  = $worksheet->get_cell($n,0)->value();
    }
    if ($worksheet->get_cell($n,1)) { 
	$cvterm_old_value = $worksheet->get_cell($n,1)->value();
    }
    if ($worksheet->get_cell($n,2)) {
	$cvterm_new_value = $worksheet->get_cell($n,2)->value();
    }

    my $stock = $schema->resultset("Stock::Stock")->find( { uniquename => $stock_name, type_id => $stock_type_id } );
    if (!$stock) { die "Stock $stock does not exist. Please fix and try again."; }

    my $current_entry = $schema->resultset("Stock::Stockprop")->find( { value => $cvterm_old_value, stock_id => $stock->stock_id(), type_id => $cvterm_id });

    if (! $current_entry) {
	die "The stock $stock_name does not have a value of $cvterm_old_value of type $cvterm_new. Please fix and try again";
    }

    print STDERR "Updating stockprop ".$current_entry->stockprop_id()." for stock $stock_name with id ".$stock->stock_id()." $cvterm_old_value WITH $cvterm_new_value\n";

    $current_entry->update(
	{
	    value => $cvterm_new_value
	});
}

print STDERR "Done.\n";
