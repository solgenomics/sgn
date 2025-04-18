#!/usr/bin/perl

=head1 NAME

update_stock_props.pl - updates stock props 

=head1 DESCRIPTION

update_accession_species.pl -H [database host] -D [database name] -i update_file.xlsx

Options:

 -H the database host
 -D the database name
 -i update_file.xlsx

update_stock_prop_file.xlsx: a file with two columns: 
 accession_name
 species_name

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


our ($opt_H, $opt_D, $opt_i);
getopts("H:D:i:");
my $dbhost = $opt_H;
my $dbname = $opt_D;
my $file = $opt_i;
my @traits;
my @formulas;
my @array_ref;

my $dbh = CXGN::DB::InsertDBH->new( { dbhost=>"$dbhost",
				   dbname=>"$dbname",
				   dbargs => {AutoCommit => 1,
					      RaiseError => 1,
				   }
				 } );

$dbh->do('set search_path to public');

my $schema= Bio::Chado::Schema->connect( sub { $dbh->get_actual_dbh() });

#my $formula_cvterm = $schema->resultset("Cv::Cvterm")->create_with({
#	name => "formula",
#	cv   => "cvterm_property",
#});

#my $type_id = $formula_cvterm->cvterm_id();


# Match a dot, extension .xls / .xlsx
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
my ($accession_header, $species_header);

if ($worksheet->get_cell(0,0)) {
    $accession_header  = $worksheet->get_cell(0,0)->value();
    if ($accession_header ne 'accession_name') { die "accession header not found"; }
}
if ($worksheet->get_cell(0,1)) { 
    $species_header = $worksheet->get_cell(0,1)->value();
    if ($species_header ne 'species_name') { die "species header not found" };
}
#if ($worksheet->get_cell(0,2)) {
#    $cvterm_new = $worksheet->get_cell(0,2)->value();
#    $cvterm_new =~ s/(.*)\_new/$1/g;
#    if (! $cvterm_new) { die "cvterm needs to be cvterm with _new extension in old column"; }
#}

#if ($cvterm_new ne $cvterm_old) {
 #   die "cvterm_new must be the same as cvterm_old without the extension, currently $cvterm_new vs $cvterm_old";
#}

#print STDERR "Working with stock property $cvterm_new\n";
#my $cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, $cvterm_new, 'stock_property')->cvterm_id();

# read data lines
#
#my ($cvterm_new_value, $cvterm_old_value);
my ($accession_name, $species);
for (my $n=1; $n<$row_max; $n++) {

    if ($worksheet->get_cell($n,0)) {
	$accession_name  = $worksheet->get_cell($n,0)->value();
    }
    if ($worksheet->get_cell($n,1)) { 
	$species = $worksheet->get_cell($n,1)->value();
    }
#    if ($worksheet->get_cell($n,2)) {
#	$cvterm_new_value = $worksheet->get_cell($n,2)->value();
#    }

    my $accession_row = $schema->resultset("Stock::Stock")->find( { uniquename => $accession_name } );
    if (!$accession_row) { die "Accession $accession_name does not exist. Please fix and try again."; }
    
    my $organism_row = $schema->resultset("Organism::Organism")->find( { species => $species });

    if (! $organism_row) {
	die "The organism $species does not exit in the database"; 
    }

    my $current_organism_id = $accession_row->organism_id();

    print STDERR "Accession: ".$accession_row->uniquename().". Current organism_id: $current_organism_id. New organism: ".$organism_row->organism_id()." ($species)\n"; 
    
    $accession_row->organism_id($organism_row->organism_id());
    $accession_row->update();
}


print STDERR "Done.\n";
