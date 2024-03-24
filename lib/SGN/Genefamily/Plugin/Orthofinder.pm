
package SGN::Genefamily::Plugin::Orthofinder;

use Moose::Role;

sub get_data {
    my $self = shift;

    my $build = shift;

    my $genefamily_definition_file =  $self->files_dir()."/$build/genefamily_defs.txt";

    print STDERR "Working with definition file at $genefamily_definition_file\n";
    open(my $F, "<", $genefamily_definition_file) || die "Can't find gene family definition file";
    
    my $header = <$F>;
    chomp($header);

    my @species = split /\t/, $header;
    
    my @table;
    while (<$F>) {
	chomp;
	my ($orthogroup, @per_species_members) = split/\t/;

	my $orthogroup_link = qq | <a href="/tools/genefamily/details/$build/$orthogroup">$orthogroup</a> | ;
	my $sequence_link = qq | <a href="/tools/genefamily/$build/fasta/$orthogroup.fa">seqs</a> |;
	my $alignment_link = qq | <a href="/tools/genefamily/$build/alignments/$orthogroup.aln">alignment</a> |;
	my $tree = qq | <a href="/tools/genefamily/$build/trees/$orthogroup.tree">tree</a> |;
	
	my $sequence_link = "<a href=\"/tools/genefamily/$build/...\">seqs</a>";
	my $alignment_link = "<a href=\"\">alignments</a>";
	my $tree = "<a>tree</a>";

	my @all_members;
	for (my $species =1; $species< @per_species_members; $species++) { 
	    my @members = split /\,/, $per_species_members[$species];
	    ## maybe add a link here later for each member
	    @all_members = (@all_members, @members);
	}
	my $members = join(",", @all_members);
	push @table, [$orthogroup_link,  $sequence_link, $alignment_link, $tree, scalar(@all_members)." members", $members];
    }
    return \@table;
}


1;
