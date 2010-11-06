package AddMissingIndexes;

=head1 NAME

AddMissingIndexes

=head1 SYNOPSIS

Add missing indexes to the SGN schema

    mx-run AddMissingIndexes [options] -H hostname -D dbname -u username [-F]

This is a subclass of L<CXGN::Metadata::Dbpatch>

=head1 DESCRIPTION

=head1 AUTHOR

Jonathan "Duke" Leto

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
    my $description = 'Add missing indexes';
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
create index cds_protein_feature_id_idx on sgn.cds (protein_feature_id);
create index phylonode_feature_id_idx on public.phylonode (feature_id);
create index clone_feature_feature_id_idx on genomic.clone_feature (feature_id);
SQL

    $self->dbh->do($sql);
    say "Have a nice day!";
}

1;
