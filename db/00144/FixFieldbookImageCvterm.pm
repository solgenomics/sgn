#!/usr/bin/env perl


=head1 NAME

FixFieldbookImageCvterm

=head1 SYNOPSIS

mx-run FixFieldbookImageCvterm [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION
This patch fixes the fieldbook_image cvterm from showing up in the trait search as an ontology. This term was missing the upper link to its ontology.

Since this cvterm needs to be linked to an internal ontology instead of a crop ontology it is now removed from the database 

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
This patch used to fix the fieldbook_image cvterm from showing up in the trait search as an ontology. This term was missing the upper link to its ontology.
Now it does nothing because it should not be linked to a crop ontology cv. A future patch will remove it from databases that ran the old version of this patch 
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

    print STDERR "Doing nothing ...\n";


    print "You're done!\n";
}


####
1; #
####
