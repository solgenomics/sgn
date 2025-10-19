
=head1 NAME

CXGN::Access - manage access rights in Breedbase

=head1 DESCRIPTION

The Breedbase Access system provides fine-tuned access to the system through roles and privileges. The database is divided into different resources, for each of which access privileges can be defined. The current resources that are defined are privileges, pedigrees, phenotyping, genotyping, and trials.

=encoding UTF-8

 ┌──────────────────┬───────────────────────┬───────────────────────────────────┐
 │ Resource         │ Context               │ Access Levels                     │
 │                  │                       │                                   │
 ├──────────────────┼───────────────────────┼───────────────────────────────────┤
 │ privileges       │ functionality related │ read, write                       │
 │                  │ to how the system can │                                   │
 │                  │ be accessed.          │                                   │
 ├──────────────────┼───────────────────────┼───────────────────────────────────┤
 │ pedigrees        │ access to pedigree    │ read, write, match_owner          │
 │                  │ information           │                                   │
 ├──────────────────┼───────────────────────┼───────────────────────────────────┤
 │ phenotyping      │ access to phenotyping │ read, write, match_owner,         │
 │                  │ information           │ match_breeding_program            │
 ├──────────────────┼───────────────────────┼───────────────────────────────────┤
 │ genotyping       │ access to genotyping  │ read, write, match_owner          │
 │                  │ information           │ match_breeding_program            │
 ├──────────────────┼───────────────────────┼───────────────────────────────────┤
 │ trials           │ generating trials,    │ read, write,                      │
 │                  │ layouts, modifying    │ match_breeding_program            │
 │                  │ trial layouts         │                                   │
 ├──────────────────┼───────────────────────┼───────────────────────────────────┤
 │ crossing         │ generating crossing   │ read, write,                      │
 │                  │ projects, adding      │ match_breeding_program            │
 │                  │ crosses               │                                   │
 ├──────────────────┼───────────────────────┼───────────────────────────────────┤
 │ loci             │ creating/modifying    │ read, write, match_owner          │
 │                  │ locus pages           │                                   │
 ├──────────────────┼───────────────────────┼───────────────────────────────────┤
 │ community        │ forum, calendar       │ read, write, match_owner          │
 └──────────────────┴───────────────────────┴───────────────────────────────────┘



=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>

=head1 FUNCTIONS

=head1 Accessors

people_schema()

role()

resource()

=head1 Other functions
=cut


package CXGN::Access;

use Moose;
use List::Util qw| any |;
use CXGN::Login;
use Data::Dumper;
use CXGN::People::Schema;

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

    my $q = "SELECT sp_access_level.name, require_ownership, require_breeding_program FROM sgn_people.sp_privilege join sp_access_level using(sp_access_level_id) join sgn_people.sp_person_roles using(sp_role_id) where sp_resource_id = (SELECT sp_resource_id FROM sgn_people.sp_resource where name=?) and sgn_people.sp_person_roles.sp_person_id = ? ";
    my $h = $self->people_schema()->storage()->dbh()->prepare($q);
    $h->execute($resource, $sp_person_id);
    
    my %privileges;
    while (my ($level, $require_ownership, $require_breeding_program) = $h->fetchrow_array()) {
	$privileges{$level}->{require_ownership} =  $require_ownership;
	$privileges{$level}->{require_breeding_program} = $require_breeding_program;
    }
    print STDERR "user_privileges for $resource: ".Dumper(\%privileges);
    return \%privileges;
    
}

sub check_ownership {
    my $self = shift;
    my $sp_person_id = shift;
    my $resource = shift || $self->resource();
    my $access_level = shift;
    my $owner_id = shift;
    my $object_breeding_program_ids = shift;

    # breeding_program_ids can also be a scalar
    #
    if (! ref($object_breeding_program_ids) && defined($object_breeding_program_ids)) {
	$object_breeding_program_ids = [ $object_breeding_program_ids ];
    }
    my $privileges = $self->user_privileges($sp_person_id, $resource);

    my $require_ownership = $privileges->{$access_level}->{require_ownership};
    my $require_breeding_program = $privileges->{$access_level}->{require_breeding_program};
    
    my $ownership_checks_out;
    my $bps_checks_out;
    
    if ($require_ownership) {
	print STDERR "OWNERSHIP IS REQUIRED!\n";
	if ($owner_id == $sp_person_id) {
	    print STDERR "Ownership checks out\n";
	    $ownership_checks_out = 1;
	}
    }

    my @user_breeding_program_info = $self->get_breeding_program_ids_for_user($sp_person_id);
    my @user_breeding_program_ids = map { $_->[0] } @user_breeding_program_info;
    
    print STDERR "BP INFO: ".Dumper(\@user_breeding_program_info);
    
    if ($require_breeding_program) {
	# user has to be associated to all breeding programs in the list
	#
	my $match_count = 0;
	print STDERR "BREEDING PROGRAM IS REQUIRED! (required breeding program ids: ". join(", ", @user_breeding_program_ids)."\n";
	foreach my $bp_id (@$object_breeding_program_ids) { 
	    if (any { $_ == $bp_id } @user_breeding_program_ids ) {
		print STDERR "Breeding program checks out\n";
		$match_count++;
	    }
	}
	
	if ($match_count == @$object_breeding_program_ids) {
	    $bps_checks_out = 1;
	}
    }

    if (!$require_ownership && !$require_breeding_program) {
	# if either aren't required we can return 1
	print STDERR "Ownership & bp constraints not required... returning 1\n";
	return 1;
    }
    
    if ($require_ownership && $require_breeding_program) {
	return $ownership_checks_out && $bps_checks_out;
    }

    if ($require_ownership) {
	return $ownership_checks_out;
    }

    if ($require_breeding_program) {
	return $bps_checks_out;
    }
}

