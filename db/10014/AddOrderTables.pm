#!/usr/bin/env perl


=head1 NAME

  AddOrderTables

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


package AddOrderTables;

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

CREATE TABLE sgn_people.sp_order (
   sp_order_id serial primary key,
   order_from_id bigint references sgn_people.sp_person,
   order_to_id bigint references sgn_people.sp_person,
   order_status varchar(100),
   comments text,
   create_date varchar(100),
   completion_date varchar(100)
);

GRANT select,insert,update,delete ON sgn_people.sp_order TO web_usr;
GRANT USAGE ON sgn_people.sp_order_sp_order_id_seq TO web_usr;

CREATE TABLE sgn_people.sp_orderprop (
    sp_orderprop_id serial primary key,
    sp_order_id bigint references sgn_people.sp_order,
    type_id bigint references cvterm,
    value jsonb,
    rank int not null
);

GRANT select,insert,update,delete ON sgn_people.sp_orderprop TO web_usr;
GRANT USAGE ON sgn_people.sp_orderprop_sp_orderprop_id_seq TO web_usr;





EOSQL

print "You're done!\n";
}


####
1; #
####
