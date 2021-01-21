#!/usr/bin/env perl


=head1 NAME

AddIsPublicDataset

=head1 SYNOPSIS

mx-run AddIsPublicDataset [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION
This patch adds the column 'is_public' to the sgn_people.sp_dataset table
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddIsPublicDataset;

use strict;
use warnings;
use Moose;
use Bio::Chado::Schema;
use Try::Tiny;
use SGN::Model::Cvterm;
use JSON;
extends 'CXGN::Metadata::Dbpatch';

has '+description' => ( default => <<'' );
This patch adds the column 'is_public' to the sgn_people.sp_dataset table

has '+prereq' => (
        default => sub {
        [],
    },

);

sub patch {
    my $self=shift;
    my $column_name;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";
    my $schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );

    my $q = "select column_name FROM information_schema.columns WHERE table_name = 'sp_dataset' and column_name = 'is_public'";
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute();
    ($column_name) = $h->fetchrow_array();
    if (defined($column_name) && ($column_name eq 'is_public')) {
	print STDOUT "patch already run!\n";
    } else {
        my $sql = "ALTER TABLE sgn_people.sp_dataset ADD COLUMN is_public BOOLEAN";
        $schema->storage->dbh->do($sql);
    }
    print "You're done!\n";
}

####
1; #
####
