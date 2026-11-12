#!/usr/bin/perl

=head1

record_finish_timestamp.pl

=head1 SYNOPSIS

record_finish_timestamp.pl -H [dbhost] -D [dbname] -P [dbpass] -U [dbuser] -j [jobid]

=head1 COMMAND-LINE OPTIONS
ARGUMENTS
 -H host name (required) Ex: "breedbase_db"
 -D database name (required) Ex: "breedbase"
 -U database username Ex: "postgres"
 -P database userpass Ex: "postgres"
 -j sp_job_id

=head2 DESCRIPTION

perl bin/record_finish_timestamp.pl -H breedbase_db -D breedbase -U postgres -P XXXX -j 1 

This script is to be used in the recording of finish timestamps for background jobs. When submitting a job,
the backend object calls generate_finish_timstamp_cmd() which uses this script to write the finish timestamp 
to the database. 

=head1 AUTHOR

Ryan Preble <rsp98@cornell.edu>

=cut

use strict;
use Getopt::Long;
use Bio::Chado::Schema;
use DateTime;
use CXGN::People::Schema;
use CXGN::DB::InsertDBH;
use CXGN::Job;
use Try::Tiny;

my ( $help, $dbhost, $dbname, $dbuser, $dbpass, $jobid);
GetOptions(
    'dbhost|H=s'           => \$dbhost,
    'dbname|D=s'           => \$dbname,
    'dbuser|U=s'           => \$dbuser,
    'dbpass|P=s'           => \$dbpass,
    'jobid|j=s'            => \$jobid,
    'help'                 => \$help,
);
pod2usage(1) if $help;
if (!defined($jobid) || !$dbuser || !$dbname || !$dbhost || !$dbpass ) { 
    pod2usage({ -msg => 'Error. Missing options!', -verbose => 1, -exitval => 1 });
}

# Connect to databases
my $dbh;
if ($dbpass && $dbuser) {
    $dbh = DBI->connect(
        "dbi:Pg:database=$dbname;host=$dbhost",
        $dbuser,
        $dbpass,
        {AutoCommit => 1, RaiseError => 1}
    );
}
else {
    $dbh = CXGN::DB::InsertDBH->new({
        dbhost => $dbhost,
        dbname => $dbname,
        dbargs => {AutoCommit => 1, RaiseError => 1}
    });
}

my $chado_schema = Bio::Chado::Schema->connect(sub { $dbh },  { on_connect_do => ['SET search_path TO  public, sgn, metadata, phenome;'] });
my $people_schema = CXGN::People::Schema->connect(sub { $dbh }, {on_connect_do => ['SET search_path TO public, sgn, sgn_people']});
my $timestamp = DateTime->now(time_zone => 'local')->strftime('%Y-%m-%d %H:%M:%S');

my $finish_timestamp_coderef = sub {
    my $job = CXGN::Job->new({
        sp_job_id => $jobid,
        schema => $chado_schema,
        people_schema => $people_schema
    });

    $job->finish_timestamp($timestamp);
    $job->store();
};

try {
    $chado_schema->txn_do($finish_timestamp_coderef);
    print STDERR "Recorded job finish timestamp at $timestamp\n";
} catch {
    $chado_schema->txn_rollback();
    print STDERR "Failed to record finish timestamp for Job ID $jobid: ", $_, "\n";
};