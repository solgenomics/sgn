#!/usr/bin/perl

=head1

change_accessions_to_crosses.pl - a script for changing stocks with type accession to type cross and adding parents

=head1 SYNOPSIS

change_accessions_to_crosses.pl -H [dbhost] -D [dbname] -i [infile]

=head1 COMMAND-LINE OPTIONS
  ARGUMENTS
 -H host name (required) e.g. "localhost"
 -D database name (required) e.g. "cxgn_cassava"
 -i path to infile (required)

=head1 DESCRIPTION

This script changes stocks with type accession to type cross and adds parents, cross type. The infile provided has 4 columns. The first column contains stock uniquenames stored as accessions. The second column contains female parent info and the third column contains male parent info. The forth column contains cross type info. There is no header on the infile and the infile is .xls.
=head1 AUTHOR

Titima Tantikanjana <tt15@cornell.edu>

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
    my $accession_cvterm_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $cross_cvterm_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'cross', 'stock_type')->cvterm_id();
    my $female_parent_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'female_parent', 'stock_relationship')->cvterm_id();
    my $male_parent_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'male_parent', 'stock_relationship')->cvterm_id();
    my $cross_experiment_cvterm_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'cross_experiment', 'experiment_type')->cvterm_id();

    my $crossing_experiment_name = $worksheet->get_cell(0,0)->value();
    $crossing_experiment_name =~ s/^\s+|\s+$//g;

    my $crossing_experiment_rs = $schema->resultset("Project::Project")->find( { name => $crossing_experiment_name });
    if (!$crossing_experiment_rs) {
	    print STDERR "Error! Crossing experiment: $crossing_experiment_name was not found in the database.\n";
	    exit;
	}
    my $crossing_experiment_id = $crossing_experiment_rs->project_id();

    for my $row ( 1 .. $row_max ) {

    	my $stock_uniquename = $worksheet->get_cell($row,0)->value();
        $stock_uniquename =~ s/^\s+|\s+$//g;
    	my $female_parent_uniquename = $worksheet->get_cell($row,1)->value();
        $female_parent_uniquename =~ s/^\s+|\s+$//g;
        my $male_parent_uniquename = $worksheet->get_cell($row,2)->value();
        $male_parent_uniquename =~ s/^\s+|\s+$//g;
        my $cross_type = $worksheet->get_cell($row,3)->value();
        $cross_type =~ s/^\s+|\s+$//g;


    	my $stock_rs = $schema->resultset('Stock::Stock')->find({ uniquename => $stock_uniquename, type_id => $accession_cvterm_id });
        my $female_rs = $schema->resultset('Stock::Stock')->find({ uniquename => $female_parent_uniquename, type_id => $accession_cvterm_id });
        my $male_rs = $schema->resultset('Stock::Stock')->find({ uniquename => $male_parent_uniquename, type_id => $accession_cvterm_id });

        if (!$stock_rs) {
            print STDERR "Error! Stock with uniquename $stock_uniquename was not found in the database.\n";
            next();
        }
        if (!$female_rs) {
            print STDERR "Error! Female parent with uniquename $female_parent_uniquename was not found in the database.\n";
            next();
        }
        if (!$male_rs) {
            print STDERR "Error! Male parent with uniquename $male_parent_uniquename was not found in the database.\n";
            next();
        }

        my $cross_stock_rs = $stock_rs->update({ type_id => $cross_cvterm_id});





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
