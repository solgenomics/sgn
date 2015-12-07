
package CXGN::Blast::SeqQuery::Plugin::ProteinFasta;

use Moose;
use Bio::SeqIO;
use IO::String;


sub name { 
    return 'protein fasta';
}

sub type { 
    return 'protein';
}

sub example { 
    return ">SGN-P698236
VHYNLFKMNGFHHTEIWDRHESFECSSVGSEESHSLEGGEKLYHDPSTEGQKEAGPKSELTSGVKSLDRCLSNPRSLGEIPASYEISEYE
HLIEQEMRWLKANYQIKLRELKDQHLGLPPKASKPPTGSSKRKKKTKNKNSCLETLLKSSDCGKTISSESNGLSCPISVSQRARKCEAIK
GSPNVRDMVSSAKSFFTRTLLPNSLHRTTSLPVDAVDI";
}

sub validate { 
    my $self = shift;
    my $c = shift;
    my $sequence = shift;
    
    eval { 
	my $string_fh = IO::String->new($sequence);
	my $io = Bio::SeqIO->new( -fh => $string_fh,
		       -format => 'fasta');
	while (my $seq = $io ->next_seq()) { 
	    if ($seq->seq() !~ /^[ACDEFGHIKLMNPQRSTVWYX\n\s\t]+$/i) { 
		die "Protein sequence contains illegal characters: ".($seq->id);
	    }
	}
    };
    if ($@) { 
	return $@;
    }
    else { 
	return "OK";
    }
    
}

sub process { 
    my $self = shift;
    my $c = shift;
    my $sequence = shift;
    return $sequence;
}

1;
