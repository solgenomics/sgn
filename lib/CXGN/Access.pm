package CXGN::Access;

use Moose;

has 'people_schema' => (isa => 'Ref', is => 'rw');
has 'role' => (isa => 'Str', is => 'rw');
has 'resource' => (isa => 'Str', is=> 'rw');

sub check_role {
    my $self = shift;
    my $role = shift || $self->role();
    my $resource = shift || $self->resource();

    my $q = "SELECT sp_access_level.name FROM sgn_people.sp_privilege join sp_access_level using(sp_access_level_id) where sp_role_id=(SELECT sp_role_id FROM sgn_people.sp_roles WHERE name=?) and sp_resource_id = (SELECT sp_resource_id FROM sgn_people.sp_resource where name=?)";
    my $h = $self->people_schema()->storage()->dbh()->prepare($q);
    $h->execute($role, $resource);

    my @privileges;
    while (my ($level) = $h->fetchrow_array()) {
	push @privileges, $level;
    }
    print STDERR "PRIVLEGES FOR $resource and $role are ". join(", ", @privileges)."\n";
    return @privileges;
}

sub check_user {
    my $self = shift;
    my $resource = shift;
    my $sp_person_id = shift;
    
    my $q = "SELECT sp_access_level.name FROM sgn_people.sp_privilege join sp_access_level using(sp_access_level_id) join sgn_people.sp_person_roles using(sp_role_id) where sp_resource_id = (SELECT sp_resource_id FROM sgn_people.sp_resource where name=? and sp_person_roles.sp_person_id=?)";
    my $h = $self->people_schema()->storage()->dbh()->prepare($q);
    $h->execute($resource, $sp_person_id);

    my @privileges;
    while (my ($level) = $h->fetchrow_array()) {
	push @privileges, $level;
    }
    print STDERR "PRIVLEGES FOR $resource and $sp_person_id are ". join(", ", @privileges)."\n";
    return @privileges;
}

    

1;
