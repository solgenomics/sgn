
package CXGN::List::FuzzySearch;

use Moose;

use Module::Pluggable require => 1;

sub fuzzysearch {
    my $self = shift;
    my $schema = shift;
    my $type = shift;
    my $list = shift;

    my $data;

    foreach my $p ($self->plugins()) {
        if ($type eq $p->name()) {
            $data = $p->fuzzysearch($schema, $list, $self);
        }
    }
    return $data;
}

1;
