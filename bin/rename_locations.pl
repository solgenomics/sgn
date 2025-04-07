#!/usr/bin/perl

=head1

rename_locations.pl - renaming locations in a cxgn database

=head1 SYNOPSIS

    rename_locations.pl -H [dbhost] -D [dbname] -i [infile]

=head1 COMMAND-LINE OPTIONS
  ARGUMENTS
 -H host name (required) e.g. "localhost"
 -D database name (required) e.g. "cxgn_cassava"
 -i path to infile (required)

=head1 DESCRIPTION

This script loads locations data into Chado, by adding data to nd_geolocation table. Infile is Excel .xls and .xlsx format.
Header is in this order: 'old_location_name', 'new_location_name'

=head1 AUTHOR

 Lukas Mueller (lam87@cornell.edu)

 Based on a script by Nicolas Morales (nm529@cornell.edu)

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

our ($opt_H, $opt_D, $opt_i);

getopts('H:D:i:');

if (!$opt_H || !$opt_D || !$opt_i) {
    pod2usage(-verbose => 2, -message => "Must provide options -H (hostname), -D (database name), -i (input file) \n");
}

my $dbhost = $opt_H;
my $dbname = $opt_D;

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

 
my $worksheet = ( $excel_obj->worksheets() )[0]; #support only one worksheet
my ( $row_min, $row_max ) = $worksheet->row_range();
my ( $col_min, $col_max ) = $worksheet->col_range();

if ($col_max ne '1' || $worksheet->get_cell(0,0)->value() ne 'old_location_name' || $worksheet->get_cell(0,1)->value() ne 'new_location_name') {
    pod2usage(-verbose => 2, -message => "Headers must be only in this order: old_location_name, new_location_name.\n");
}


try { 
    $schema->txn_do(
	sub {  
	    for my $row ( 1 .. $row_max ) {	
		my $old_name = $worksheet->get_cell($row,0)->value();
		my $new_name = $worksheet->get_cell($row,1)->value();
		my $row = $schema->resultset('NaturalDiversity::NdGeolocation')->find({ description => $old_name });
		if ($row) {
		    $row->description($new_name);
		    $row->update();
		    print STDERR "Updated $old_name to $new_name\n";
		}
		else {
		    print STDERR "Location $old_name was not found. Skipping.\n";
		}
	    }
	});
}

catch { 
    my $error = shift;
    print STDERR "An error occurred ($error). Rolling back.\n";
};

print STDERR "Script Complete.\n";
