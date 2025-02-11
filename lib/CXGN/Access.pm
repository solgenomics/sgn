
=head1 NAME

CXGN::Access - manage access rights in Breedbase

=head1 DESCRIPTION

=head2 Accessors

people_schema

role

resource

=head2 Resources

Currently planned resources are:

=item *

pedigrees

=item * 

genotypes

=item *

phenotypes

=item

wizard

=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>

=head2 Functions

=cut


package CXGN::Access;

use Moose;
use Data::Dumper;

has 'people_schema' => (isa => 'Ref', is => 'rw');
has 'role' => (isa => 'Str', is => 'rw');
has 'resource' => (isa => 'Str', is=> 'rw');



=head3 check_role()

   Arguments: optional role, optional resource
   (otherwise taken from object)
   Returns: privileges (list of strings) such as ("read", "write")

=cut

sub check_role {
    my $self = shift;
    my $role = shift || $self->role();
    my $resource = shift || $self->resource();

    my $q = "SELECT sp_access_level.name FROM sgn_people.sp_privilege join sgn_people.sp_access_level using(sp_access_level_id) where sp_role_id=(SELECT sp_role_id FROM sgn_people.sp_roles WHERE name=?) and sp_resource_id = (SELECT sp_resource_id FROM sgn_people.sp_resource where name=?)";
    my $h = $self->people_schema()->storage()->dbh()->prepare($q);
    $h->execute($role, $resource);

    my @privileges;
    while (my ($level) = $h->fetchrow_array()) {
	push @privileges, $level;
    }
    print STDERR "PRIVLEGES FOR $resource and $role are ". join(", ", @privileges)."\n";
    return @privileges;
}

=head3 check_user()

   Arguments: sp_person_id (integer), optional resource (string)
   Returns: true if user can access resource, false if not

=cut

sub check_user {
    my $self = shift;
    my $sp_person_id = shift;
    my $resource = shift || $self->resource();

    my $q = "SELECT sp_access_level.name FROM sgn_people.sp_privilege join sp_access_level using(sp_access_level_id) join sgn_people.sp_person_roles using(sp_role_id) where sp_resource_id = (SELECT sp_resource_id FROM sgn_people.sp_resource where name=?) and sgn_people.sp_person_roles.sp_person_id = ? ";
    my $h = $self->people_schema()->storage()->dbh()->prepare($q);
    $h->execute($resource, $sp_person_id);
    
    my @privileges;
    while (my ($level) = $h->fetchrow_array()) {
	push @privileges, $level;
    }
    
    print STDERR "PRIVLEGES FOR $resource and $sp_person_id are ". join(", ", @privileges)."\n";

    return @privileges;    
}

sub user_privileges {
    my $self = shift;
    my $sp_person_id = shift;
    my $resource = shift || $self->resource();

    my $q = "SELECT sp_access_level.name, require_ownership FROM sgn_people.sp_privilege join sp_access_level using(sp_access_level_id) join sgn_people.sp_person_roles using(sp_role_id) where sp_resource_id = (SELECT sp_resource_id FROM sgn_people.sp_resource where name=?) and sgn_people.sp_person_roles.sp_person_id = ? ";
    my $h = $self->people_schema()->storage()->dbh()->prepare($q);
    $h->execute($resource, $sp_person_id);
    
    my %privileges;
    while (my ($level, $require_ownership) = $h->fetchrow_array()) {
	$privileges{$level}= $require_ownership;
    }
    print STDERR "user_privileges for $resource: ".Dumper(\%privileges);
    return \%privileges;
    
}

=head3 grant()

   Arguments: $sp_person_id (integer), requested_role, resource 

=cut

sub grant {
    my $self = shift;
    my $sp_person_id = shift;
    my $requested_role = shift;
    my $resource = shift || $self->resource();

    my @privileges = $self->check_user($sp_person_id, $resource);

    if (grep { /$requested_role/ } @privileges) {
	return 1;
    }

    return 0;
}

=head3 privileges_table()

    Arguments: none
    Returns: table of privileges, a list of hashrefs containing:
          {
              privilege_id => $sp_privilege_id,
	      resource_id => $sp_resource_id,
	      resource => $resource,
	      access_level_id => $access_level_id,
	      access_level => $access_level,
	      role_id => $role_id,
	      role_name => $role_name,
	  };

=cut

