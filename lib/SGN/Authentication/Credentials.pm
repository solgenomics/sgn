
=head1 NAME

SGN::Authentication::Credentials - a class providing credentials for the SGN Catalyst system

=head1 DESCRIPTION

Implemented according to Catalyst::Plugin::Authentication::Internals

=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>

=cut

use strict;
use warnings;

package SGN::Authentication::Credentials;

use SGN::Authentication::Store;
use SGN::Authentication::User;

sub new { 
    my $class = shift;
    my $config = shift;
    my $app = shift;
    my $realm = shift;
    
    my $self = bless {}, $class;
    $self->{config} = $config;
    $self->{app} = $app;
    $self->{realm} = $realm;

    
    return $self;
}


sub authenticate { 
    my $self = shift;
    my $c = shift;
    my $realm = shift;
    my $authinfo = shift;

    print STDERR "authenticate: Authenticating user: $authinfo->{username}\n";
    my $store = SGN::Authentication::Store->new();
    my $user = $store->find_user($authinfo, $c);

    return $user;

}

1;

