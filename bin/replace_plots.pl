#!/usr/bin/perl

=head1 NAME

replace_plots.pl - a bulk script to replace accessions in field layouts

=head1 SYNOPSIS

rename_stocks.pl -H [dbhost] -D [dbname] -i [infile] <-t>

=head1 COMMAND-LINE OPTIONS

-H host name (required) e.g. "localhost"
-D database name (required) e.g. "cxgn_cassava"
-i path to infile (required)
-t (optional) test - do not modify the database.

=head1 DESCRIPTION

This script replaces accessions in field layouts in bulk. 

The infile provided has three columns:

1) the plot name that needs to be changed. 
2) the stock uniquename as it is in the database that is currently associated
3) the new stock uniquename (needs to be in the database).
4) optional: a new plot name

There is no header on the infile and the infile is .xls and .xlsx.

The script will dissociate the old accession in column 1 and associate the new accession. The plot name will be unchanged.

=head1 AUTHOR

    Lukas Mueller (lam87@cornell.edu)

    Adapted from a cvterm renaming script by:
    Guillaume Bauchet (gjb99@cornell.edu)
    Nicolas Morales (nm529@cornell.edu)

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
use Try::Tiny;
use SGN::Model::Cvterm;

our ($opt_H, $opt_D, $opt_i, $opt_t);

getopts('H:D:i:t');

if (!$opt_H || !$opt_D || !$opt_i) {
    pod2usage(-verbose => 2, -message => "Must provide options -H (hostname), -D (database name), -i (input file)\n");
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

my $coderef = sub {
    for my $row ( 0 .. $row_max ) {

	my $plot_name = $worksheet->get_cell($row, 0)->value();
	my $plot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id();
    my $plot_id = $schema->resultset('Stock::Stock')->find({uniquename=>$plot_name, type_id=>$plot_cvterm_id})->stock_id();

	# my $plot_id = $worksheet->get_cell($row, 1)->value();
    	my $db_uniquename = $worksheet->get_cell($row,1)->value();
    	my $new_uniquename = $worksheet->get_cell($row,2)->value();

	my $new_plotname = "";
	eval { 
	    $new_plotname = $worksheet->get_cell($row, 3)->value();
	};
	
	if ($@) {
	    print STDER "no alternate plot name provided. Keeping old name.\n";
	}
	
	print STDERR "$db_uniquename -> $new_uniquename\n";
	
    	my $old_stock = $schema->resultset('Stock::Stock')->find({ uniquename => $db_uniquename });
	my $new_stock = $schema->resultset('Stock::Stock')->find({ uniquename => $new_uniquename });

	if (!$old_stock) { 
	    print STDERR "Warning! Stock with uniquename $db_uniquename was not found in the database.\n";
	    next();
	}
	if (!$new_stock) { 
	    print STDERR "Warning! Stock with uniquename $new_uniquename was not found in the database.\n";
	    next();
	
	}
	my $q = "select plot.uniquename, accession.uniquename, sr.stock_relationship_id, cvterm.name from stock as plot join stock_relationship as sr on (plot.stock_id=sr.subject_id) join stock as accession on (accession.stock_id=sr.object_id) join cvterm on (sr.type_id=cvterm.cvterm_id) where plot.stock_id=? and accession.uniquename=? and cvterm.name='plot_of'";

        my $h = $dbh->prepare($q);
	$h->execute($plot_id, $db_uniquename);

	my ($plot, $acc, $stock_relationship_id) = $h->fetchrow_array();

	#update stock_relationship row with new object_id...
	my $uq = "UPDATE stock_relationship set object_id=? where stock_relationship_id=?";
	my $uh = $dbh->prepare($uq);
	print STDERR "Changing object_id to ".$new_stock->stock_id()." for relationship $stock_relationship_id\n";
	if ($opt_t) {
	    print STDERR "Not updating because of -t option...\n";
	}
	else { 
	    $uh->execute($new_stock->stock_id, $stock_relationship_id);
	}

	if ($new_plotname) {
	    print STDERR "Renaming plot to $new_plotname...\n";
	    my $pq = "UPDATE stock SET uniquename=?, name=? WHERE stock_id=?";
	    my $ph = $dbh->prepare($pq);
	    $ph->execute($new_plotname, $new_plotname, $plot_id);
	}
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
