package SGN::Role::Site::DBIC;
use 5.10.0;

use Moose::Role;
use namespace::autoclean;

use Carp;
use Data::Dumper;
use Class::Load ':all';

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
    my ( $class, $schema_name, $profile_name, $sp_person_id) = @_;
    #my $self = shift;
    print STDERR "sp_person_id passed to DBIC Schema: $sp_person_id \n";
    $class = ref $class if ref $class;
    $schema_name or croak "must provide a schema package name to dbic_schema";
    #Class::MOP::load_class( $schema_name );
    load_class( $schema_name );
    state %schema_cache;
    
    return $schema_cache{$class}{$profile_name || ''}{$schema_name} ||= do {
        my $profile = $class->dbc_profile( $profile_name );
        #print STDERR "profile: ".Dumper($profile)."\n";
        #my $sp_person_id = $profile -> user -> get_object() -> get_sp_person_id;
        $schema_name->connect(
            @{$profile}{qw| dsn user password attributes |},
            { on_connect_call => sub { $class->ensure_dbh_search_path_is_set(my $dbh = shift->dbh ) ; 

                
                #my $delete_old_table_query = "DROP TABLE IF EXISTS logged_in_user";
                #my $delete = $dbh -> do($delete_old_table_query);
                my $q = "CREATE temporary table IF NOT EXISTS logged_in_user (sp_person_id bigint)";
                my $create_handle = $dbh -> do($q);
                #my $count_q = "select count(*) from logged_in_user";
                #my $count_h = $dbh -> prepare($count_q);
                #$count_h -> execute();
                #my ($count) = $count_h->fetchrow_array();
                #print STDERR "count: $count \n";
                my $insert_query = "INSERT INTO logged_in_user (sp_person_id) VALUES (?)";
                my $insert_handle = $dbh -> prepare($insert_query);
                $insert_handle -> execute($sp_person_id);
               

            
            }, },
            
            
            #on_connect_do => [
            #    "CREATE temporary table IF NOT EXISTS logged_in_user (sp_person_id bigint)",
             #   "INSERT INTO logged_in_user (sp_person_id) VALUES ($sp_person_id)",
            #]
            
            
            
           )
    };
}

1;

                #my $dbh = $class->dbc->dbh;
                #$dbh->do("CREATE temporary table IF NOT EXISTS logged_in_user (sp_person_id bigint)");
                #my $insert_query = "INSERT INTO logged_in_user (sp_person_id) VALUES (?)";
                #my $insert_handle = $dbh->prepare($insert_query);
                #my $sp_person_id = $class -> user -> get_object() -> get_sp_person_id;
                #$insert_handle->execute($sp_person_id);
