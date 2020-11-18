#!/usr/bin/perl

=head1

delete_cvterms.pl - for deleting cvterms in bulk

=head1 SYNOPSIS

    delete_cvterms.pl -H [dbhost] -D [dbname] -i [infile]

=head1 COMMAND-LINE OPTIONS

  ARGUMENTS
 -H host name (required) e.g. "localhost"
 -D database name (required) e.g. "cxgn_cassava"
 -c cvname
 -i path to infile (required)
 -t test (lists the number of observations associated with each term)

=head1 DESCRIPTION

This script deletes cvterms in bulk. The infile provided has one column containing the cvterm name as it is in the database which should be deleted.

There is no header in the infile and the format is .xls

=head1 AUTHOR

  Lukas Mueller, based on a script by Nick Morales

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

our ($opt_H, $opt_D, $opt_i, $opt_c, $opt_t);

getopts('H:D:i:c:t');

if (!$opt_H || !$opt_D || !$opt_i || !$opt_c) {
    pod2usage(-verbose => 2, -message => "Must provide options -H (hostname), -D (database name), -i (input file), -c CVNAME \n");
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
    my $cv = $schema->resultset('Cv::Cv')->find({ name => $opt_c });
    for my $row ( 0 .. $row_max ) {

    	my $db_cvterm_name = $worksheet->get_cell($row,0)->value();

    	my $cvterm = $schema->resultset('Cv::Cvterm')->find({ name => $db_cvterm_name, cv_id => $cv->cv_id() });

	if (!$cvterm) { print STDERR "Cvterm $db_cvterm_name does not exit. SKIPPING!\n";
			next;
	}
	my $phenotypes = $schema->resultset('Phenotype::Phenotype')->search( { cvalue_id => $cvterm->cvterm_id() });
	if ($opt_t) { 
	    
	    if ($phenotypes->count() > 0) { 
		print STDERR $cvterm->name()."\t".$phenotypes->count()."\n";
	    }
	}
	else {
	    if ($phenotypes->count() > 0) {
		print STDERR "Not deleting term ".$cvterm->name()."  with ".$phenotypes->count()." associated phenotypes.\n";
	    }
	    else { 
		my $dbxref = $schema->resultset('General::Dbxref')->find({ dbxref_id => $cvterm->dbxref_id() });
		
		# check if the dbxref is referenced by other cvterms, only delete
		# if it's only referenced by this one term
		#
		my $dbxref_count_rs = $schema->resultset('Cv::Cvterm')->search( { dbxref_id=> $cvterm->dbxref_id() });
		
		if ($dbxref_count_rs->count() == 1) {
		    $dbxref->delete();
		}
		my $name = $cvterm->name();
		$cvterm->delete();
		print STDERR "Deleted term $name.\n";
	    }

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
