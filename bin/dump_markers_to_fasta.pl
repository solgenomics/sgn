#!/usr/bin/perl -w

# This script will output all marker and primer sequences to fasta. 
# These fasta files can be used to generate blast databases. 

use strict;
use CXGN::DB::Connection;
use Getopt::Std;

# optional map_version_id
our ($opt_v);
getopts('v:');

my $dbh = CXGN::DB::Connection->new();

my $DEBUG = 1;

my @marker_types = ("COS","P","TM","RFLP - fwd","RFLP - rev","PCR - fwd","PCR - rev","COSII","EST clones","EST markers","Unigenes - singletons","Unigenes - contigs", "SNP", "SNP");

my $map_version_id = $opt_v;

# test whether map_version_id is valid
if ($map_version_id) {

    my $query = "SELECT map_version_id FROM map_version WHERE map_version_id = ?";
    my $sth = $dbh->prepare($query);
    $sth->execute($map_version_id);
    
    my $exists = $sth->fetchrow();

    unless ($exists) { die "invalid map_version_id specified\n" }
}

# modify queries to accomodate specific map_version_id
my ($join,$where,$where_modified) = ("","","");

if ($map_version_id) {
    $join = "join marker_experiment using (marker_id) join marker_location using (location_id)";
    $where = "and map_version_id = ?";
    $where_modified = "where map_version_id = ?";
}

my @queries = (

# cos markers
"SELECT c.cos_id as name, c.marker_id, coalesce(substring(e.seq from qc_report.hqi_start::integer+1 for qc_report.hqi_length::integer), e.seq) as sequence FROM cos_markers AS c LEFT JOIN est AS e ON (c.est_read_id=e.read_id) INNER JOIN qc_report on (e.est_id=qc_report.est_id) $join where marker_id > 0 and cos_id is not null and coalesce(substring(seq, hqi_start::integer+1, hqi_length::integer), seq) is not null and coalesce(substring(seq, hqi_start::integer+1, hqi_length::integer), seq) != '' $where",

# p markers
"SELECT p.p_mrkr_name as name, p.marker_id, e.seq as sequence  FROM p_markers AS p INNER JOIN seqread AS s ON p.est_clone_id=s.clone_id INNER JOIN est AS e ON s.read_id=e.read_id $join where marker_id > 0 and p_mrkr_name is not null and seq is not null and seq != '' $where",

# tm_markers
"SELECT tm.tm_name as name, tm.marker_id, r.fasta_sequence as sequence FROM tm_markers AS tm INNER JOIN rflp_sequences AS r ON tm.seq_id=r.seq_id $join where tm_name is not null and marker_id > 0 and fasta_sequence is not null and fasta_sequence != '' $where",

# rflp markers (forward)
"SELECT rflp_name||'-F' as name, marker_id, fasta_sequence as sequence FROM rflp_markers AS r LEFT JOIN rflp_sequences AS fs ON r.forward_seq_id=fs.seq_id $join where fasta_sequence is not null and fasta_sequence != '' $where",

# rflp markers (reverse)
"SELECT rflp_name||'-R' as name, marker_id, fasta_sequence as sequence FROM rflp_markers AS r LEFT JOIN rflp_sequences AS fs ON r.reverse_seq_id=fs.seq_id $join where fasta_sequence is not null and fasta_sequence != '' $where",

# pcr primers (forward)
"select alias||'-FPRIMER' as name, marker_id, sequence from marker_alias inner join pcr_experiment using(marker_id) inner join pcr_experiment_sequence using(pcr_experiment_id) join sequence using(sequence_id) join cvterm on (pcr_experiment_sequence.type_id=cvterm.cvterm_id) $join where sequence is not null $where and cvterm.name='forward_primer'",

# pcr primers (reverse)
"select alias||'-RPRIMER' as name, marker_id, sequence from marker_alias inner join pcr_experiment using(marker_id) inner join pcr_experiment_sequence using(pcr_experiment_id) join sequence using(sequence_id) $join join cvterm on (pcr_experiment_sequence.type_id=cvterm.cvterm_id) where sequence is not null $where and cvterm.name='reverse_primer'",

# cosii markers?
"select alias, marker_alias.marker_id, seq from marker_alias inner join cosii_ortholog using(marker_id) inner join unigene using(unigene_id) inner join unigene_consensi using(consensi_id) $join $where_modified",

# this one works good for EST clones (we're skipping genomic clones, of course)
"select alias, marker_id, coalesce(substring(seq, hqi_start::integer+1, hqi_length::integer), seq) as sequence from marker_alias inner join marker_derived_from using(marker_id) inner join clone on(clone_id=id_in_source and derived_from_source_id=1) inner join seqread using(clone_id) inner join est using(read_id) inner join qc_report using(est_id) $join where coalesce(substring(seq, hqi_start::integer+1, hqi_length::integer), seq) is not null and coalesce(substring(seq, hqi_start::integer+1, hqi_length::integer), seq) != '' $where",

# this one SHOULD work for est markers linked by read, but the sequences are missing
"select alias, marker_id, coalesce(substring(e.seq from qc_report.hqi_start::integer+1 for qc_report.hqi_length::integer), e.seq) as sequence from marker_alias inner join marker_derived_from as d using(marker_id) inner join seqread on(id_in_source=read_id) inner join est as e on(e.read_id=seqread.read_id) inner join qc_report using(est_id) $join where derived_from_source_id=2 and coalesce(substring(seq, hqi_start::integer+1, hqi_length::integer), seq) is not null and coalesce(substring(seq, hqi_start::integer+1, hqi_length::integer), seq) != '' $where",

# unigenes - singletons
"select alias, marker_id, COALESCE(substring(seq FROM (hqi_start)::int+1 FOR (hqi_length)::int ),seq) as sequence from marker_alias inner join marker_derived_from using(marker_id) inner join unigene on(unigene_id=id_in_source and derived_from_source_id=3) LEFT JOIN unigene_member USING (unigene_id) LEFT JOIN est USING (est_id) LEFT JOIN qc_report USING (est_id) $join where unigene.nr_members=1 and coalesce(substring(seq, hqi_start::integer+1, hqi_length::integer), seq) is not null and coalesce(substring(seq, hqi_start::integer+1, hqi_length::integer), seq) != '' $where",

# unigenes - real unigenes
"select alias, marker_id, seq as sequence from marker_alias inner join marker_derived_from using(marker_id) inner join unigene on(unigene_id=id_in_source and derived_from_source_id=3) LEFT JOIN unigene_consensi USING (consensi_id) $join where seq is not null and seq != '' $where",

#SNP markers - left
"select alias||'-5prime_flanking_region' as name, marker_id, sequence from marker_alias inner join pcr_experiment using(marker_id) inner join pcr_experiment_sequence using(pcr_experiment_id) join sequence using(sequence_id) $join join cvterm on (pcr_experiment_sequence.type_id=cvterm.cvterm_id) where sequence is not null $where and cvterm.name='five_prime_flanking_region'",

#SNP markers - right
"select alias||'-3prime_flanking_region' as name, marker_id, sequence from marker_alias inner join pcr_experiment using(marker_id) inner join pcr_experiment_sequence using(pcr_experiment_id) join sequence using(sequence_id) $join join cvterm on (pcr_experiment_sequence.type_id=cvterm.cvterm_id) where sequence is not null $where and cvterm.name='three_prime_flanking_region'"

);

