#!/usr/bin/perl

=head1
generate_trial_instances.pl - creates a jbrowse instance for each trial in the database
=head1 SYNOPSIS
    generate_trial_instances.pl 
=head1 COMMAND-LINE OPTIONS
 
=head1 DESCRIPTION
This script makes a jbrowse instance for each trail in the database by creating a named directory, symlinking most necessary files, and creating a conf file using\
 accession names associated with the trial in the database. Also adds the dataset to the jbrowse.conf list.  
=head1 AUTHOR
Bryan Ellerbrock (bje24@cornell.edu) - August 2015
=cut

use strict;
use warnings;
use Net::SSH::Perl;
use Getopt::Std;
use Try::Tiny;
use CXGN::DB::InsertDBH;
use Moose;
use Data::Dumper;




# get database params

our ($opt_H, $opt_D);

getopts('H:i:D:t');

my $dbhost = $opt_H;
my $dbname = $opt_D;
my $dbh;
my %seq;

# create database handle

$dbh = CXGN::DB::InsertDBH->new( { dbhost=>$dbhost,
				         dbname=>$dbname,
				         dbargs => {AutoCommit => 0,
						     RaiseError => 1}
				       }
    );

# prep and execute sql statement to select trial_id, trial_name, and accessions from all trials

my $query = "select ;"
	
my $h=$dbh->prepare($query);

$h->execute();
	
# then loop through each row and create jbrowse instance for each trial 

    while (my($trial_id,$trial_name,@accession_names) = $h->fetchrow_array) {
	
	# create folder with $trial_id
	

    }
}
