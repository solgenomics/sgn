#!/usr/bin/perl

=head1

update_cvterm_annotations.pl 

=head1 SYNOPSIS

    update_cvterm_annotationss.pl -H [dbhost] -D [dbname] -i [infile]

=head1 COMMAND-LINE OPTIONS
  ARGUMENTS
 -H host name (required) e.g. "localhost"
 -D database name (required) e.g. "sandbox_musabase"
 -i path to infile (required)

=head1 DESCRIPTION

This script updates phenotypes associated with depracated cvterms to the current ones. The infile provided has two columns, in the first column is the cvterm accession as it is in the database, and in the second column is the new cvterm accession (format is db.name:dbxref.accession e.g. PREFIX:NNNNNNN) . There is no header on the infile and the infile is .xls and .xlsx.


=head1 AUTHOR

 Naama Menda (nm249@cornell.edu)

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

our ($opt_H, $opt_D, $opt_i, $opt_t);

getopts('H:D:ti:');

if (!$opt_H || !$opt_D || !$opt_i ) {
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

my $coderef = sub {
    for my $row ( 0 .. $row_max ) {

    	my $db_cvterm = $worksheet->get_cell($row,0)->value();
    	my $file_cvterm = $worksheet->get_cell($row,1)->value();
       
	my ($old_db_name, $old_accession ) = split ":", $db_cvterm ; 
    	my ($new_db_name, $new_accession ) = split ":" , $file_cvterm;



	my $old_cvterm = $schema->resultset('Cv::Cvterm')->find(
	    { 
		'db.name'          => $old_db_name,
		'dbxref.accession' => $old_accession,
	    },
	    { join => { 'dbxref' => 'db'} , } 
	    ) ;
	if ( !defined $old_cvterm ) { 
	    print STDERR "Cannot find cvterm $db_cvterm in the database! skipping\n";
	    next();
	}

	my $new_cvterm = $schema->resultset('Cv::Cvterm')->find(
	    { 
		'db.name'          => $new_db_name,
		'dbxref.accession' => $new_accession,
	    },
	    { join => { 'dbxref' => 'db'} , } 
	    );
	
	my $phenotypes = $schema->resultset('Phenotype::Phenotype')->search(
	    {
		observable_id => $old_cvterm->cvterm_id,
		cvalue_id     => $old_cvterm->cvterm_id,
	    } ) ;

	print STDERR "Updating cvterm $db_cvterm to $file_cvterm\n";

	$phenotypes->update(  { observable_id => $new_cvterm->cvterm_id }  );
	$phenotypes->update( { cvalue_id => $new_cvterm->cvterm_id } );
    }
};

my $transaction_error;
try {
    $schema->txn_do($coderef);
} catch {
    $transaction_error =  $_;
};

if ($transaction_error || $opt_t) {
    $dbh->rollback;
    print STDERR "Transaction error storing terms: $transaction_error\n";
} else {
    print STDERR "Script Complete.\n";
}
