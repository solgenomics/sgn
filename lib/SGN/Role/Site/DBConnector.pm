package SGN::Role::Site::DBConnector;
use 5.10.0;

use Moose::Role;
use namespace::autoclean;

use Carp;
use CXGN::DB::Connection;
use Storable;

requires qw(
            config
           );

=head2 dbc

  Usage: $c->dbc('profile_name')->dbh->do($sql)
  Desc : get a L<DBIx::Connector> connection for the
         given profile name, or from profile 'default' if not given
  Args : optional profile name
  Ret  : a L<DBIx::Connector> connection
  Side Effects: uses L<DBIx::Connector> to manage database connections.
                calling dbh() on the given connection will create a new
                database handle on the connection if necessary

  Example:

     # straightforward use of a dbh
     $c->dbc
       ->dbh
       ->do($sql);

     # faster way to do the same thing.  be careful though, read the
     # DBIx::Connector::run() documentation before doing this
     $c->dbc->run( fixup => sub { $_->do($sql) });

     # do something in a transaction
     $c->dbc->txn( ping  => sub {
         my $dbh = shift;
         # do some stuff...
     });

=cut

sub _connections {
    my ($class) = @_;
    $class = ref $class if ref $class;
    state %connections;
    $connections{$class} ||= {};
}

sub dbc {
    my ( $self, $profile_name ) = @_;
    $profile_name ||= 'default';

    my $profile = $self->dbc_profile( $profile_name );

    my $conn = $self->_connections->{$profile_name} ||=
	SGN::Role::Site::DBConnector::Connector->new( @{$profile}{qw| dsn user password attributes |} );

    return $conn;
}
sub dbc_profile {
    my ( $self, $profile_name ) = @_;
    $profile_name ||= 'default';

    $self->_build_compatibility_profiles(); #< make sure our compatibility profiles are set

    my $profile = $self->config->{'DatabaseConnection'}->{$profile_name}
	or croak "connection profile '$profile_name' not defined";

    # generate the string to set as the search path for this profile,
    # if necessary
    $profile->{'attributes'}{'private_search_path_string'}
	||= $profile->{search_path} ? join ',',map qq|"$_"|, @{$profile->{'search_path'}}  :
	                              'public';

    return $profile;
}

# called on database handles to make sure they are setting the right
# search path
sub ensure_dbh_search_path_is_set {
    my ($self,$dbh) = @_;
    return $dbh if $dbh->{private_search_path_is_set};

    $dbh->do("SET search_path TO $dbh->{private_search_path_string}");
    #warn "SET search_path TO $dbh->{private_search_path_string}";

    $dbh->{private_search_path_is_set} = 1;
    return $dbh;
}


# generates 'default' and 'sgn_chado' profiles that are compatibile
# with the legacy CXGN::DB::Connection
sub _build_compatibility_profiles {
    my ($self) = @_;

    # make a default profile
    $self->config->{'DatabaseConnection'}->{'default'} ||= do {
	require CXGN::DB::Connection;
	my %conn;
	@conn{qw| dsn user password attributes |} =
            CXGN::DB::Connection->new_no_connect({ config => $self->config })
                                ->get_connection_parameters;

        $conn{attributes}{AutoCommit} = 1;
	$conn{attributes}{pg_enable_utf8} = 1;

	$conn{search_path} = $self->config->{'dbsearchpath'} || ['public'];
	\%conn
    };

    # make a second profile 'sgn_chado' that removes the sgn search path
    # from the beginning
    $self->config->{'DatabaseConnection'}->{'sgn_chado'} ||= do {
        my $c = Storable::dclone( $self->config->{'DatabaseConnection'}->{'default'} );
        if( $c->{search_path}->[0] eq 'sgn' ) {
            push @{$c->{search_path}}, shift @{$c->{search_path}};
        }
        $c
    }
}


{ # tiny DBIx::Connector subclass that makes sure search paths are set
  # on database handles before returning them
  package SGN::Role::Site::DBConnector::Connector;
  use strict;
  use warnings FATAL => 'all';
  use base 'DBIx::Connector';

  sub dbh {
      my $dbh = shift->SUPER::dbh(@_);
      SGN::Role::Site::DBConnector->ensure_dbh_search_path_is_set( $dbh );
      return $dbh;
  }
}


1;
