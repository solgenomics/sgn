#! /usr/bin/perl

=head1 NAME

load_featureprop_json.pl - load json feature properties

=head1 DESCRIPTION

usage: load_featureprop_json.pl -H [hostname] -D [database] -i [infile] -t [type] -c [chunk count]

-H database host name (required)
-D database name (required)
-i path to input file (required)
-t cvterm name of featureprop type (cvterm of 'genotype_property' CV) (required)
-c chunk count (max number of items to include in a single JSON value)

input file format (to be decided):

a tab-delimited file with the following columns:
- feature name
- start position (zero-based)
- end position (zero-based)
- <not used>
- value

=cut

use strict;
use Getopt::Std;
use CXGN::DB::InsertDBH;
use Bio::Chado::Schema;
use JSON;



# Parse CLI Arguments
our ($opt_H, $opt_D, $opt_i, $opt_t, $opt_c);
getopts('H:D:i:t:c:');

if ( !$opt_H || !$opt_D || !$opt_i || !$opt_t ) {
    print STDERR "ERROR: You pust provide the required options: -H hostname, -D database -i infile, -t type\n";
    exit 1;
}

my $dbhost = $opt_H;
my $dbname = $opt_D;
my $infile = $opt_i;
my $type_cvterm_name = $opt_t;
my $chunk_size = $opt_c ? $opt_c : 10000;


# Connect to Database
my $dbh = CXGN::DB::InsertDBH->new({ 
    dbhost => $opt_H,
    dbname => $opt_D,
    dbargs => {AutoCommit => 1, RaiseError => 1}
});
my $schema = Bio::Chado::Schema->connect(sub { $dbh->get_actual_dbh() });


# Get type cvterm ID
my $cv = $schema->resultset("Cv::Cv")->find({ name => 'genotype_property' });
my $cvterm = $schema->resultset("Cv::Cvterm")->find({
    name  => $type_cvterm_name,
    cv_id => $cv->cv_id()
});
if ( !$cvterm ) {
    print STDERR "ERROR: No matching cvterm found for the specified type [$type_cvterm_name]\n";
    exit 1;
}
my $cvterm_id = $cvterm->cvterm_id();


# Open the input file
open(my $fh, '<', $infile) or die "Could not open input file\n";

# Properties of the current chunk
my $chunk_feature = undef;  # the name of the chunk's feature (if the current line's feature name is different, start a new chunk)
my $chunk_start = undef;    # the min start position of the chunk's contents
my $chunk_end = undef;      # the max end position of the chunk's contents
my @chunk_values = ();      # the chunk's values (to be converted to JSON array)
my $chunk_count = 0;        # the number of items in the chunk (if the count exceeds the chunk_size, start a new chunk)
my $total = 0;              # the total number of chunks

# Parse the input by line
while ( defined(my $line = <$fh>) ) {
    chomp $line;
    my @data = split(/\t/, $line);
    my $feature = @data[0];
    my $start = @data[1];
    my $end = @data[2];
    my $score = @data[4];

    # Write the current chunk to the database
    # when the feature changes or the chunk size has been reached
    if ( ($chunk_feature && $feature ne $chunk_feature) || $chunk_count > $chunk_size ) {
        write_chunk();
    }

    # Set chunk properties
    if ( !$chunk_feature ) {
        $chunk_feature = $feature;
    }
    if ( !$chunk_start || $start < $chunk_start ) {
        $chunk_start = $start
    }
    if ( !$chunk_end || $end > $chunk_end ) {
        $chunk_end = $end;
    }
    my %value = ( score => $score, start => $start, end => $end);
    push @chunk_values, \%value;
    $chunk_count++;
}

# Write the last chunk
write_chunk();

print "Wrote $total chunks\n";


sub write_chunk() {

    # Get Feature ID
    my $query = "SELECT feature_id FROM public.feature WHERE uniquename=?" ;
    my $sth = $dbh->prepare($query);
    $sth->execute($chunk_feature);
    my ($feature_id) = $sth->fetchrow_array();

    # Convert values to JSON array string
    my $json_str = encode_json(\@chunk_values);

    # Insert into the database
    my $insert = "INSERT INTO public.featureprop_json (feature_id, type_id, start_pos, end_pos, json) VALUES (?, ?, ?, ?, ?);";
    my $ih = $dbh->prepare($insert);
    $ih->execute($feature_id, $cvterm_id, $chunk_start, $chunk_end, $json_str);

    # Reset chunk properties
    $chunk_feature = undef;
    $chunk_start = undef;
    $chunk_end = undef;
    @chunk_values = ();
    $chunk_count = 0;
    $total++;

}