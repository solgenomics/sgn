
package CXGN::Phenotype::ParseUpload;

use Moose;

use Module::Pluggable require => 1;

sub validate {
    my $self = shift;
    my $c = shift;
    my $type;
    my $filename = shift;
    my $validate_result;

    foreach my $p ($self->plugins()) {
        if ($type eq $p->name()) {
	     $validate_result = $p->validate($c, $filename);
	}
    }
    return;
}

sub parse {
    my $self = shift;
    my $c = shift;
    my $type;
    my $filename = shift;
    my $parse_result;

    foreach my $p ($self->plugins()) {
        if ($type eq $p->name()) {
	     $parse_result = $p->parse($c, $filename);
	}
    }
    return;
}

1;
