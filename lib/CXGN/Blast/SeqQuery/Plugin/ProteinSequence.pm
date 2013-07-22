
package CXGN::Blast::SeqQuery::Plugin::ProteinSequence;

use Moose;

use Bio::Seq;

sub name { 
    return "protein sequence";
}

sub type { 
    return 'protein';
}

sub example { 
    return "VHYNLFKMNGFHHTEIWDRHESFECSSVGSEESHSLEGGEKLYHDPSTEGQKEAGPKSELTSGVKSLDRCLSNPRSLGEIPASYEISEYE
HLIEQEMRWLKANYQIKLRELKDQHLGLPPKASKPPTGSSKRKKKTKNKNSCLETLLKSSDCGKTISSESNGLSCPISVSQRARKCEAIK
GSPNVRDMVSSAKSFFTRTLLPNSLHRTTSLPVDAVDI";
}

sub validate { 
    my $self = shift;
    my $c = shift;
    my $input = shift;

    eval { 
	my $s = Bio::Seq->new(-seq => $input);

	if ($s->seq() !~ /^[ACDEFGHIKLMNPQRSTVWYX\n\s\t]$/i) { 
	    $c->stash->{rest} = { error=> "Protein sequence contains illegal characters: ".($s->id)};
	    return;
	}
    };
    if ($@) { 
	$c->stash->{rest} = {error => "The sequence does not seem to be a legal protein sequence.", };
	return;
    }
    
    return "OK";
}
    
sub process { 
    my $self = shift;
    my $c = shift;
    my $sequence = shift;

    return ">Untitled Sequence\n$sequence\n";
}

1;
