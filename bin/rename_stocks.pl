#!/usr/bin/perl

=head1 NAME

rename_stocks.pl - a script for renaming stocks

=head1 SYNOPSIS

rename_stocks.pl -H [dbhost] -D [dbname] -i [infile]

=head2 Command-line options

=over 5

=item -H 

host name (required) e.g. "localhost"

=item -D 

database name (required) e.g. "cxgn_cassava"

=item -i 

path to infile (required)

=item -s 

stock type (default: accession)

=item -n 

don't store old name as a synonym

=item -t 

test mode, do not commit changes.

=back

=head1 DESCRIPTION

This script renames stocks in bulk using an xls file as input with two columns: the first column is the stock uniquename as it is in the database, and in the second column is the new stock uniquename. There is no header line. Both stock.name and stock.uniquename fields will be changed to the new name.

The oldname will be stored as a synonym unless option -n is given.

=head1 AUTHORS

Guillaume Bauchet (gjb99@cornell.edu)

Lukas Mueller <lam87@cornell.edu> (added -n option)

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
use SGN::Model::Cvterm;

our ($opt_H, $opt_D, $opt_i, $opt_s, $opt_t, $opt_n);

getopts('H:D:i:s:tn');

if (!$opt_H || !$opt_D || !$opt_i) {
    pod2usage(-verbose => 2, -message => "Must provide options -H (hostname), -D (database name), -i (input file)\n");
}

my $dbhost = $opt_H;
my $dbname = $opt_D;
my $stock_type = $opt_s || "accession";
my $parser   = Spreadsheet::ParseExcel->new();
my $excel_obj = $parser->parse($opt_i);

my $dbh = CXGN::DB::InsertDBH->new({ 
	dbhost=>$dbhost,
	dbname=>$dbname,
	dbargs => {AutoCommit => 0, RaiseError => 1}
});

my $schema= Bio::Chado::Schema->connect(  sub { $dbh->get_actual_dbh() } );
$dbh->do('SET search_path TO public,sgn');

my $synonym_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stock_synonym', 'stock_property')->cvterm_id();


my $worksheet = ( $excel_obj->worksheets() )[0]; #support only one worksheet
my ( $row_min, $row_max ) = $worksheet->row_range();
my ( $col_min, $col_max ) = $worksheet->col_range();

my $stock_type_row = $schema->resultset("Cv::Cvterm")->find( { name => $stock_type });

if (! $stock_type_row) { die "The stock type $stock_type is not in the database."; }

my $stock_type_id = $stock_type_row->cvterm_id();

my $coderef = sub {
    for my $row ( 0 .. $row_max ) {

    	my $db_uniquename = $worksheet->get_cell($row,0)->value();
    	my $new_uniquename = $worksheet->get_cell($row,1)->value();
        
	print STDERR "processing row $row: $db_uniquename -> $new_uniquename\n";

    	my $old_stock = $schema->resultset('Stock::Stock')->find({ name => $db_uniquename, uniquename => $db_uniquename, type_id => $stock_type_id });

	if (!$old_stock) { 
	    print STDERR "Warning! Stock with uniquename $db_uniquename was not found in the database.\n";
	    next();
	}
	
        my $new_stock = $old_stock->update({ name => $new_uniquename, uniquename => $new_uniquename});
	if (! $opt_n) {
	    print STDERR "Storing old name ($db_uniquename) as synonym or stock with id ".$new_stock->stock_id()." and type_id $synonym_id...\n";
	    my $synonym = { value => $db_uniquename,
			    type_id => $synonym_id,
			    stock_id => $new_stock->stock_id(),
	    };

	    print STDERR "find_or_create...\n";
	    $schema->resultset('Stock::Stockprop')->find_or_create($synonym);
	    print STDERR "Done.\n";
	}
    }
};

my $transaction_error;
try {
    eval($coderef->());
} catch {
    $transaction_error =  $_;
};

if ($opt_t) {
    print STDERR "Not storing with test flag (-t). Rolling back.\n";
    $schema->txn_rollback();
}
elsif ($transaction_error) {
    print STDERR "Transaction error storing terms: $transaction_error. Rolling back.\n";
    $schema->txn_rollback();
} else {
    print STDERR "Everything looks good. Committing.\n";
    $schema->txn_commit();
    print STDERR "Script Complete.\n";
}
