
=head1 NAME

CXGN::People::Roles - helper class for people's roles

=head1 SYNOPSYS

 my $person_roles = CXGN::Person::Roles->new( { people_schema => $schema } );

 etc.

=head1 AUTHOR

Nicolas Morales <nm529@cornell.edu>

=head1 METHODS

=cut

package CXGN::People::Roles;

use Moose;
use Try::Tiny;
use SGN::Model::Cvterm;
use Data::Dumper;
use Text::Unidecode;
use List::MoreUtils qw /any /;

has 'bcs_schema' => (  # deprecated
    isa => 'Bio::Chado::Schema',
    is => 'rw',
    );

has 'people_schema' => (
    isa => 'CXGN::People::Schema',
    is => 'rw',
    );

sub add_sp_role {
	my $self = shift;
	my $name = shift;
	my $dbh = $self->people_schema->storage->dbh;

	my $q="SELECT sp_role_id FROM sgn_people.sp_roles where name=?;";
	my $sth = $dbh->prepare($q);
	$sth->execute($name);
	my $count = $sth->rows;
	if ($count > 0){
		print STDERR "A role with that name already exists.\n";
		return;
	}
	eval {
		my $q="INSERT INTO sgn_people.sp_roles (name) VALUES (?) RETURNING sp_role_id;";
		my $sth = $dbh->prepare($q);
		$sth->execute($name);
		my ($sp_role_id) = $sth->fetchrow_array();
		return $sp_role_id;
	};
	if ($@) {
		die "An error occurred while storing a new role. ($@)";
	}
}

sub update_sp_role {
    my $self = shift;
    my $new_name = shift;
    my $old_name = shift;
    my $dbh = $self->people_schema->storage->dbh;

    my $q="SELECT sp_role_id FROM sgn_people.sp_roles where name=?;";
    my $sth = $dbh->prepare($q);
    $sth->execute($old_name);
    my $count = $sth->rows;
    if ($count < 1){
	print STDERR "No role with that name exists.\n";
	return;
    }
    eval {
	my $q="UPDATE sgn_people.sp_roles SET name = ? WHERE name = ?;";
	my $sth = $dbh->prepare($q);
	$sth->execute($new_name,$old_name);
    };
    if ($@) {
	return "An error occurred while updating an existing role. ($@)";
    }
}

sub delete_sp_role {
    my $self = shift;
    my $sp_role_name = shift;

    my $role = $self->people_schema()->resultset('SpRole')->find( { name => $sp_role_name });

    if (! $role) {
	return "The role ($sp_role_name) you are trying to delete does not exist";
    }
    # check whether the role is assigned to anybody
    # if so, do not allow deletion
    #
    my $assigned = $self->people_schema->resultset('SpPersonRole')->find( { sp_role_id => $role->sp_role_id() });

    if ($assigned) {
	return "This role is currently being in use and cannot be deleted.";
    }

    # check if role matches a breeding program name
    #
    my $bp = $self->bcs_schema()->resultset('Project::Project')->find( { name => $role->name() });

    if ($bp) {
	return "The role you would like to delete is associated with a breeding program. You need to remove the breeding program to delete this role.";
    }

    my $privilege_row = $self->people_schema->resultset('SpPrivilege')->find( { sp_role_id => $role->sp_role_id() });
    $privilege_row->delete();
    $role->delete();
    return 0;

}


sub role_hash {
    my $self = shift;
    my %roles;
    my $rs1 = $self->people_schema()->resultset("SpRole")->search( { } );
    while (my $row = $rs1->next()) {
	$roles{$row->sp_role_id} = $row->name();
    }
    return %roles;
}

