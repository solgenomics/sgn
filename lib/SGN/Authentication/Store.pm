
=head1 NAME

SGN::Authentication::Store - a Catalyst compatible store class

=head1 DESCRIPTION

Implemented according to Catalyst::Plugin::Authentication::Internals

=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>

=cut

use strict;
use warnings;

package SGN::Authentication::Store;

use SGN::Authentication::Store;
use SGN::Authentication::User;
use CXGN::DB::Connection;
use CXGN::People::Person;


sub new { 
    my $class = shift;
    my $c = shift;
    my $app = shift;
    my $realm = shift;

    my $self = bless {}, $class;

    $self->{c} = $c;
    $self->{app} = $app;
    $self->{realm} = $realm;
    $self->{dbh} = CXGN::DB::Connection->new();
    return $self;

}


sub find_user { 
    my $self = shift;
    my $authinfo = shift;
    my $c = shift;

    print STDERR "find_user: $authinfo->{username}\n";
    my $sp_person_id = CXGN::People::Person->get_person_by_username($self->{dbh}, $authinfo->{username});

    my $user;
    my $sp_person = CXGN::People::Person->new($self->{dbh}, $sp_person_id);
    if (ref($sp_person) eq 'CXGN::People::Person') { 
	print STDERR "Obtained sp_person ".$sp_person->get_sp_person_id()."\n";
	my $user = SGN::Authentication::User->new();
    
	print STDERR "USER ".$sp_person->get_username()." FOUND!\n";
	$user->set_object($sp_person);
	return $user;
    }
    else { 
	print STDERR "USER $authinfo->{username} NOT FOUND!\n";
    }

    return undef;
}

1;
