
package CXGN::Blast::SeqQuery;

use Moose;
use Module::Pluggable require => 1;

# list which modules for parsing input are available.
# the sequence module just passes the sequence through, 
# whereas another module could parse SGN unigene identifiers
# and retrieve their corresponding sequences.
#

sub validate { 
    my $self = shift;
    my $c = shift;
    my $method = shift;
    my $input = shift;


    my $valid = "OK";
    foreach my $m ($self->plugins()) { 
	if ($m->name eq $method) { 
	    $valid = $m->validate($c, $input);
	}
    }
    return $valid;
}


sub process { 
    my $self = shift;
    my $c = shift;
    my $method = shift;
    my $input = shift;

    my $seq_fasta = "";
    foreach my $m ($self->plugins()) { 
	if ($m->name eq $method) { 
	    $seq_fasta = $m->process($c, $input);
	}
    }
    return $seq_fasta;
}

sub autodetect_seq_type {
    my $self = shift;
    my $c = shift;
    my $method = shift;
    my $input = shift;

    my $seq_type = "";
    foreach my $m ($self->plugins()) { 
	if ($m->name eq $method) { 
	    $seq_type = $m->autodetect_seq_type($c, $input);
	}
    }
    return $seq_type;
}

1;
