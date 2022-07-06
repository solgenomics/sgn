package RemoveListCreateDate;

=head1 NAME

AddTimestampFields

=head1 SYNOPSIS

Remove create_date field from sgn_people.list table

    mx-run RemoveListCreateDate [options] -H hostname -D dbname -u username [-F]

This is a subclass of L<CXGN::Metadata::Dbpatch>

=head1 DESCRIPTION

=head1 AUTHOR

Tim Parsons

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
    my $description = 'Remove create_date field from sgn_people.list';
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

DO $$

BEGIN
    IF EXISTS(
        SELECT column_name FROM information_schema.columns WHERE table_schema = 'sgn_people' and table_name = 'list' AND column_name = 'create_date'
    )
    THEN
        update sgn_people.list set "timestamp" = create_date;
        ALTER TABLE sgn_people.list DROP COLUMN create_date;
    END IF;
END $$;
SQL

    $self->dbh->do($sql);
    say "Done";
}

1;
