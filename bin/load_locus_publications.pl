
=head1 NAME
 load_locus_publications.pl - a script to associate publications (pubmed IDs) with locus

=head1 SYNOPSYS

load_locus_publications.pl -p [person_id] -H [hostname] -D [database name] file

where file contains a column with locus names and a column with associated pubmed_ids.

=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>

=cut

use strict;
use warnings;

use Getopt::Std;
use File::Slurp qw | slurp |;
use CXGN::DB::InsertDBH;
use CXGN::Phenome::Locus;
use CXGN::Chado::Dbxref;

our %opts;
getopts('p:H:D:', \%opts);

my $file = shift;

my @lines = slurp($file);
chomp(@lines);

my $dbh = CXGN::DB::InsertDBH->new( { dbname => $opts{D},
				      dbhost => $opts{H},
				    });



foreach my $l (@lines) { 
    my ($locus_name, $pubmed_id) = split /\t/, $l;
    my $sth = $dbh->prepare("SELECT locus_id FROM phenome.locus WHERE locus_name = ?");
    $sth->execute($locus_name);
    my ($locus_id) = $sth->fetchrow_array();
    my $locus = CXGN::Phenome::Locus->new($dbh, $locus_id);
    
    my $pub = CXGN::Chado::Publication->get_pub_by_accession($dbh, $pubmed_id);
    
    my ($dbxref, @more_dbxrefs) = $pub->get_dbxrefs();
    print STDERR "Adding dbxref ".($dbxref->get_dbxref_id())."...\n";
    my $dbxref = CXGN::Chado::Dbxref->new($dbh, $dbxref->get_dbxref_id);

    $locus->add_locus_dbxref($dbxref, undef, $opts{p});

}
$dbh->commit();
    
				





