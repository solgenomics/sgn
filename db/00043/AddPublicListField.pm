package AddPublicListField;

=head1 NAME

AddPublicListField

=head1 SYNOPSIS

Add is_public boolean field (NOT NULL DEAFULT FALSE) to sgn_people.list table

    mx-run AddPublicListField [options] -H hostname -D dbname -u username [-F]

This is a subclass of L<CXGN::Metadata::Dbpatch>

=head1 DESCRIPTION

=head1 AUTHOR

Nick Morales

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

use Try::Tiny;
use Moose;
use 5.010;
extends 'CXGN::Metadata::Dbpatch';

sub init_patch {
    my $self=shift;
    my $name = __PACKAGE__;
    say "dbpatch name $name";
    my $description = 'Add is_public boolean field to sgn_people.list';
    my @previous_requested_patches = ();
    $self->name($name);
    $self->description($description);
    $self->prereq(\@previous_requested_patches);
}

sub patch {
    my $self=shift;
    say  "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";
    say  "Checking if this db_patch was executed before or if previous db_patches have been executed.\n";
    say  "Executing the SQL commands.\n";

    my $sql = <<SQL;
ALTER TABLE sgn_people.list ADD COLUMN "is_public" BOOLEAN NOT NULL DEFAULT FALSE;
UPDATE sgn_people.list SET is_public = 'f';
SQL

    $self->dbh->do($sql);
    say "Have a nice day!";
}

1;