# using a hash makes sure the identifiers are unique. In the event of
# a conflict, the later result takes precedence over the earlier.

my %marker_hash;
    
foreach my $index (0..$#queries) {

    my $query = $queries[$index];
    my $marker_type = $marker_types[$index];
    
    my $sth = $dbh->prepare($query);

    if ($map_version_id) { $sth->execute($map_version_id) }
    else { $sth->execute() }
    
    while (my ($name, $marker_id, $seq) = $sth->fetchrow_array()) {
	$marker_hash{$marker_type}{$marker_id}{seq} = $seq; # for SGN-M$id format
	$marker_hash{$marker_type}{$marker_id}{name} = $name; # marker alias
    }    
}

$dbh->disconnect(42);

# now print the fasta file! Woo!

my %marker_count = ();

foreach my $marker_type (sort keys %marker_hash){

    foreach my $marker (sort keys %{$marker_hash{$marker_type}}) {

	my $seq = $marker_hash{$marker_type}{$marker}{seq};
	my $name = $marker_hash{$marker_type}{$marker}{name};

	if ($seq =~ /^\s*$/) {
	    # uh-oh!
	    warn "$marker has an empty sequence!\n";
	    next;
	}
	
	if ($seq =~ /[^atgcnrymkswbdhv]/i){ 
	    # allowing IUPAC nucleotide codes - http://www.mun.ca/biochem/courses/3107/symbols.html
	    # AFLP primers are often written as "MSEI-CAG", where the first part is a restriction enzyme.
	    # For now we'll just skip these. There aren't many.
	    warn "$marker contains non-nucleotide characters ($marker_hash{$marker_type}{$marker}).\n";
	    next;
	}
	
        $marker_count{$marker}++;
        # if marker has been seen before, append count onto ID
	my $count = ($marker_count{$marker} > 1) ? "-$marker_count{$marker}" : "";

	# regular plain ol fasta file
	print ">SGN-M$marker$count $name ($marker_type)\n$seq\n";
    }
}