=head3 get_breeding_program_ids_for_user()

   Desc: get the breeding program ids the user is associated with; output can be used
         with the grant function

   Params: an sp_person_id

   Returns: a list of breeding_program ids the user is associated with. Other roles are
         excluded from the list.

=cut

sub get_breeding_program_ids_for_user {
    my $self = shift;
    my $sp_person_id = shift;

    my $q = "SELECT distinct(project_id), project.name FROM project join projectprop using(project_id) join cvterm on (projectprop.type_id=cvterm_id) join sgn_people.sp_roles on(project.name=sp_roles.name)  join sgn_people.sp_person_roles using(sp_role_id) where  sp_person_roles.sp_person_id = ?";
    my $h = $self->people_schema()->storage()->dbh()->prepare($q);
    $h->execute($sp_person_id);

    my @role_info;
    while (my ($id, $name) = $h->fetchrow_array()) {
	push @role_info, [ $id, $name ];
    }

    return @role_info;
}
	

=head3 grant()

   Arguments: $sp_person_id (integer), requested_role, resource, owner_id, breeding_program_id 

=cut

sub grant {
    my $self = shift;
    my $sp_person_id = shift;
    my $access_level = shift;
    my $resource = shift || $self->resource();
    my $owner_id = shift;
    my $breeding_program_ids = shift;

    my @privileges = $self->check_user($sp_person_id, $resource);

    # not logged in - no grant!
    if (! $sp_person_id) {
	return 0;
    }
    
    # do not allow anything if no privileges are set
    #
    if (!@privileges) {
	return 0;
    }    
    
    my $ownerships_check_out = $self->check_ownership($sp_person_id, $resource, $access_level, $owner_id, $breeding_program_ids);

    print STDERR "Ownerships check: $ownerships_check_out\n";
    
    my $privileges_check_out;
    
    if (grep { /$access_level/ } @privileges) {
	print STDERR "Privileges check out\n";
	$privileges_check_out = 1;
    }

    return $privileges_check_out && $ownerships_check_out;
}

=head3 denied()

   Arguments: $sp_person_id, requested role, resource, owner_id, breeding_program_id
   Summary: the opposite of grant
   Returns: an error message string if denied, 0 otherwise

=cut

sub denied {
    my $self = shift;
    my $sp_person_id = shift;
    my $access_level = shift;
    my $resource = shift || $self->resource();
    my $owner_id = shift;
    my $breeding_program_ids = shift;

    my @privileges = $self->check_user($sp_person_id, $resource);

    # do not allow anything if no privileges are set
    #
    my $denied = 0;

    if (! $sp_person_id) {
	return "Login required for this activity. ";
    }
    if (!@privileges) {
	$denied = "No privileges set for this activity. "
    }
		
    my $ownerships_check_out = $self->check_ownership($sp_person_id, $resource, $access_level, $owner_id, $breeding_program_ids);

    print STDERR "Ownerships check: $ownerships_check_out\n";
    
    my $privileges_check_out;
    
    if (grep { /$access_level/ } @privileges) {
	print STDERR "Privileges check out ".Dumper(\@privileges)."\n";
	$privileges_check_out = 1;
    }

    if (! $privileges_check_out ) { $denied .= "Required privileges not available."; }
    if (! $ownerships_check_out ) { $denied .= "Ownerships do not match."; }
	
    return $denied;
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

    my $row;
    if (! $error) { 
	$row = {
	    sp_role_id => $role_row->sp_role_id(),
	    sp_access_level_id => $access_level_row->sp_access_level_id(),
	    sp_resource_id => $resource_row->sp_resource_id(),
	};
	
	$row = $self->people_schema->resultset("SpPrivilege")->find_or_create($row);
    }

    if ($error) {
	return { error => $error };
    }

    my $privilege_id;
    if (ref($row)) { $privilege_id = $row->sp_privilege_id(); }
    return { success => 1, privilege_id => $privilege_id };
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

=head2 add_resource()

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

=head2 delete_resource

=cut

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

=head2 add_access_level()

=cut

sub add_access_level {
    my $self = shift;
    my $name = shift;

    my $row = $self->people_schema()->resultset('SpAccessLevel')->
	find_or_create( { name => $name });

    return $row->sp_access_level_id();
}

=head2 delete_access_level()

=cut

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
