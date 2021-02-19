#!/usr/bin/env perl


=head1 NAME

FixFieldbookImageCvterm

=head1 SYNOPSIS

mx-run FixFieldbookImageCvterm [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION
This patch fixes the fieldbook_image cvterm from showing up in the trait search as an ontology. This term was missing the upper link to its ontology.
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package FixFieldbookImageCvterm;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;
use SGN::Model::Cvterm;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch fixes the fieldbook_image cvterm from showing up in the trait search as an ontology. This term was missing the upper link to its ontology.

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
    my $schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );

    print STDERR "Fixing CVTERM fieldbook_image...\n";

    my $type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'is_a', 'relationship')->cvterm_id();
    my $subject_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'fieldbook_image', 'cassava_trait')->cvterm_id();
    my $object_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'CGIAR cassava trait ontology', 'cassava_trait')->cvterm_id();

    my $q_check = "SELECT cvterm_relationship_id FROM cvterm_relationship WHERE type_id=? and object_id=? and subject_id=?;";
    my $check_h = $schema->storage->dbh()->prepare($q_check);
    $check_h->execute($type_id, $object_id, $subject_id);
    my ($exists) = $check_h->fetchrow_array();

    if (!$exists) {
        my $q_ins = "INSERT INTO cvterm_relationship (type_id, object_id, subject_id) VALUES (?,?,?);";
        my $ins_h = $schema->storage->dbh()->prepare($q_ins);
        $ins_h->execute($type_id, $object_id, $subject_id);
    }

    print "You're done!\n";
}


####
1; #
####
