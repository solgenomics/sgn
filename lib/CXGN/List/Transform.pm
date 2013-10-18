
package CXGN::List::Transform;

use Moose;

use Module::Pluggable require => 1;

sub can { 
    my $self = shift;
    my $type1 = shift;
    my $type2 = shift;

    foreach my $p ($self->plugins()) { 
	if ($p->can($type1, $type2)) { 
	    return $p->name();
	}
    }
    return 0;
}


sub transform { 
    my $self = shift;
    my $schema = shift;
    my $type = shift;
    my $list = shift;

    my $data;

    

    foreach my $p ($self->plugins()) { 
        if ($type eq $p->name()) { 
             $data = $p->transform($schema, $list);
        }
    }
    return $data;
}

1;
