
package CXGN::Blast::SeqQuery::Plugin::NucleotideSequence;

use Moose;

use Bio::Seq;

sub name { 
    return "nucleotide sequence";
}

sub type { 
    return 'nucleotide';
}

sub example { 
    return "AAAAGGATAATGTTATTATTGGAAGTACATTCATTTTAAGCCCCTTTGAACCAAAGTCATGTACATATATCCCACT
TGGAGAAATAATCTAAAGCCTCAATAATTACATTGTCTCATAAGATGCCTGTCACAGCTCACTATCATTCATATTTTTTCTATTCATGAA
TATAAATATAGGCAAACCCCACAAGTAGAAAAGGGAGGGGTAAATTGGATGGCCTGATGATCAATAAACTAACCTCATAGAT";
}

sub validate { 
    my $self = shift;
    my $c = shift;
    my $sequence = shift;
    
    print STDERR "SEQUENCE: $sequence\n";

    my $valid = "OK";

    if ($sequence !~ /^[ATGCYWRSKMBDHV\.\-N \n\t]+$/i) { 
	$valid = "Illegal chars in sequence $sequence";
    }
    return $valid;
    
}


sub process { 
    my $self = shift;
    my $c = shift;
    my $sequence = shift;
    return ">Untitled Sequence\n$sequence\n";
}

1;
