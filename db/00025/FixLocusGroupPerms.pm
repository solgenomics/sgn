#!/usr/bin/env perl


=head1 NAME

 FixLocusGroupPerms.pm

=head1 SYNOPSIS

mx-run FixLocusGroupPerms [options] -H hostname -D dbname -u username [-F]

This patch is needed for running the tests (removal of test user).

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

 Lukas Mueller <lam87@cornell.edu>
 

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package FixLocusGroupPerms;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
Description of this patch goes here

has '+prereq' => (
    default => sub {
        ['MyPrevPatch'],
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

GRANT select, update, insert, delete  ON phenome.locusgroup_member to postgres, web_usr;
GRANT select, update, usage  ON phenome.locusgroup_member_locusgroup_member_id_seq to postgres, web_usr;


EOSQL

print "You're done!\n";
}


####
1; #
####
