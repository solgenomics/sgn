
package SGN::Controller::AJAX::Genefamily;

use Moose;

BEGIN { extends 'Catalyst::Controller::REST'; }

sub browse_families_table :Path('/ajax/tools/genefamily/table') Args(0) {
    my $self = shift;
    my $c = shift;

    my $build = $c->req->param("build");
    
    open(my $F, "<", $c->config->{genefamily_dir}."/$build/genefamily_defs") || die "Can't find gene family definition file";

    my @table;
    while (<$F>) {
	chomp;
	my ($orthogroup, $members) = split/\t/;
	my $sequence_link = "<a href=\"/tools/genefamily/$build/...\">seqs</a>";
	my $alignment_link = "<a href=\"\">alignments</a>";
	my $tree = "<a>tree</a>";
	push @table, [$orthogroup, $sequence_link, $alignment_link, $tree, $members];
    }

    $c->stash->{rest} = { data => \@table };

}
    
1;
