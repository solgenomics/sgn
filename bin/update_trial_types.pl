#!/usr/bin/perl

=head1

discard_seedlots.pl - a script to load stock data

=head1 SYNOPSIS

discard_seedlots.pl -H [dbhost] -D [dbname] [-t] -i infile  -r discard_reason -d discard_date

=head1 COMMAND-LINE OPTIONS

 -H host name
 -D database name
 -i infile
 -u username associated with the discard action
 -t Test run . Rolling back at the end.

=head1 DESCRIPTION

Script to update the trial types. 

The infile is a tab delimited file with 3 columns: the trial name, the old type, and the new type. All the trials and new types need to be in the database.

=head1 AUTHORS

Lukas Mueller (lam87@cornell.edu)

=cut


use strict;
use warnings;
use Getopt::Std;
use CXGN::Tools::File::Spreadsheet;

use CXGN::Phenome::Schema;
use CXGN::Stock::Seedlot;
use Bio::Chado::Schema;
use CXGN::DB::InsertDBH;
use Carp qw /croak/ ;

use CXGN::Chado::Dbxref;
use CXGN::Chado::Phenotype;
use CXGN::People::Person;
use Try::Tiny;
use SGN::Model::Cvterm;
use Getopt::Long;
use Time::localtime;
use CXGN::Project;

my ( $dbhost, $dbname, $file, $username, $test, $reason, $date );
GetOptions(
    'i=s'        => \$file,
    'u=s'        => \$username,
    't'          => \$test,
    'dbname|D=s' => \$dbname,
    'dbhost|H=s' => \$dbhost,
    'reason|r=s' => \$reason,
    'date|y=s'   => \$date,
);

$reason = 'no reason given' if ! $reason;
my $tm = localtime();
$date = ($tm->year + 1900)."-".($tm->mon + 1)."-".$tm->mday if ! $date;

print STDERR "date is $date, dbname is $dbname\n";

my $dbh = CXGN::DB::InsertDBH->new( { dbhost=>$dbhost,
				      dbname=>$dbname,
				      dbargs => {AutoCommit => 1,
						 RaiseError => 1}
				    }
    );
my $schema= Bio::Chado::Schema->connect(  sub { $dbh->get_actual_dbh() } ,  { on_connect_do => ['SET search_path TO  public;'] }
					  );
my $phenome_schema= CXGN::Phenome::Schema->connect( sub { $dbh->get_actual_dbh } , { on_connect_do => ['set search_path to public,phenome;'] }  );


# parse first the file with the clone names and synonyms. Load into stock,
# and stockprop population for grouping the clones
#
my $sp_person_id = CXGN::People::Person->get_person_by_username($dbh, $username); 
die "Need to have a user pre-loaded in the database! " if !$sp_person_id;


my $trial_type_cv_id = $schema->resultset("Cv::Cv")->find( { name => 'project_type' })->cv_id();

# cache trial type db ids
#
print STDERR "Caching projectprop ids... ";

my $rs = $schema->resultset("Cv::Cvterm")->search( { cv_id => $trial_type_cv_id });
my %ids;
while (my $row = $rs->next()) {
    $ids{$row->name} = $row->cvterm_id();
}
print STDERR " Done.\n";

open(my $F, "<", $file) || die "Can't open file $file\n";

my $header = <$F>;

# accession genus species population_name synonyms
#
my $coderef= sub  {
    while (<$F>) {
	chomp;
	my ($trial_name, $old_type, $new_type) = split /\t/;
	# remove spaces from seedlot name 

	my $row = $schema->resultset("Project::Project")->find( { name => $trial_name });

	if ($row) {
	    print STDERR "Processing trial $trial_name; new type is $new_type\n";
	    my $project_obj = CXGN::Project->new( { bcs_schema => $schema, trial_id => $row->project_id() });
	    $project_obj->set_project_type($ids{$new_type}, undef);
	}
	else {
	    print STDERR "Trial $trial_name does not exist in the database\n";
	}
    }
	
    if ($test) {
        die "TEST RUN! rolling back\n";
    }
};


try {
    $schema->txn_do($coderef);
    if (!$test) { print "Transaction succeeded! Commiting stocks and their properties! \n\n"; }
} catch {
    die "An error occured! Rolling back  and reseting database sequences!" . $_ . "\n";
};
