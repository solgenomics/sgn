#! /usr/bin/perl

=head1 NAME

verify_featureprop_json.pl - pre-process and verify gff3 file for load_featureprop_json.pl script

=head1 DESCRIPTION

usage: verify_featureprop_json.pl -H [hostname] -D [database] -U [dbuser] -p [dbpass] -i [infile] -o [outfile]

-H database host name (default: localhost)
-D database name (default: breedbase)
-U database username (default: postgres)
-p database password
-i path to input file (required)
-o path to processed output file (required)

This script will pre-process and verify the input gff file before loading the data into the 
database using the load_featureprop_json.pl script.  It will:
- sort the input file by the seqid and start columns
- save the sorted file to the output location (and remove the initial input file)
- verify the seqid's exist as features in the database

The results will be printed to STDOUT, for missing features:
MISSING=feature_name

=cut

use strict;
use Getopt::Std;
use CXGN::DB::Connection;
use Bio::Chado::Schema;


# Directory to helper scripts
my $HELPER_SCRIPT_BIN="/home/production/cxgn/sgn/bin/sequence_metadata";



# Parse CLI Arguments
our ($opt_H, $opt_D, $opt_U, $opt_p, $opt_i, $opt_o);
getopts('H:D:U:p:i:o:');

if ( !$opt_i || !$opt_o ) {
    print STDERR "ERROR: You pust provide the required options: -i infile, -o outfile\n";
    exit 1;
}

my $dbhost = $opt_H ? $opt_H : "localhost";
my $dbname = $opt_D ? $opt_D : "breedbase";
my $dbuser = $opt_U ? $opt_U : "postgres";
my $dbpass = $opt_p;
my $infile = $opt_i;
my $outfile = $opt_o;


# PROCESS THE INPUT FILE
# Remove comments
# Sort by seqid and start
# Save to output file
my $rv = system("$HELPER_SCRIPT_BIN/preprocess_featureprop_json.sh \"$infile\" \"$outfile\"");
if    ($rv == -1)         { die("ERROR=Could not launch pre-processing script: $!\n"); }
elsif (my $s = $rv & 127) { die("ERROR=Pre-processing script died from signal $s\n"); }
elsif (my $e = $rv >> 8)  { die("ERROR=Pre-processing script exited with code $e\n"); }

# Connect to Database
my $dbh = CXGN::DB::Connection->new({ 
    dbhost => $dbhost, 
    dbname => $dbname,
    dbuser => $dbuser,
    dbpass => $dbpass 
});
my $schema = Bio::Chado::Schema->connect(sub { $dbh->get_actual_dbh() });


# CHECK FEATURES
my @features = `$HELPER_SCRIPT_BIN/get_unique_features.sh "$outfile"`;
foreach my $feature ( @features ) {
    chomp($feature);
    my $query = "SELECT feature_id FROM public.feature WHERE uniquename=?" ;
    my $sth = $dbh->prepare($query);
    $sth->execute($feature);
    my ($feature_id) = $sth->fetchrow_array();
    if ( $feature_id eq "" ) {
        print STDOUT "MISSING=$feature\n";
    }
}

# Close the DB Connection
$dbh->commit;
