
package CXGN::List::Validate;

use Moose;

use Module::Pluggable require => 1;

sub validate {
    my $self = shift;
    my $schema = shift;
    my $type = shift;
    my $list = shift;

    my $data;



    foreach my $p ($self->plugins()) {
        if ($type eq $p->name()) {
	     $data = $p->validate($schema, $list, $self, @_);
	}
    }
    return $data;
}

1;
