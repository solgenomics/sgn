package SGN::Authentication::Credentials;

use strict;
use warnings;
use SGN::Authentication::Store;
use SGN::Authentication::User;

=head1 NAME

SGN::Authentication::Credentials - a class providing credentials for the SGN Catalyst system

=head1 DESCRIPTION

Implemented according to Catalyst::Plugin::Authentication::Internals

=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>

=cut

sub new {
    my ($class, $config, $app, $realm) = @_;

    my $self = bless {}, $class;

    $self->{config} = $config;
    $self->{app}    = $app;
    $self->{realm}  = $realm;

    return $self;
}

sub authenticate {
    my $self = shift;
    my $c = shift;
    my $realm = shift;
    my $authinfo = shift;

    $c->log->debug("authenticate: Authenticating user: $authinfo->{username}") if $c->debug;
    my $store = SGN::Authentication::Store->new();
    my $user = $store->find_user($authinfo, $c);

    return $user;

}

1;
