
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
	my $sequence_link = qq | <a href="/tools/genefamily/fasta/$build/$orthogroup">seqs</a> |;

	my $alignment_link = "alignment";
	if ( -e $self->files_dir()."/$build/alignments/$orthogroup.aln" ) {
	    $alignment_link = qq | <a href="/tools/genefamily/alignments/$build/$orthogroup">alignment</a> |;
	}

	my $tree_link = "tree";

	if ( -e $self->files_dir()."/$build/trees/$orthogroup.tree") { 
	    $tree_link = qq | <a href="/tools/genefamily/$build/trees/$orthogroup">tree</a> |;
	}

	
	my @all_members;
	for (my $species =1; $species< @per_species_members; $species++) { 
	    my @members = split /\,/, $per_species_members[$species];
	    ## maybe add a link here later for each member
	    @all_members = (@all_members, @members);
	}
	my $members = join(",", @all_members);
	push @table, [$orthogroup_link,  $sequence_link, $alignment_link, $tree_link, scalar(@all_members)." members", $members];
    }
    
    return \@table;
}


1;
