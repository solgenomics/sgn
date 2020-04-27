#!/usr/bin/env perl


=head1 NAME

 EncodePasswords.pm

=head1 SYNOPSIS

mx-run EncodePasswords [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

Running this script will encode the passwords with the BF algorithm, using salt.
NOTE that this script should not be forced (-F) because IT SHOULD NEVER BE RUN MORE THAN ONCE!!!

=head1 AUTHOR

 Naama Menda<nm249@cornell.edu>
 Lukas Mueller <lam87@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package EncodePasswords;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
Description of this patch goes here

has '+prereq' => (
    default => sub {
        [ ],
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
CREATE EXTENSION IF NOT EXISTS pgcrypto;
UPDATE sgn_people.sp_person SET password=crypt(sgn_people.sp_person.password, gen_salt('bf'));


EOSQL

print "You're done!\n";
}


####
1; #
####
