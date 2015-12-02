package AddJbrowseSrcField;

=head1 NAME

AddJbrowseSrcField

=head1 SYNOPSIS

Add jbrowse_src column varchar(80) in sgn.blast_db table

    mx-run AddJbrowseSrcField -H hostname -D dbname -u username

This is a subclass of L<CXGN::Metadata::Dbpatch>

=head1 DESCRIPTION

=head1 AUTHOR

Noe Fernandez-Pozo nf232@cornell.edu

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
    my $description = 'Add jbrowse_src column to sgn.blast_db';
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
ALTER TABLE sgn.blast_db ADD COLUMN "jbrowse_src" varchar(80);
SQL

    $self->dbh->do($sql);
    say "DB Patch done!";
}

1;
