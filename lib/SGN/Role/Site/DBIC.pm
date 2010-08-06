package SGN::Role::Site::DBIC;

use Moose::Role;
use namespace::autoclean;

use Carp;

requires
    'dbc_profile',
    'ensure_dbh_search_path_is_set',
    ;


=head2 dbic_schema

  Usage: my $schema = $c->dbic_schema( 'Schema::Package', 'connection_name' );
  Desc : get a L<DBIx::Class::Schema> with the proper connection
         parameters for the given connection name
  Args : L<DBIx::Class> schema package name,
         (optional) connection name to use
  Ret  : schema object
  Side Effects: dies on failure

=cut

sub dbic_schema {
    my ( $self, $schema_name, $profile_name ) = @_;

    $schema_name or croak "must provide a schema package name to dbic_schema";
    Class::MOP::load_class( $schema_name );

    my $profile = $self->dbc_profile( $profile_name );

    return $schema_name->connect(
        @{$profile}{qw| dsn user password attributes |},
        { on_connect_call => sub { $self->ensure_dbh_search_path_is_set( shift->dbh ) } },
       );
}

1;