sub list_roles {
    my $self = shift;
    my $sp_person_id = shift;

    my $rs2;

    if ($sp_person_id) {
	$rs2 = $self->people_schema->resultset("SpPerson")->search(
	    { censor => 0, disabled => undef, 'me.sp_person_id' => $sp_person_id },
	    { join => 'sp_person_roles',
	      '+select' => ['sp_person_roles.sp_role_id', 'sp_person_roles.sp_person_role_id' ],
	      '+as'     => ['sp_role_id', 'sp_person_role_id' ],
	      order_by => 'sp_role_id' });
    }
    else {
	$rs2 = $self->people_schema->resultset("SpPerson")->search(
	    { censor => 0, disabled => undef },
	    { join => 'sp_person_roles',
	      '+select' => ['sp_person_roles.sp_role_id', 'sp_person_roles.sp_person_role_id' ],
	      '+as'     => ['sp_role_id', 'sp_person_role_id' ],
	      order_by => 'sp_role_id' });
    }

    my @rows;

    while (my $row= $rs2->next()) {
	push @rows, $row;
    }

    return @rows;
}

sub get_breeding_program_roles {
	my $self = shift;
	my $ascii_chars = shift;
	my $dbh = $self->people_schema->storage->dbh;
	my @breeding_program_roles;
	my $q="SELECT username, sp_person_id, name, censor FROM sgn_people.sp_person
	JOIN sgn_people.sp_person_roles using(sp_person_id)
	JOIN sgn_people.sp_roles using(sp_role_id)
	where  disabled IS NULL and sp_person.censor = 0";
	my $sth = $dbh->prepare($q);
	$sth->execute();
	while (my ($username, $sp_person_id, $sp_role, $censor) = $sth->fetchrow_array ) {
	    if ($ascii_chars) {
		$username = unidecode($username);
	    }
		push(@breeding_program_roles, [$username, $sp_person_id, $sp_role, $censor] );
	}

	print STDERR Dumper \@breeding_program_roles;
	return \@breeding_program_roles;
}

sub add_sp_person_role {
	my $self = shift;
	my $sp_person_id = shift;
	my $sp_role_id = shift;
	my $dbh = $self->people_schema->storage->dbh;
	my $q = "INSERT INTO sgn_people.sp_person_roles (sp_person_id, sp_role_id) VALUES (?,?);";
	my $sth = $dbh->prepare($q);
	$sth->execute($sp_person_id, $sp_role_id);
	return;
}

sub get_sp_persons {
	my $self = shift;
	my $dbh = $self->people_schema->storage->dbh;
	my @sp_persons;
	my $q="SELECT username, sp_person_id FROM sgn_people.sp_person WHERE disabled IS NULL and censor = 0 ORDER BY username ASC;";
	my $sth = $dbh->prepare($q);
	$sth->execute();
	while (my ($username, $sp_person_id) = $sth->fetchrow_array ) {
		push(@sp_persons, [$username, $sp_person_id] );
	}
	return \@sp_persons;
}

sub get_sp_roles {
	my $self = shift;
	my $dbh = $self->people_schema->storage->dbh;
	my @sp_roles;
	my $q="SELECT name, sp_role_id FROM sgn_people.sp_roles;";
	my $sth = $dbh->prepare($q);
	$sth->execute();
	while (my ($name, $sp_role_id) = $sth->fetchrow_array ) {
		push(@sp_roles, [$name, $sp_role_id] );
	}
	return \@sp_roles;
}

sub get_non_breeding_program_roles {
	my $self = shift;
	my $dbh = $self->people_schema->storage->dbh;
	my @sp_roles;
	my $q="SELECT name, sp_role_id FROM sgn_people.sp_roles where name not in (SELECT name from project)";
	my $sth = $dbh->prepare($q);
	$sth->execute();
	while (my ($name, $sp_role_id) = $sth->fetchrow_array ) {
		push(@sp_roles, [$sp_role_id, $name] );
	}
	return @sp_roles;
}



sub check_sp_roles {
	my $self = shift;
	my $user_roles = shift;
	my $program_name = shift;
    my %check_roles;
	if (!any { $_ eq "curator" || $_ eq "submitter" } (@$user_roles)){
        $check_roles{'invalid_role'} = 1;
    }

    my %has_roles = ();
    map { $has_roles{$_} = 1; } @$user_roles;

    if (! ( (exists($has_roles{$program_name}) && exists($has_roles{submitter})) || exists($has_roles{curator}))) {
		$check_roles{'invalid_program'} = 1;
    }

    return \%check_roles;
}


1;
