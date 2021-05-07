#! /usr/bin/perl

=head1
load_sequence_metadata.pl - verify and store sequence metadata from a gff3 file

=head1 SYNOPSIS
This script uses the CXGN::Genotype::SequenceMetadata package to verify and store sequence metadata 
from a gff3 file.

The verification step checks to make sure the seqid column (#1) in the gff3 file matches existing features 
stored in the database.  If a list of attributes are provided, the verification step will check if those 
attributes exist in the gff3 file and if there are attributes in the file missing from the provided list.

If the verification passes, the script will store the annotations from the gff3 file as sequence metadata 
in the featureprop_json table.

IMPORTANT:  A sequence metadata protocol must already exist in the nd_protocol table and must have an nd_protocolprop 
of type 'sequence_metadata_protocol_properties' that include the sequence metadata type and attributes described by 
the protocol.


=head1 COMMAND-LINE OPTIONS
  ARGUMENTS
 -H host name (required) e.g. "localhost"
 -D database name (required) e.g. "cxgn_cassava"
 -U database username (required)
 -P database password (optional, default=prompt user for password)
 -n nd_protocol_id of the sequence metadata protocol to associated the data with (required)
 -i input gff file (required)
 -o output/processed gff file (optional, default=$input.processed)
 -s species name (required)
 -w flag to skip verification warnings about missing/undefined attributes (optional, default=prompt user on warnings)
=head1 AUTHOR
    David Waring <djw64@cornell.edu>
=cut

use strict;

use Getopt::Std;
use Data::Dumper;
use JSON;

use Bio::Chado::Schema;
use CXGN::Genotype::SequenceMetadata;



# Read CLI Options
our ($opt_H, $opt_D, $opt_U, $opt_P, $opt_n, $opt_i, $opt_o, $opt_s, $opt_w);
getopts('H:D:U:P:n:i:o:s:w');


# Check for required arguments
if ( !$opt_H || !$opt_U || !$opt_D ) {
    die "ERROR: Database options -H, -D, and -U are required!\n";
}
if ( !$opt_n ) {
    die "ERROR: Sequence Metadata Protocol ID is required!\n";
}
if ( !$opt_i ) {
    die "ERROR: Input gff file path required!\n";
}
if ( !$opt_s ) {
    die "ERROR: Species name is required!\n";
}


# Set parameters from options
my $nd_protocol_id = $opt_n;
my $input = $opt_i;
my $output = $opt_o ? $opt_o : $opt_i . ".processed";
my $species = $opt_s;
my $ignore_warnings = $opt_w;


# Check if input file exists
if( !(-e -f -r $input) ){
   die "ERROR: Input file ($input) does not exist or is not readable!\n";	
}


# Connect to DB
my $pass = $opt_P;
if ( !$opt_P ) {
    print "Password for $opt_H / $opt_D: \n";
    my $pw = <>;
    chomp($pw);
    $pass = $pw;
}
print STDERR "Connecting to database...\n";
my $dsn = 'dbi:Pg:database='.$opt_D.";host=".$opt_H.";port=5432";
my $schema = Bio::Chado::Schema->connect($dsn, $opt_U, $pass);
my $dbh = $schema->storage->dbh;


# Get the protocol information (type_id and attributes)
my $q = "SELECT value FROM public.nd_protocolprop WHERE nd_protocol_id = ?;";
my $h = $dbh->prepare($q);
$h->execute($nd_protocol_id);
my ($value_json) = $h->fetchrow_array();
if (!$value_json){
    die "ERROR: Sequence Metadata Protocol ID ($nd_protocol_id) is not valid!\n";
}
my $value = decode_json $value_json;
my $type_id = $value->{'sequence_metadata_type_id'};
my $attribute_descriptions = $value->{'attribute_descriptions'};
if ( !$type_id || !$attribute_descriptions ) {
    die "ERROR: Sequence Metadata Protocol does not have the correct attributes (sequence_metadata_type_id, attribute_descriptions) set!\n";
}
my @attributes = keys %{$attribute_descriptions};


# VERIFY
print STDERR "====> VERIFY GFF FILE <====\n";
print STDERR "Input File: $input\n";
print STDERR "Output File: $output\n";
print STDERR "Species: $species\n";
print STDERR "Type ID: $type_id\n";
print STDERR "Protocol ID: $nd_protocol_id\n";
print STDERR "Attributes: " . join(', ', @attributes) . "\n";

my $smd = CXGN::Genotype::SequenceMetadata->new(bcs_schema => $schema, type_id => $type_id, nd_protocol_id => $nd_protocol_id);
my $verification_results = $smd->verify($input, $output, $species, \@attributes);

# Verification Error
if ( $verification_results->{'processed'} ne 1 || $verification_results->{'verified'} ne 1 ) {
    print STDERR "Missing features:\n";
    print STDERR Dumper $verification_results->{'missing_features'};
    die "ERROR: Could not verify the input gff file!\n";
}
elsif ( !$ignore_warnings && ($verification_results->{'missing_attributes'} || $verification_results->{'undefined_attributes'}) ) {
    print STDERR "WARNING: Missing and/or undefined attributes:\n";
    print STDERR "Missing Attributes (Provided in the list of attributes but not found in the file)\n";
    print STDERR Dumper $verification_results->{'missing_attributes'};
    print STDERR "Undefined Attributes (Found in the file but not provided in the list of attributes)\n";
    print STDERR Dumper $verification_results->{'undefined_attributes'};

    print "Do you want to continue storing the file? (Y/N): ";
    chomp(my $answer = <STDIN>);
    if ( !(lc($answer) eq 'y') ) {
        die "ERROR: Verification failed due to missing/undefined attributes\n";
    }
}

print "--> VERIFICATION COMPLETE!\n";


# STORE
print STDERR "====> STORE GFF FILE <====\n";

my $store_results = $smd->store($output, $species);

# Store Error
if ( $store_results->{'stored'} ne 1 ) {
    die $store_results->{'error'};
}

print STDERR "--> STORAGE COMPLETE (" . $store_results->{'chunks'} . " chunks written to the database)!\n";
