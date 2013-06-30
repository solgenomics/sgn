
package CXGN::Blast::SeqQuery::Plugin::Fasta;

use Moose;

sub name { 
    return "fasta";
}

sub check { 
    my $self = shift;
    my $sequence = shift;
    
}

sub process { 
    my $self = shift;
    my $sequence = shift;
    return $sequence;
}

1;
