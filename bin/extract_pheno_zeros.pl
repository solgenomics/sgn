#!/usr/bin/perl

=head1 NAME

extract_pheno_zeros.pl - find all 0 phenotype values in archived uploads and generate a CSV file to re-upload

=head1 DESCRIPTION

extract_pheno_zeros.pl -H [database host] -D [database name] -U [database uesr] -P [database pass] -s [start date YYYY-MM-DD] -o [output csv file]

Options:

 -H the database host
 -D the database name
 -U username
 -P password
 -d start date YYYY-MM-DD (default = 2024-06-11)
 -o output .csv file

=head1 AUTHOR

David Waring <djw64@cornell.edu>

=cut

use strict;
use warnings;
use DBI;
use Try::Tiny;
use Getopt::Long;
use Data::Dumper;
use CXGN::File::Parse;

my ( $dbhost, $dbname, $username, $password, $date, $output );
GetOptions(
    'H=s'        => \$dbhost,
    'D=s'        => \$dbname,
    'U=s'        => \$username,
    'P=s'        => \$password,
    's=s'        => \$date,
    'o=s'        => \$output,
);

if ( !$dbhost || !$dbname || !$username || !$password ) {
    print STDERR "ERROR: Missing either -H dbhost -D dbname -U username or -P password\n";
    exit 1;
}
if ( !$output ) {
    print STDERR "ERROR: Missing output .xls file\n";
    exit 1;
}
if ( !$date || $date eq '' ) {
    $date = "2024-06-11";
}

print STDERR "Connecting to database...\n";
my $dsn = 'dbi:Pg:database='.$dbname.";host=".$dbhost.";port=5432";
my $dbh = DBI->connect($dsn, $username, $password, { RaiseError => 1, AutoCommit=>0 });

# Get all phenotype files from the metadata since the start date
my $q = "SELECT dirname || '/' || basename
FROM metadata.md_files
LEFT JOIN metadata.md_metadata ON (md_files.metadata_id = md_metadata.metadata_id)
WHERE md_files.filetype = 'spreadsheet phenotype file' AND md_metadata.create_date > ?
ORDER BY create_date ASC;";
my $h = $dbh->prepare($q);
$h->execute($date);
$dbh->commit();

my %data;
my %traits;

# Check each file for 0s
while ( my ($file) = $h->fetchrow_array() ) {
    print STDERR "==> Checking File: $file\n";
    my $parser = CXGN::File::Parse->new(
        file => $file,
        required_columns => [ 'observationunit_name' ],
        column_aliases => {
            'observationunit_name' => [ 'plot_name', 'subplot_name', 'plant_name', 'observationUnitName', 'plotName', 'subplotName', 'plantName' ]
        }
    );
    my $parsed = $parser->parse();
    my $parsed_data = $parsed->{data};
    my $trait_columns = $parsed->{optional_columns};

    foreach my $row (@$parsed_data) {
        my $ou = $row->{'observationunit_name'};
        foreach my $trait (@$trait_columns) {
            my $value = $row->{$trait};
            if ( defined($value) && $value eq '0' ) {
                print STDERR "$ou | $trait = 0\n";
                $traits{$trait} = 1;
                $data{$ou}{$trait} = '0';
            }
        }
    }
}

# Generate output CSV data
my @output;
push @output, join(',', 'observationunit_name', keys %traits);
my @ous = sort keys %data;
foreach my $ou (@ous) {
    my @line;
    push @line, $ou;
    foreach my $trait (keys %traits) {
        my $value = $data{$ou}{$trait};
        push @line, defined($value) ? $value : '';
    }
    push @output, join(',', @line);
}


# Write CSV to file
open my $fh, '>', $output or die "Cannot open output file: $!";
foreach (@output) {
    print $fh "$_\n";
}
close $fh;
