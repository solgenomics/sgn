#!/usr/bin/perl

=head1

rename_stocks.pl - a script for renaming stocks

=head1 SYNOPSIS

    rename_stocks.pl -H [dbhost] -D [dbname] -i [infile]

=head1 COMMAND-LINE OPTIONS
  ARGUMENTS
 -H host name (required) e.g. "localhost"
 -D database name (required) e.g. "cxgn_cassava"
 -i path to infile (required)

=head1 DESCRIPTION

This script rename stocks in bulk. The infile provided has two columns, in the first column is the stock uniquename as it is in the database, and in the second column is the new stock uniquename. There is no header on the infile and the infile is .xls. The stock.name field is untouched.

=head1 AUTHOR

 Guillaume Bauchet (gjb99@cornell.edu)

 Adapted from a cvterm renaming script by:
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
use Try::Tiny;

our ($opt_H, $opt_D, $opt_i);

getopts('H:D:i:');

if (!$opt_H || !$opt_D || !$opt_i) {
    pod2usage(-verbose => 2, -message => "Must provide options -H (hostname), -D (database name), -i (input file)\n");
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

my $coderef = sub {
    for my $row ( 0 .. $row_max ) {

    	my $db_uniquename = $worksheet->get_cell($row,0)->value();
    	my $new_uniquename = $worksheet->get_cell($row,1)->value();
        
	print STDERR "$db_uniquename -> $new_uniquename\n";

    	my $old_stock = $schema->resultset('Stock::Stock')->find({ uniquename => $db_uniquename });

	if (!$old_stock) { 
	    print STDERR "Warning! Stock with uniquename $db_uniquename was not found in the database.\n";
	    next();
	}
        my $new_stock = $old_stock->update({ uniquename => $new_uniquename});

    }
};

my $transaction_error;
try {
    $schema->txn_do($coderef);
} catch {
    $transaction_error =  $_;
};

if ($transaction_error) {
    print STDERR "Transaction error storing terms: $transaction_error\n";
} else {
    print STDERR "Script Complete.\n";
}
