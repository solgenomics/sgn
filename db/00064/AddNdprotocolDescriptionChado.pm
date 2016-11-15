#!/usr/bin/env perl


=head1 NAME

 AddNdprotocolDescriptionChado

=head1 SYNOPSIS

mx-run ThisPackageName [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

Add a description column to the Chado table nd_protocol
This change will go into Chado version 1.4. See GMOD git repo for details.
DO NOT ALTER CHADO TABLES WITHOUT COORDINATING WITH GMOD FIRST!

This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

 Naama Menda<nm249@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddNdprotocolDescriptionChado;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
patch for adding descriotion column to chado table nd_protocol. This change will go into Chado version 1.4. DO NOT ALTER CHADO TABLES WITHOUT COORDINATING FIRST WITH GMOD!


sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    $self->dbh->do(<<EOSQL);
--do your SQL here
--

ALTER TABLE nd_protocol ADD COLUMN description varchar(255) DEFAULT null;


EOSQL

print "You're done!\n";
}


####
1; #
####
