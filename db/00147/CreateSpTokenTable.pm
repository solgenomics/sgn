#!/usr/bin/env perl


=head1 NAME

 CreateSpTokenTable.pm

=head1 SYNOPSIS

mx-run CreateSpTokenTable [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

Creates the sgn_people.sp_token table
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR
Naftali Panitz<np298@cornell.edu>
Lukas Mueller

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package CreateSpTokenTable;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch creates the sgn_people.sp_token table.

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

CREATE TABLE sgn_people.sp_token (
   sp_token_id serial primary key,
   cookie_string text,
   last_access_time timestamp without time zone,
   source_ip_address varchar(64),
   sp_person_id bigint references sgn_people.sp_person
);

GRANT select, update, insert, delete  ON sgn_people.sp_token to postgres, web_usr;
GRANT usage on sequence sp_token_sp_token_id_seq to postgres, web_usr;



EOSQL

print "You're done!\n";
}


####
1; #
####
