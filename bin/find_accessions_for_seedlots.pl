#!/usr/bin/perl

=head1

find_accessions_for_seedlots.pl - give the accession for each seedlot name

=head1 SYNOPSIS

    find_accessions_for_seedlots.pl -H [dbhost] -D [dbname] -i [infile]

=head1 COMMAND-LINE OPTIONS
  ARGUMENTS
 -H host name (required) e.g. "localhost"
 -D database name (required) e.g. "cxgn_cassava"
 -i path to infile (required)

=head1 DESCRIPTION



=head1 AUTHOR

   Lukas Mueller <lam87@cornell.edu>, based on a script by Nick Morales

=cut

use strict;

use Getopt::Std;
use Data::Dumper;
use Carp qw /croak/ ;
use Pod::Usage;
use Spreadsheet::ParseExcel;
use Spreadsheet::ParseXLSX;
use Bio::Chado::Schema;
use CXGN::DB::InsertDBH;
use SGN::Model::Cvterm;
use CXGN::Stock;
use CXGN::Stock::Seedlot;

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

print STDERR "Figuring out file format... ($extension)...\n";
if ($extension eq '.xlsx') {
	$parser = Spreadsheet::ParseXLSX->new();
}
else {
	$parser = Spreadsheet::ParseExcel->new();
}

#print STDERR "Parsing file... (please wait...)\n";

#my $excel_obj = $parser->parse($opt_i);

print STDERR "Connecting to database $dbname on $dbhost ...\n";

my $dbh = CXGN::DB::InsertDBH->new({ 
	dbhost=>$dbhost,
	dbname=>$dbname,
	dbargs => {AutoCommit => 1, RaiseError => 1}
});

my $schema= Bio::Chado::Schema->connect(  sub { $dbh->get_actual_dbh() } );
$dbh->do('SET search_path TO public,sgn');


print STDERR "Parsing file...\n";

#my $worksheet = ( $excel_obj->worksheets() )[0]; #support only one worksheet
#my ( $row_min, $row_max ) = $worksheet->row_range();
#my ( $col_min, $col_max ) = $worksheet->col_range();

my $seedlot_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'seedlot', 'stock_type')->cvterm_id();
my $stock_type_id   = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();

print STDERR "Seedlot type id = $seedlot_type_id\n";

open(my $F, "<", $opt_i) || die "Can't open file $opt_i";


while (<$F>) {
    
    chomp($_);
    
    my ($empty, $seedlot, @row) = split /\t/, $_;
    
    print STDERR "Reading row '$empty', $seedlot, and the rest is: ". join(",", @row)."\n";
    
    my $seedlot_row = $schema->resultset("Stock::Stock")->find( { uniquename => $seedlot, type_id=> $seedlot_type_id });

    my $name = "";
    my $type = "";
    
    if (! defined($seedlot_row)) {
	$name = "[SEEDLOT NOT IN DB]";
	print STDERR "ROW === ".Dumper($seedlot_row);
    }
    else {

	print STDERR "FOUND SEEDLOT!\n";

	my $seedlot = CXGN::Stock::Seedlot->new(  schema => $schema, seedlot_id => $seedlot_row->stock_id() );

	if (my $accession = $seedlot->accession()) {
	    $name = $accession->[1];
	    $type = "accession";
	}
	elsif (my $cross = $seedlot->cross()) {
	    $name = $cross->[1];
	    $type = "cross";
	}

    }
    print join("\t", $name, $seedlot, @row)."\n";
}

close($F);
print STDERR "Script Complete.\n";
