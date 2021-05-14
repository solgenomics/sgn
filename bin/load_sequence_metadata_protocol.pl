#! /usr/bin/perl

=head1
load_sequence_metadata_protocol.pl - create a new sequence metadata protocol

=head1 SYNOPSIS
This script uses the CXGN::Genotype::SequenceMetadata package to create a new 
Sequence Metadata Protocol in the nd_protocol table and store its sequence 
metadata protocol props in the nd_protocolprop table.

=head1 COMMAND-LINE OPTIONS
  ARGUMENTS
 -H host name (required) e.g. "localhost"
 -D database name (required) e.g. "cxgn_cassava"
 -U database username (required)
 -P database password (optional, default=prompt user for password)
 -t Sequence Metadata Type ID, cvterm_id of term from 'sequence_metadata_types' CV (required)
 -n protocol name (required)
 -d protocol description (required)
 -r reference genome name (required)
 -s score description (optional)
 -a attribute names and descriptions (optional)
    Example: "ID=marker name,Locus=gene name,pvalue=p value"
=head1 AUTHOR
    David Waring <djw64@cornell.edu>

=cut

use strict;

use Getopt::Std;
use Data::Dumper;

use Bio::Chado::Schema;
use CXGN::Genotype::SequenceMetadata;


# Read CLI Options
our ($opt_H, $opt_D, $opt_U, $opt_P, $opt_t, $opt_n, $opt_d, $opt_r, $opt_s, $opt_a);
getopts('H:D:U:P:t:n:d:r:s:a:');


# Check for required arguments
if ( !$opt_H || !$opt_U || !$opt_D ) {
    die "ERROR: Database options -H, -D, and -U are required!\n";
}
if ( !$opt_t ) {
    die "ERROR: Sequence Metadata Type is required!\n";
}
if ( !$opt_n ) {
    die "ERROR: Sequence Metadata Protocol name is required!\n";
}
if ( !$opt_d ) {
    die "ERROR: Sequence Metadata Protocol description is required!\n";
}
if ( !$opt_r ) {
    die "ERROR: Reference genome name is required!\n";
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


# Parse attributes
my %attributes = ();
if ( defined $opt_a && $opt_a ne '' ) {
    my @as = split(',', $opt_a);
    foreach my $a (@as) {
        my @vs = split('=', $a);
        my $n = $vs[0];
        my $d = $vs[1];
        $attributes{$n} = $d;
    }
}

# Create Protocol
my $smd = CXGN::Genotype::SequenceMetadata->new(bcs_schema => $schema, type_id => $opt_t);
my %args = (
    protocol_name => $opt_n,
    protocol_description => $opt_d,
    reference_genome => $opt_r,
    score_description => $opt_s,
    attributes => \%attributes
);
my $results = $smd->create_protocol(\%args);

print STDERR "Results:\n";
print STDERR Dumper $results;
