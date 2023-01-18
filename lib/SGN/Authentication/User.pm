=head1 NAME

SGN::Authentication::User - a Catalyst compatible user class

=head1 DESCRIPTION

Implemented according to Catalyst::Plugin::Authentication::Internals

=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>

=cut

use strict;
use warnings;

package SGN::Authentication::User;

use base "Catalyst::Authentication::User";

sub id {
    my $self = shift;
    return $self->{user}->get_username();
}

sub supported_features {
    my $self = shift;
    return { roles =>1,  self_check=>1};
}

sub get_object {
    my $self = shift;
    my $c = shift;
    return $self->{user};
}

sub set_object {
    my $self = shift;
    $self->{user} = shift;
}

sub roles {
    my $self = shift;
    return $self->{user}->get_roles();
}

sub check_roles {
    my $self = shift;
    my @roles = @_;
    my %has_roles = ();
    map { $has_roles{$_} = 1; } $self->roles();

    foreach my $r (@roles) {
        if (!exists($has_roles{$r})) {
            return 0;
        }
    }
    return 1;
}

1;
