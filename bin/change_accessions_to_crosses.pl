#!/usr/bin/perl

=head1

change_accessions_to_crosses.pl - a script for changing stocks with type accession to type cross, linking these crosses to female and male parents, nd_experiments and crossing experiments

=head1 SYNOPSIS

change_accessions_to_crosses.pl -H [dbhost] -D [dbname] -i [infile]

=head1 COMMAND-LINE OPTIONS
  ARGUMENTS
 -H host name (required) e.g. "localhost"
 -D database name (required) e.g. "cxgn_cassava"
 -i path to infile (required)

=head1 DESCRIPTION
Use case: Previously, users were not able to use cross stock type in trials because cross stock type was not allowed. As a result, some of the cross names were uploaded as accession stock type. After an improvement by allowing cross stock type in trials, users would like to change those names with accession stock type to cross stock type.

This script changes stocks with type accession to type cross, then links each cross to parents,a cross type, an nd_experiment and a project.  The infile provided has 5 columns. The first column contains stock uniquenames stored as accession stock type. The second column contains female parent uniquenames. The third column contains male parent uniquenames. The forth column contains cross type info. The fifth column contains crossing experiment names. There is no header on the infile and the infile is .xls and .xlsx.
=head1 AUTHOR

Titima Tantikanjana <tt15@cornell.edu>

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

our ($opt_H, $opt_D, $opt_i);

getopts('H:D:i:');

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
    my $accession_cvterm_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $cross_cvterm_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'cross', 'stock_type')->cvterm_id();
    my $female_parent_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'female_parent', 'stock_relationship')->cvterm_id();
    my $male_parent_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'male_parent', 'stock_relationship')->cvterm_id();
    my $project_location_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project location', 'project_property')->cvterm_id();
    my $cross_experiment_cvterm =  SGN::Model::Cvterm->get_cvterm_row($schema, 'cross_experiment', 'experiment_type');

    for my $row ( 0 .. $row_max ) {

    	my $stock_uniquename = $worksheet->get_cell($row,0)->value();
        $stock_uniquename =~ s/^\s+|\s+$//g;

    	my $female_parent_uniquename = $worksheet->get_cell($row,1)->value();
        $female_parent_uniquename =~ s/^\s+|\s+$//g;

        my $male_parent_uniquename = $worksheet->get_cell($row,2)->value();
        $male_parent_uniquename =~ s/^\s+|\s+$//g;

        my $cross_type = $worksheet->get_cell($row,3)->value();
        $cross_type =~ s/^\s+|\s+$//g;

        my $crossing_experiment_name = $worksheet->get_cell($row,4)->value();
        $crossing_experiment_name =~ s/^\s+|\s+$//g;

    	my $stock_rs = $schema->resultset('Stock::Stock')->find({ uniquename => $stock_uniquename, type_id => $accession_cvterm_id });
        my $female_rs = $schema->resultset('Stock::Stock')->find({ uniquename => $female_parent_uniquename, type_id => $accession_cvterm_id });
        my $male_rs = $schema->resultset('Stock::Stock')->find({ uniquename => $male_parent_uniquename, type_id => $accession_cvterm_id });
        my $crossing_experiment_rs = $schema->resultset("Project::Project")->find( { name => $crossing_experiment_name });

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
        if (!$crossing_experiment_rs) {
    	    print STDERR "Error! Crossing experiment: $crossing_experiment_name was not found in the database.\n";
    	    next();
    	}

        my $crossing_experiment_id = $crossing_experiment_rs->project_id();
        my $geolocation_rs = $schema->resultset("Project::Projectprop")->find({project_id => $crossing_experiment_id, type_id => $project_location_cvterm_id});

        #update stock type
        my $cross_stock_rs = $stock_rs->update({ type_id => $cross_cvterm_id});

         #link cross to female and male parents
        my $stock_female_rs = $schema->resultset("Stock::StockRelationship")->search({ object_id => $cross_stock_rs->stock_id(), type_id => $female_parent_cvterm_id });
        my $previous_female = $stock_female_rs->count();
#        print STDERR "FEMALE COUNT =".Dumper($previous_female)."\n";
        if ($previous_female > 0) {
            print STDERR "Stock: $stock_uniquename already has female parent in the database.\n";
            next();
        } else {
            $cross_stock_rs->find_or_create_related('stock_relationship_objects', {
                type_id => $female_parent_cvterm_id,
                object_id => $cross_stock_rs->stock_id(),
                subject_id => $female_rs->stock_id(),
                value => $cross_type,
            });
        }

        my $stock_male_rs = $schema->resultset("Stock::StockRelationship")->search({ object_id => $cross_stock_rs->stock_id(), type_id => $male_parent_cvterm_id });
        my $previous_male = $stock_male_rs->count();
        if ($previous_male > 0) {
            print STDERR "Stock: $stock_uniquename already has male parent in the database.\n";
            next();
        } else {
            $cross_stock_rs->find_or_create_related('stock_relationship_objects', {
                type_id => $male_parent_cvterm_id,
                object_id => $cross_stock_rs->stock_id(),
                subject_id => $male_rs->stock_id(),
            });
        }

        #create experiment
        my $experiment = $schema->resultset('NaturalDiversity::NdExperiment')->create({
            nd_geolocation_id => $geolocation_rs->value,
            type_id => $cross_experiment_cvterm->cvterm_id(),
        });

        #link cross unique id to the experiment
        $experiment->find_or_create_related('nd_experiment_stocks' , {
              stock_id => $cross_stock_rs->stock_id(),
              type_id  =>  $cross_experiment_cvterm->cvterm_id(),
            });

        #link experiment to the project
        $experiment->find_or_create_related('nd_experiment_projects', {
            project_id => $crossing_experiment_id,
        });
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
