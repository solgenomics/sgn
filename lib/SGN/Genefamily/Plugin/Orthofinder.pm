
package SGN::Genefamily::Plugin::Orthofinder.pm

use Moose;

sub get_data {
    my $self = shift;
    
    open(my $F, "<", $self->genefamily_dir()."/".$self->build()."/genefamily_defs") || die "Can't find gene family definition file";
    
    my $header = <$F>;
    chomp($header);

    my @species = split /\t/, $header;
    
    my @table;
    while (<$F>) {
	chomp;
	my ($orthogroup, @per_species_members) = split/\t/;
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
	push @table, [$orthogroup, $sequence_link, $alignment_link, $tree, $members];
    }
}


1;
