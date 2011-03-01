package AddUserRoles;

use Moose;
use 5.010;
extends 'CXGN::Metadata::Dbpatch';

sub init_patch {
    my $self=shift;
    my $name = __PACKAGE__;
    say "dbpatch name is $name";
    my $description = 'Add User Roles';
    my @previous_requested_patches = (); #ADD HERE

    $self->name($name);
    $self->description($description);
    $self->prereq(\@previous_requested_patches);

}

sub patch {
    my $self=shift;

    print "Executing the patch:\n " . $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print "\nExecuting the SQL commands.\n";

    $self->dbh->do(<<EOSQL);

CREATE TABLE sgn_people.sp_roles (
    sp_role_id serial primary key,
    name varchar(20)
  );

CREATE TABLE sgn_people.sp_person_roles (
    sp_person_role_id serial primary key,
    sp_person_id bigint references sgn_people.sp_person on delete cascade,
    sp_role_id bigint references sgn_people.sp_roles on delete cascade
  );

    INSERT INTO sgn_people.sp_roles(name) VALUES ('curator');
    INSERT INTO sgn_people.sp_roles(name) VALUES ('sequencer');
    INSERT INTO sgn_people.sp_roles(name) VALUES ('submitter');
    INSERT INTO sgn_people.sp_roles(name) VALUES ('user');

    INSERT INTO sgn_people.sp_person_roles (sp_role_id, sp_person_id)
       SELECT sp_role_id, sp_person_id
       FROM sgn_people.sp_person
       JOIN sgn_people.sp_roles ON (user_type=name);

    GRANT select, update, insert, delete  ON sgn_people.sp_roles to postgres, web_usr;
    GRANT select, update, insert, delete  ON sgn_people.sp_person_roles to postgres, web_usr;

    GRANT select, update, usage  ON sgn_people.sp_roles_sp_role_id_seq to postgres, web_usr;

    GRANT select, update, usage ON sgn_people.sp_person_roles_sp_person_role_id_seq to postgres, web_usr;

EOSQL

    say "You're done!";

}

1;
