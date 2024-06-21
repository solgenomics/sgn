
package SGN::Genefamily::Plugin::Orthomcl;

use Moose::Role;

sub get_data {
    my $self = shift;

    my $build = $self->build();
    
    open(my $F, "<", $self->files_dir()."/$build/genefamily_defs") || die "Can't find gene family definition file";
    
    my $header = <$F>;
    chomp($header);

    my @table;
    while (<$F>) {
	chomp;
	my ($orthogroup, $per_species_members) = split/\t/;
	my $sequence_link = qq | <a href="/tools/genefamily/$build/fasta/$orthogroup.fa">seqs</a> |;
	my $alignment_link = qq | <a href="/tools/genefamily/$build/alignments/$orthogroup.aln">alignment</a> |;
	my $tree = qq | <a href="/tools/genefamily/$build/trees/$orthogroup.tree">tree</a> |;
	
	my @all_members = split /\s+/, $per_species_members;

	my $members = join(",", @all_members);

	push @table, [$orthogroup, $sequence_link, $alignment_link, $tree, $members];
    }
    return \@table;
}


1;
