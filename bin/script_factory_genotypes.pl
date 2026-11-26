#!/usr/bin/env perl

=head1 NAME

script_factory_genotypes.pl - marker dosages of a genotyping protocol for an Analysis Pipeline run

=head1 SYNOPSIS

  perl script_factory_genotypes.pl --conf=<run>.dbconf.json --protocol=<nd_protocol_id> \
       --accessions=<file of accession stock ids> --out=<dosage matrix file>

=head1 DESCRIPTION

First step of an Analysis Pipeline job with a genomic (G) or single-step (H)
model: writes the dosage matrix of the genotyping protocol for the accessions
of the dataset (one line per genotyped accession: name, then the dosage of
every marker; header 'Marker' and the marker names), with the cached
Breedbase dosage matrix (CXGN::Genotype::DownloadFactory, DosageMatrix). The
BLUPF90+ engine (bin/script_factory_blupf90.pl --genotypes=) reads it.

The database connection comes from a JSON file written by the web server for
this run only (keys dbhost, dbname, dbuser, dbpass, cache_root,
shared_tempdir, backend, cluster_host, queue, basepath). The file is deleted
as soon as it is read, so the password is never on a command line nor kept
on disk.

Progress lines start with "[script_factory]"; a failure prints a WARNING
and exits with status 1 (the analysis then falls back to the pedigree or
unrelated model and says so).

=head1 AUTHOR

Chris Simoes <ccs263@cornell.edu>

=cut

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Getopt::Long;
use JSON::XS;
use File::Copy qw(copy);
use Bio::Chado::Schema;
use CXGN::People::Schema;
use CXGN::Genotype::DownloadFactory;

my ($conf_file, $protocol_id, $acc_file, $out);
GetOptions('conf=s' => \$conf_file, 'protocol=i' => \$protocol_id, 'accessions=s' => \$acc_file, 'out=s' => \$out);

sub fail {
    my $msg = shift;
    unlink($conf_file) if $conf_file && -e $conf_file;
    print STDERR "WARNING: The genotypes of the genotyping protocol could not be retrieved ($msg).\n";
    exit(1);
}

fail('missing arguments') if !$conf_file || !$protocol_id || !$acc_file || !$out;
my $conf = eval { open(my $F, '<', $conf_file) or die "cannot read the connection file\n"; local $/; my $j = <$F>; close($F); decode_json($j) };
unlink($conf_file);
fail($@ || 'invalid connection file') if !$conf;

my @acc_ids;
if (open(my $A, '<', $acc_file)) {
    while (my $l = <$A>) { push @acc_ids, $1 if $l =~ /^\s*(\d+)\s*$/; }
    close($A);
}
fail('no accessions') if !@acc_ids;

print STDERR "[script_factory] Retrieving the genotypes of protocol $protocol_id for " . scalar(@acc_ids) . " accessions\n";
my $dsn = "dbi:Pg:host=$conf->{dbhost};dbname=$conf->{dbname}";
my $schema = Bio::Chado::Schema->connect($dsn, $conf->{dbuser}, $conf->{dbpass}, { AutoCommit => 1, RaiseError => 1 },
                                         { on_connect_do => ['SET search_path TO public,sgn,phenome,sgn_people'] });
my $people_schema = CXGN::People::Schema->connect($dsn, $conf->{dbuser}, $conf->{dbpass}, { AutoCommit => 1, RaiseError => 1 },
                                                  { on_connect_do => ['SET search_path TO sgn_people,public'] });

my $fh = eval {
    my $geno = CXGN::Genotype::DownloadFactory->instantiate('DosageMatrix', {
        bcs_schema => $schema,
        people_schema => $people_schema,
        cache_root_dir => $conf->{cache_root},
        accession_list => \@acc_ids,
        protocol_id_list => [ $protocol_id ],
        return_only_first_genotypeprop_for_stock => 1,
        prevent_transpose => 1,    # one line per accession, as BLUPF90 reads them
    });
    $geno->download($conf->{shared_tempdir}, $conf->{backend}, $conf->{cluster_host}, $conf->{queue}, $conf->{basepath});
};
fail($@ =~ s/\s+$//r) if !$fh;

open(my $O, '>', $out) or fail("cannot write $out");
my ($n, $m, $first) = (0, 0, 1);
while (my $l = <$fh>) {
    if ($first) {
        $first = 0;
        if ($l =~ /^Marker\t/) { $m = scalar(grep { $_ ne '' && $_ !~ /^\s+$/ } split /\t/, $l) - 1; print $O $l; next; }
    }
    $n++ if $l =~ /\S/;
    print $O $l;
}
close($O);
fail('the protocol has no genotypes for these accessions') if $n < 1;
print STDERR "[script_factory] Genotypes: $n accession(s) x $m marker(s) from protocol $protocol_id\n";
exit(0);
