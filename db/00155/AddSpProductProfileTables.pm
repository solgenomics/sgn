#!/usr/bin/env perl


=head1 NAME

  AddSpProductProfileTables

=head1 SYNOPSIS

mx-run ThisPackageName [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This is a test dummy patch.
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

 Naama Menda<nm249@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddSpProductProfileTables;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
Description of this patch goes here

has '+prereq' => (
    default => sub {
        [],
    },
  );

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    $self->dbh->do(<<EOSQL);
--do your SQL here
--

CREATE TABLE sgn_people.sp_product_profile (
    sp_product_profile_id serial primary key,
    sp_stage_gate_id bigint references sgn_people.
    sp_stage_gate, name varchar(100),
    scope varchar(100),
    sp_person_id bigint references sgn_people.sp_person,
    create_date timestamp without time zone default now(),
    modified_date timestamp without time zone default now()
);

GRANT select,insert,update,delete ON sgn_people.sp_product_profile TO web_usr;
GRANT USAGE ON sgn_people.sp_product_profile_sp_product_profile_id_seq TO web_usr;

CREATE TABLE sgn_people.sp_product_profileprop (
    sp_product_profileprop_id serial primary key,
    sp_product_profile_id bigint references sgn_people.sp_product_profile,
    type_id bigint references cvterm,
    value jsonb,
    rank bigint
);

GRANT select,insert,update,delete ON sgn_people.sp_product_profileprop TO web_usr;
GRANT USAGE ON sgn_people.sp_product_profileprop_sp_product_profileprop_id_seq TO web_usr;

EOSQL

print "You're done!\n";
}


####
1; #
####
