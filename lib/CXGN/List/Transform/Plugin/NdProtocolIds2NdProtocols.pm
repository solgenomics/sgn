
package CXGN::List::Transform::Plugin::NdProtocolIds2NdProtocols;

use Moose;
use Data::Dumper;

sub name { 
    return "nd_protocol_ids_2_protocols";
}

sub display_name { 
    return "nd_protocol IDs to nd_protocol";
}

sub can_transform { 
    my $self = shift;
    my $type1 = shift;
    my $type2= shift;

    if (($type1 eq "nd_protocol_ids") and ($type2 eq "nd_protocols")) { 
        print STDERR "NdProtocolIds2NdProtocols: can transform $type1 to $type2\n";
        return 1;
    }
    return 0;
}

sub transform { 
    my $self = shift;
    my $schema = shift;
    my $list = shift;

    my @transform = ();
    my @missing = ();

    foreach my $l (@$list) { 
        my $rs = $schema->resultset("NaturalDiversity::NdProtocol")->search({
            nd_protocol_id => $l,
        });
        if ($rs->count() == 0) { 
            push @missing, $l;
        }
        else { 
            push @transform, $rs->first()->name();
        }
    }
    print STDERR " transform array = " . Dumper(@transform);
    print STDERR " missing array = " . Dumper(@missing);
    return {
        transform => \@transform,
        missing   => \@missing,
    };
}

1;
