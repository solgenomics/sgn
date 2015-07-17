#!/usr/bin/perl

=head1

remove_accessions.pl - removes accessions from cxgn databases that were loaded with the load_genotypes script, based on accession names or obvious error (colon) in accession names.

=head1 SYNOPSIS

    remove_accessions.pl -H [dbhost] -D [dbname] -i [file with accession names] [-t]

=head1 COMMAND-LINE OPTIONS
 
 -H host name
 -D database name
 -i file with accession names
 -t Test run. Rolls back at the end.

=head1 DESCRIPTION

This script removes data loaded in error. It identifies rows to be deleted in the genotype and stock tables of the Chado schema, linked by the nd_experiment table. Then, working backwards, it deletes from all three tables using the relevant ids. 

=head1 AUTHOR

Bryan Ellerbrock (bje24@cornell.edu) - July 2015, with large parts lifted from Naama's load_genotypes.pl script and a lot of help.

=cut

use strict;
use warnings;

use Getopt::Std;
use Try::Tiny;
use CXGN::DB::InsertDBH;

our ($opt_H, $opt_D, $opt_i, $opt_t);

getopts('H:i:D:t');

my $dbhost = $opt_H;
my $dbname = $opt_D;
my $file = $opt_i;
my $dbh;
my %seq;

# store database handle and schema

$dbh = CXGN::DB::InsertDBH->new( { dbhost=>$dbhost,
				      dbname=>$dbname,
				      dbargs => {AutoCommit => 0,
						 RaiseError => 1}
				    }
    );

# prepare sql delete statements

my $s_query = "Delete from stock where stock_id = ?;";
my $n_query = "Delete from nd_experiment where nd_experiment_id = ?;";
my $g_query = "Delete from genotype where genotype_id = ?;";
my $g=$dbh->prepare($g_query);
my $n=$dbh->prepare($n_query);
my $s=$dbh->prepare($s_query);

try {

    if ($opt_i) {
	
        # identify accessions to be removed from names supplied in a file                                                                                                                                   
	
	open (FILE, "<", $opt_i) || die "Can't open infile $opt_i \n";
	
	my $l_query = "select stock.stock_id, nd_experiment.nd_experiment_id, genotype.genotype_id from stock left join nd_experiment_stock on (stock.stock_id = nd_experiment_stock.stock_id) left join nd_experiment on (nd_experiment_stock.nd_experiment_id = nd_experiment.nd_experiment_id) left join nd_experiment_genotype on (nd_experiment.nd_experiment_id = nd_experiment_genotype.nd_experiment_id) left join genotype on (nd_experiment_genotype.genotype_id = genotype.genotype_id) left join genotypeprop on (genotype.genotype_id = genotypeprop.genotype_id) where stock.name = ?;";
	
	my $l=$dbh->prepare($l_query);
	
	while (<FILE>) {
	    chomp (my $accession = $_ );
	    $l->execute($accession);
	    
	    &loopdelete($l);


	}
	
    } else {
	
        # if no infile, identify accessions to be removed by confirming that stock_id is for an accession and the accession has a colon in the stock name                                                   

	my $q = "select stock.stock_id, nd_experiment.nd_experiment_id, genotype.genotype_id from stock left join nd_experiment_stock on (stock.stock_id = nd_experiment_stock.stock_id) left join nd_experiment on (nd_experiment_stock.nd_experiment_id = nd_experiment.nd_experiment_id) left join nd_experiment_genotype on (nd_experiment.nd_experiment_id = nd_experiment_genotype.nd_experiment_id) left join genotype on (nd_experiment_genotype.genotype_id = genotype.genotype_id) left join genotypeprop on (genotype.genotype_id = genotypeprop.genotype_id) where stock.name like '%:%' and stock.type_id = 76392;";

	my $h=$dbh->prepare($q);

	$h->execute();
	
        # then loop through rows of table containing info of accessions to be deleted, and delete them by id from the genotype, nd_experiment, and stock tables 

	&loopdelete($h);


    }

} catch {  
   # Rollback if transaction failed

	$dbh->rollback();
	die "An error occured! Transaction rolled back!" . $_ . "\n";
};
    
if (!$opt_t) { 
    # commit if this is not a test run

    $dbh->commit();
    print "Deletion succeeded! Commiting deletion of accessions! \n\n"; 
} else { 
    # Rolling back because test run

    print "No errors occurred. Rolling back test run. \n\n";
    $dbh->rollback();
}

sub loopdelete {
    my $sth = $_[0];
    while (my($stock_id,$nd_exp_id,$genotype_id) = $sth->fetchrow_array) {
	print STDERR "Deleting from genotype table where genotype id = $genotype_id \n";
	print STDERR "Deleting from nd_experiment table where nd_experiment id = $nd_exp_id \n";
	print STDERR "Deleting from stock table where stock id = $stock_id \n";
	$g->execute($genotype_id);
	$n->execute($nd_exp_id);
	$s->execute($stock_id);
    }
}
