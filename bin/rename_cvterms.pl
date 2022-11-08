#!/usr/bin/perl

=head1

rename_cvterms.pl - for renaming cvterms in bulk

=head1 SYNOPSIS

    rename_cvterms.pl -H [dbhost] -D [dbname] -i [infile]

=head1 COMMAND-LINE OPTIONS
  ARGUMENTS
 -H host name (required) e.g. "localhost"
 -D database name (required) e.g. "cxgn_cassava"
 -i path to infile (required)

=head1 DESCRIPTION

This script rename cvterms in bulk. The infile provided has two columns, in the first column is the cvterm name as it is in the database, and in the second column is the new cvterm name. There is no header on hte infile and the infile is .xls and .xlsx.


=head1 AUTHOR

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

our ($opt_H, $opt_D, $opt_i, $opt_c);

getopts('H:D:i:c:');

if (!$opt_H || !$opt_D || !$opt_i || !$opt_c) {
    pod2usage(-verbose => 2, -message => "Must provide options -H (hostname), -D (database name), -i (input file), -c CVNAME \n");
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
    my $cv = $schema->resultset('Cv::Cv')->find({ name => $opt_c });
    for my $row ( 0 .. $row_max ) {

    	my $db_cvterm_name = $worksheet->get_cell($row,0)->value();
    	my $new_cvterm_name = $worksheet->get_cell($row,1)->value();
        print STDERR $db_cvterm_name."\n";

    	my $old_cvterm = $schema->resultset('Cv::Cvterm')->find({ name => $db_cvterm_name, cv_id => $cv->cv_id() });
        my $new_cvterm = $old_cvterm->update({ name => $new_cvterm_name});

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
