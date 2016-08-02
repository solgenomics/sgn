#!/usr/bin/perl

=head1 NAME

load_trait_formula.pl - loads formulas for computing derived traits

=head1 DESCRIPTION

load_trait_formula.pl -H [database host] -D [database name] load_trait_formula_file.txt

Options:

 -H the database host
 -D the database name

load_trait_formula_file.txt: A file with two columns: trait name, trait formula.

If the trait name is found in the database, formula for computing the trait will be added as a cvtermprops.

=head1 AUTHOR

Alex Ogbonna <aco46@cornell.edu>

=cut


use strict;
use warnings;
use Bio::Chado::Schema;
use Getopt::Std;
use CXGN::DB::InsertDBH;
use SGN::Model::Cvterm;

our ($opt_H, $opt_D);
getopts("H:D:");
my $dbhost = $opt_H;
my $dbname = $opt_D;
my $file = shift;
my @traits;
my @formulas;
my @array_ref;

my $dbh = CXGN::DB::InsertDBH->new( { dbhost=>"$dbhost",
				   dbname=>"$dbname",
				   dbargs => {AutoCommit => 1,
					      RaiseError => 1,
				   }

				 } );


my $schema= Bio::Chado::Schema->connect( sub { $dbh->get_actual_dbh() });

my $formula_cvterm = $schema->resultset("Cv::Cvterm")->create_with({
	name => "formula",
	cv   => "cvterm_property",
});

my $type_id = $formula_cvterm->cvterm_id();

open (my $file_fh, "<", $file ) || die ("\nERROR: the file $file could not be found\n" );

my $header = <$file_fh>;
while (my $line = <$file_fh>) {
    chomp $line;

    my ($my_trait,$my_formula) = split("\t", $line);
	push @traits, $my_trait;
	push @formulas, $my_formula;
}

for (my $n=0; $n<scalar(@traits); $n++) {
		print STDERR $traits[$n]."\n";
    my $trait_cvterm = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, $traits[$n]);
    if (!$trait_cvterm) {
	print STDERR "The trait $traits[$n] is not in the database. Skipping...\n";
	next();
    }

    my $cvterm_id = $trait_cvterm->cvterm_id();
    my $new_prop= $trait_cvterm->create_cvtermprops({formula=>$formulas[$n]} , {} );

}
