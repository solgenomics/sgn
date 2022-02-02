#!/usr/bin/perl

=head1

check_genotyped_accessions.pl - checks if accessions are genotyped or not using a genotyping protocol.

=head1 SYNOPSIS

perl bin/check_genotyped_accessions.pl -h [dbhost] -d [dbname] -i [infile] -o [outfile] -p [genotyping_protocol]

=head1 REQUIRED ARGUMENTS
 -h host name  e.g. "localhost"
 -d database name e.g. "cxgn_cassava"
 -p genotyping protocol name
 -i path to infile
 -o path to output file 

=head1 DESCRIPTION

This script checks if accessions are genotyped using a given genotyping protocol. The accessions are in a single column, one accessions per line. File should not have a header.

=head1 AUTHOR

 Isaak Y Tecle 

=cut


use strict;
use warnings;

use Bio::Chado::Schema;
use Getopt::Std;
use SGN::Model::Cvterm;
use CXGN::DB::InsertDBH;
use File::Slurp qw /read_file write_file/;
use Data::Dumper;

our ($opt_h, $opt_d, $opt_p, $opt_i, $opt_o);

getopts("h:d:p:i:o:");
my $dbhost = $opt_h;
my $dbname = $opt_d;
my $in_file = $opt_i;
my $out_file = $opt_o;
my $protocol_name = $opt_p;

my $dbh = CXGN::DB::InsertDBH->new( { dbhost=>$dbhost,
				      dbname=>$dbname,
				      dbargs => {AutoCommit => 1,
						 RaiseError => 1,
				      }

				    } );


my $schema= Bio::Chado::Schema->connect( sub { $dbh->get_actual_dbh() });


my $q = "SELECT nd_protocol_id, name 
                FROM nd_protocol
                WHERE name = ?";

my $h = $dbh->prepare($q);
$h->execute($protocol_name);

my $protocol_exists;

while (my ($pr_id, $pr_name) = $h->fetchrow_array()) {
    print STDERR "\nFound genotyping protocol: $pr_name -- id: $pr_id\n";
    $protocol_exists = 1;
}

if (!$protocol_exists) {
    die "\n\nGENOTYPING PROTOCOL $protocol_name does not exist in the database\n\n";
}

print STDERR "Getting genotype names... ";

$q = "SELECT genotype.uniquename, stock.uniquename
    FROM genotype
    JOIN nd_experiment_genotype USING(genotype_id)
    JOIN nd_experiment_stock USING(nd_experiment_id)
    JOIN stock USING(stock_id)
    JOIN nd_experiment USING (nd_experiment_id)
    JOIN nd_experiment_protocol USING(nd_experiment_id)
    JOIN nd_protocol USING (nd_protocol_id)
    WHERE nd_protocol.name = ?";


$h = $dbh->prepare($q);
$h->execute($protocol_name);

my %g2s;
my $cnt = 0;

while (my ($gt, $stock) = $h->fetchrow_array()) {
    if ($stock =~ m/(.*?)\.(.*)/) {
	$stock = $1;
    }
	 
    if (!$g2s{$stock}) {
	$cnt++;
	$g2s{$stock} = uc($gt);
	print STDERR "\n$stock-- $gt\n" if $cnt < 10;
    }
}

my $synonym_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stock_synonym', 'stock_property')->cvterm_id();

my @clones = read_file($in_file);

my $output = "Clone\tUniquename\tMatch_type\tGenotyped\n";

my $genotyped;
my $genotyped_cnt = 0;
my $not_genotyped_cnt = 0;
my $total_clones = @clones;

foreach my $clone (@clones) {

    $clone =~ s/\s+//;

    my $uniquename = "";
    my $match_type = "";
    my $stock_type = "";

    if ($g2s{$clone}) {
	$uniquename = $clone;
	$match_type = "uniquename";
	$genotyped = 'Yes';

	$genotyped_cnt++;
    }
    else {
	print STDERR "\n checking genotyped synonyms for clone: $clone\n";

	my $syn_rs = $schema->resultset("Stock::Stockprop")->search( { value => { ilike => $clone}, 'me.type_id' => $synonym_id }, { join => 'stock' } );
	
	if ($syn_rs->count()) {
	    my $row = $syn_rs->first()->stock();
	    my $uniquename = $row->uniquename();

	    if ($g2s{$uniquename}) {
		$match_type = "synonym";
		$genotyped = 'Yes';
		$genotyped_cnt++;
	    } else {
		$uniquename = $clone;
		$match_type = "not found";
		$genotyped = 'No';
		$not_genotyped_cnt++;
	    }
	}
	else {
	    $uniquename = $clone;
	    $match_type = "not found";
	    $genotyped = 'No';
	    $not_genotyped_cnt++;
	}
    }

    my $out = join("\t", $clone, $uniquename, $match_type, $genotyped);
    $output .= $out . "\n";

}

print STDERR "\nChecked for $total_clones clones: $genotyped_cnt are genotyped, $not_genotyped_cnt are not genotyped with $protocol_name.\n";

print STDERR "\nwriting output to file: $out_file\n";
write_file($out_file, $output);

print STDERR "Done.\n";