sub privileges_table {
    my $self = shift;

    my $q = "SELECT sp_privilege.sp_privilege_id, sp_privilege.sp_resource_id, sp_resource.name, sp_access_level.sp_access_level_id, sp_access_level.name, sp_roles.sp_role_id, sp_roles.name FROM sgn_people.sp_privilege LEFT join sgn_people.sp_access_level using(sp_access_level_id) LEFT join sgn_people.sp_resource using(sp_resource_id) LEFT join  sgn_people.sp_roles using(sp_role_id) order by sp_resource.name";
    my $h =  $self->people_schema()->storage()->dbh()->prepare($q);
    $h->execute();
    my @data;
    while (my ($sp_privilege_id, $sp_resource_id, $resource, $access_level_id, $access_level, $role_id, $role_name) = $h->fetchrow_array()) {
	push @data,
	{
	    privilege_id => $sp_privilege_id,
	    resource_id => $sp_resource_id,
	    resource => $resource,
	    access_level_id => $access_level_id,
	    access_level => $access_level,
	    role_id => $role_id,
	    role_name => $role_name,
	};
    }	      
    return @data;
}

=head3 add_privilege($resource, $role, $access_level)

    Adds a privilege row

    Arguments: $resource (string), $role (string), $access_level (string)
               all args must be present in the respective tables

    Returns:   hashref with success => 1 on success, error => $error_string
               on error condition

=cut

sub add_privilege {
    my $self = shift;
    my $resource = shift;
    my $role = shift;
    my $access_level = shift;

    my $error = "";
       
    my $resource_row = $self->people_schema->resultset("SpResource")->find( { name => $resource });
    if (! $resource_row) {
	$error = "Resource $resource does not exist. ";
    }

    my $role_row = $self->people_schema->resultset("SpRole")->find( { name => $role});
    if (! $role_row) {
	$error .= "Role $role does not exist. ";
    }

    my $access_level_row = $self->people_schema->resultset("SpAccessLevel")->find( { name => $access_level });
    if (! $access_level_row) {
	$error .= "Access level $access_level does not exist. ";
    }

    my $row = {
	sp_role_id => $role_row->sp_role_id(),
	sp_access_level_id => $access_level_row->sp_access_level_id(),
	sp_resource_id => $resource_row->sp_resource_id(),
    };

    my $row = $self->people_schema->resultset("SpPrivilege")->find_or_create($row);

    if ($error) {
	return { error => $error };
    }

    return { success => 1, privilege_id => $row->sp_privilege_id() };
}

=head3 delete_privilege($privilege_id)

    Deletes the privilege with id $privilege_id
    Argument: $privilege_id (integer)
    Returns:  hashref with success => 1 if success, error => $error_string 
              otherwise

=cut

sub delete_privilege {
    my $self = shift;
    my $privilege_id = shift;

    my $row = $self->people_schema()->resultset("SpPrivilege")->find( { sp_privilege_id => $privilege_id });

    if (! $row) {
	return { error => 'The specified privilege_id ($privilge_id) does not exist and could not be deleted.' };
    }

    $row->delete();
    
    return { success => 1 };

}

=head3 add_resource()

    Argument: resource name
    Returns:  resource_id

=cut

sub add_resource {
    my $self = shift;
    my $name = shift;

    my $row = $self->people_schema()->resultset('SpResource')->
	find_or_create( { name => $name });

    return $row->sp_resource_id();
}

sub delete_resource {
    my $self = shift;
    my $resource_id = shift;

    my $row = $self->people_schema()->resultset('SpResource')
	->find({ sp_resource_id => $resource_id });

    if ($row) { 
	$row->delete();
	return { success => 1 };
    }

    return { error => 'The resource with id $resource_id does not exist and could not be deleted.' };
}

sub add_access_level {
    my $self = shift;
    my $name = shift;

    my $row = $self->people_schema()->resultset('SpAccessLevel')->
	find_or_create( { name => $name });

    return $row->sp_access_level_id();
}
    
sub delete_access_level {
    my $self = shift;
    my $access_level_id = shift;

    my $row = $self->people_schema()->resultset('SpAccessLevel')
	->find({ sp_access_level_id => $access_level_id });

    if ($row) { 
	$row->delete();
	return { success => 1 };
    }

    return { error => 'The access level with id $access_level_id does not exist and could not be deleted.' };

}


1;
