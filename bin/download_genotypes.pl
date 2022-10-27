#!/usr/bin/perl

=head1

download_genotypes.pl - downloads a genotyping file (vcf or dosage) using a file with a list of accession names and a genotyping protocol id.

=head1 SYNOPSIS

perl bin/download_genotypes.pl -h [dbhost] -d [dbname] -i [infile] -o [outfile] -p [genotyping_protocol]

=head2 REQUIRED ARGUMENTS

 -h host name  e.g. "localhost"
 -d database name e.g. "cxgn_cassava"
 -p genotyping protocol name
 -i path to infile
 -o path to output file
 -f format [default vcf]

=head2 OPTIONAL ARGUMENTS

 -q web cluster queue
 -t cluster shared temp dir
 -c cache root dir
 -b basepath
 
 

=head1 DESCRIPTION



=head1 AUTHOR

  Lukas Mueller

=cut

use strict;
use warnings;

use Bio::Chado::Schema;
use Getopt::Std;
use Data::Dumper;

use SGN::Model::Cvterm;
use CXGN::DB::InsertDBH;
use CXGN::Dataset::File;
use CXGN::List;

our ($opt_h, $opt_d, $opt_p, $opt_i, $opt_o, $opt_q, $opt_t, $opt_c, $opt_b, $opt_f);

getopts("h:d:p:i:o:q:t:c:b:f:");
my $dbhost = $opt_h;
my $dbname = $opt_d;
my $in_file = $opt_i;
my $out_file = $opt_o;
my $protocol_name = $opt_p;
my $web_cluster_queue = $opt_q || '';
my $cluster_shared_tempdir = $opt_t || '/tmp';
my $cluster_host = $opt_c || 'localhost';
my $format = $opt_f || "vcf";
my $basepath = $opt_b || '/home/production/cxgn/sgn';

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

my $protocol_id;
while (my ($pr_id, $pr_name) = $h->fetchrow_array()) {
    print STDERR "\nFound genotyping protocol: $pr_name -- id: $pr_id\n";
    $protocol_exists = 1;
    $protocol_id = $pr_id;
}

if (!$protocol_exists) {
    die "\n\nGENOTYPING PROTOCOL $protocol_name does not exist in the database\n\n";
}

my @accession_names;
if ($in_file) { 
    print STDERR "Getting genotype names... ";
    
    
    open(my $F, "< :encoding(UTF-8)", $in_file) || die "Can't open file $in_file\n";

    while (<$F>) {
	chomp;
	push @accession_names, $_;
    }
    close($F);
}


my $s= Bio::Chado::Schema->connect(  sub { $dbh->get_actual_dbh() } );
my $p = CXGN::People::Schema->connect( sub { $dbh->get_actual_dbh() });

my @accession_ids;

foreach my $a (@accession_names) {
    my $row = $s->resultset('Stock::Stock')->find( { uniquename => $a });
    if (!$row) {
	print STDERR "Accession $a does not exist! Skipping!\n";
    }
    else {
	push @accession_ids, $row->stock_id();
    }	
}


my $ds = CXGN::Dataset::File->new( { people_schema => $p, schema => $s } );

if ($in_file) { 
    $ds->accessions(\@accession_ids);
}
$ds->genotyping_protocols([ $protocol_id ]);

if ($format eq "vcf") { 
    my $fh = $ds->retrieve_genotypes_vcf($protocol_id, $out_file, '/tmp', $cluster_shared_tempdir, 'Slurm', $cluster_host, $web_cluster_queue, $basepath, 1);
}
elsif ($format eq "dosage") {
    my $fh = $ds->retrieve_genotypes($protocol_id, $out_file, '/tmp', $cluster_shared_tempdir, 'Slurm', $cluster_host, $web_cluster_queue, $basepath, 1);
}
else {
    print STDERR "Unknown format $format.\n";
}

print STDERR "Done.\n";
