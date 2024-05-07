#!/usr/bin/env perl

=head1

load_trait_props.pl

=head1 SYNOPSIS

    $load_trait_props.pl -H [dbhost] -D [dbname] -I [input file] -o [ontology] -w

=head1 COMMAND-LINE OPTIONS

 -H  host name
 -D  database name
 -w  overwrite
 -t  Test run . Rolling back at the end.
 -o  Ontology name (from db table, e.g. "GO")
 -I  input file, either .xls or .xlsx format

=head2 DESCRIPTION

The input file should have the following column headers:

  trait_name
  trait_format
  trait_default_value
  trait_minimum
  trait_maximum
  trait_categories
  trait_details

  trait_name: the name of the variable human readable form (e.g., "plant height in cm")
  trait_format: can be numeric, qualitative, date or boolean
  trait_default_value: is the value if no value is given
  trait_categories: are the different possible names of the categories, separated by /, for example "1/2/3/4/5"
  trait_details: string describing the trait categories 

=head2 AUTHOR

Jeremy D. Edwards (jde22@cornell.edu)

April 2014

=head2 TODO

Add support for other spreadsheet formats

=cut

use strict;
use warnings;

use lib 'lib';
use Getopt::Std;
use Bio::Chado::Schema;
use Spreadsheet::ParseExcel;
use Spreadsheet::ParseXLSX;
use CXGN::DB::InsertDBH;
use CXGN::DB::Connection;
use CXGN::Fieldbook::TraitProps;


our ($opt_H, $opt_D, $opt_I, $opt_o, $opt_w, $opt_t);
getopts('H:D:I:o:wt');


sub print_help {
    print STDERR "A script to load trait properties\nUsage: load_trait_props.pl -D [database name] -H [database host, e.g., localhost] -I [input file] -o [ontology namespace, e.g., CO] -w\n\t-w\toverwrite existing trait properties if they exist (optional)\n\t-t\ttest run.  roll back at the end\n";
}


if (!$opt_D || !$opt_H || !$opt_I || !$opt_o) {
    print_help();
    die("Exiting: options missing\n");
}

# Match a dot, extension .xls / .xlsx
my ($extension) = $opt_I =~ /(\.[^.]+)$/;
my $parser;

if ($extension eq '.xlsx') {
    $parser = Spreadsheet::ParseXLSX->new();
}
else {
    $parser = Spreadsheet::ParseExcel->new();
}

#try to open the excel file and report any errors
my $excel_obj = $parser->parse($opt_I);

if ( !$excel_obj ) {
    die "Input file error: ".$parser->error()."\n";
}

my $worksheet = ( $excel_obj->worksheets() )[0]; #support only one worksheet
my ( $row_min, $row_max ) = $worksheet->row_range();
my ( $col_min, $col_max ) = $worksheet->col_range();

if (($col_max - $col_min)  < 1 || ($row_max - $row_min) < 1 ) { #must have header and at least one row of phenotypes
    die "Input file error: spreadsheet is missing header\n";
}

my $trait_name_head;

if ($worksheet->get_cell(0,0)) {
    $trait_name_head  = $worksheet->get_cell(0,0)->value();
}

if (!$trait_name_head || $trait_name_head ne 'trait_name') {
    die "Input file error: no \"trait_name\" in header\n";
}

my @trait_property_names = qw(
    trait_format
    trait_default_value
    trait_minimum
    trait_maximum
    trait_categories
    trait_details
    );

#check header for property names
for (my $column_number = 1; $column_number <= scalar @trait_property_names; $column_number++) {
    my $property_name = $trait_property_names[$column_number-1];
    if ( !($worksheet->get_cell(0,$column_number)) || !($worksheet->get_cell(0,$column_number)->value() eq $property_name) ) {
	die "Input file error: no \"$property_name\" in header\n";
    }
}

my @trait_props_data;


for my $row ( 1 .. $row_max ) {
    my %trait_props;
    my $trait_name;
    my $current_row = $row+1;
    
    
    if ($worksheet->get_cell($row,0)) {
	$trait_name = $worksheet->get_cell($row,0)->value();
	$trait_props{'trait_name'}=$trait_name;
    } else {
	next; #skip blank lines
    }
    
    my $prop_column = 1;
    foreach my $property_name (@trait_property_names) {
	if ($worksheet->get_cell($row,$prop_column)) {
	    my $value = $worksheet->get_cell($row,$prop_column)->value();
	    if (defined($value) && ($value ne '')) {
		$trait_props{$property_name}=$worksheet->get_cell($row,$prop_column)->value();
	    }
	}
	$prop_column++;
    }
    
    push @trait_props_data, \%trait_props;
    
}

my $dbh = CXGN::DB::InsertDBH
    ->new({
	dbname => $opt_D,
	dbhost => $opt_H,
	dbargs => {AutoCommit => 1,
		   RaiseError => 1},
	  });

my $overwrite_existing_props = 0;

if ($opt_w){
    $overwrite_existing_props = 1;
}

my $is_test_run = 0;

if ($opt_t){
    $is_test_run = 1;
}

my $chado_schema = Bio::Chado::Schema->connect(  sub { $dbh->get_actual_dbh() } );

my $db_name = $opt_o;

my $trait_props = CXGN::Fieldbook::TraitProps->new({ chado_schema => $chado_schema, db_name => $db_name, trait_names_and_props => \@trait_props_data, overwrite => $overwrite_existing_props, is_test_run => $is_test_run});

print STDERR "Validating data...\t";
my $validate=$trait_props->validate();

if (!$validate) {
    die("input data is not valid\n");
} else {
    print STDERR "input data is valid\n";
}

print STDERR "Storing data...\t\t";
my $store = $trait_props->store();

if (!$store){
    if (!$is_test_run) {
	die("\n\nerror storing data\n");
    }
} else {
    print STDERR "successfully stored data\n";
}



