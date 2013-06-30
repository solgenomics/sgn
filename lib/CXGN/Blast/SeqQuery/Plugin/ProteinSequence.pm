
package CXGN::Blast::SeqQuery::Plugin::ProteinSequence;

use Moose;

sub name { 
    return "protein sequence";
}

sub convert { 
    my $self = shift;
    my $sequence = shift;
    return ">Untitled Sequence\n$sequence\n";
}

1;
