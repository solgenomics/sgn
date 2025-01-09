#!/usr/bin/env perl


=head1 NAME

AddBreederRole

=head1 SYNOPSIS

mx-run AddBreederRole [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch adds vendor role on sgn_people.sp_roles

This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

 Chris Simoes < ccs263@cornell.edu >

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddBreederRole;

use Moose;

extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch adds vendor role on sgn_people.sp_roles

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
INSERT INTO sgn_people.sp_roles(name) VALUES ('breeder');

EOSQL


    print "You're done!\n";

}


####
1; #
####
