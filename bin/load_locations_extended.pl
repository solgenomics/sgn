#!/usr/bin/perl

=head1

load_locations_extended.pl - loading locations into cxgn databases.

=head1 SYNOPSIS

    load_locations_extended.pl -H [dbhost] -D [dbname] -i [infile]

=head1 COMMAND-LINE OPTIONS
  ARGUMENTS
 -H host name (required) e.g. "localhost"
 -D database name (required) e.g. "cxgn_cassava"
 -i path to infile (required)

=head1 DESCRIPTION

This script loads locations data into Chado, by adding data to nd_geolocation table, and properties to nd_geolocationprop. Infile is Excel .xls format. 
Header must have in the first 4 columns: 'Name', 'Longitude', 'Latitude', 'Altitude'. 
Header columns from colum 5 and onwards are stored as cvterms that are part of the cv 'geolocation_property'.


=head1 AUTHOR

 Nicolas Morales (nm529@cornell.edu)

=cut

use strict;

use Getopt::Std;
use Data::Dumper;
use Carp qw /croak/ ;
use Pod::Usage;
use Spreadsheet::ParseExcel;
use Bio::Chado::Schema;
use CXGN::DB::InsertDBH;

our ($opt_H, $opt_D, $opt_i);

getopts('H:D:i:');

if (!$opt_H || !$opt_D || !$opt_i) {
    pod2usage(-verbose => 2, -message => "Must provide options -H (hostname), -D (database name), -i (input file) \n");
}

my $dbhost = $opt_H;
my $dbname = $opt_D;
my $parser   = Spreadsheet::ParseExcel->new();
my $excel_obj = $parser->parse($opt_i);

my $dbh = CXGN::DB::InsertDBH->new({ 
	dbhost=>$dbhost,
	dbname=>$dbname,
	dbargs => {AutoCommit => 1, RaiseError => 1}
});

my $schema= Bio::Chado::Schema->connect(  sub { $dbh->get_actual_dbh() } );
$dbh->do('SET search_path TO public,sgn');


my $worksheet = ( $excel_obj->worksheets() )[0]; #support only one worksheet
my ( $row_min, $row_max ) = $worksheet->row_range();
my ( $col_min, $col_max ) = $worksheet->col_range();

for my $row ( 1 .. $row_max ) {

	my $name = $worksheet->get_cell($row,0)->value();
	my $longitude = $worksheet->get_cell($row,1)->value();
	my $latitude = $worksheet->get_cell($row,2)->value();
	my $altitude = $worksheet->get_cell($row,3)->value();

	my $new_row;
	$new_row = $schema->resultset('NaturalDiversity::NdGeolocation')->new({ description => $name });
	if ($longitude) {
	  $new_row->longitude($longitude);
	}
	if ($latitude) {
	  $new_row->latitude($latitude);
	}
	if ($altitude) {
	  $new_row->altitude($altitude);
	}
	$new_row->insert();

	print STDERR "Stored: ".$name." in nd_geolocation.\n";

	for my $col ( 4 .. $col_max ) {

		my $prop_term = $worksheet->get_cell(0, $col)->value();
		my $prop_value = $worksheet->get_cell($row,$col)->value();

		my $prop_cvterm = $schema->resultset("Cv::Cvterm")->create_with({
		    name => $prop_term,
		    cv   => 'geolocation_property',
		});

		my $new_prop = $schema->resultset('NaturalDiversity::NdGeolocationprop')->create({ 
			nd_geolocation_id => $new_row->nd_geolocation_id(), 
			type_id => $prop_cvterm->cvterm_id(),
			value => $prop_value,
		});

		print STDERR "Stored: ".$prop_value." in nd_geolocationprop.\n";
	}

}

print STDERR "Script Complete.\n";
