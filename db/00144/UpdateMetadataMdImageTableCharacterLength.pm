#!/usr/bin/env perl


=head1 NAME

    UpdateMetadataMdImageTableCharacterLength.pm

=head1 SYNOPSIS

mx-run UpdateMetadataMdImageTableCharacterLength [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch changes fields character length to greater than 100 chars

This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR


=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package UpdateMetadataMdImageTableCharacterLength;

use Moose;

extends 'CXGN::Metadata::Dbpatch';

has '+description' => ( default => <<'');
This patch changes fields character length to greater than 100 chars


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

ALTER TABLE metadata.md_image ALTER COLUMN original_filename TYPE varchar (250);
ALTER TABLE metadata.md_image ALTER COLUMN name TYPE varchar (250);

EOSQL

print "You're done!\n";
}


####
1; #
####
