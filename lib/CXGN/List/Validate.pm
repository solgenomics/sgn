
package CXGN::List::Validate;

use Moose;

use Module::Pluggable require => 1;

has 'composable_validation_check_name' => (
    isa => "Bool",
    is => 'rw',
    default => 0
);

sub validate {
    my $self = shift;
    my $schema = shift;
    my $type = shift;
    my $list = shift;

    my $data;



    foreach my $p ($self->plugins()) {
        if ($type eq $p->name()) {
	     $data = $p->validate($schema, $list, $self);
	}
    }
    return $data;
}

1;
