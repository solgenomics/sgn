#!/usr/bin/env perl


=head1 NAME

RemoveFieldbookImageCvterm

=head1 SYNOPSIS

mx-run RemoveFieldbookImageCvterm [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION
This patch removes the fieldbook_image cvterm from the cassavs_trait ontology. This term is not used by the Fieldbook App, and if it is needed in the future should be linked to stock_prop or a "local" cv.
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package RemoveFieldbookImageCvterm;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;
use SGN::Model::Cvterm;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch removes the fieldbook_image cvterm from the ontology.

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

    print STDERR "Removing CVTERM fieldbook_image...\n";

    my $coderef = sub {
	
	
	my $subject_id;
	my $subject = SGN::Model::Cvterm->get_cvterm_row($schema, 'fieldbook_image', 'cassava_trait');
	if ($subject) {
	    $subject_id = $subject->cvterm_id ;
	} else {
	    print STDERR "Cvterm fieldbook_image does not exist in the database. Exiting\n";
	    return 0;
	}

	 #my $object_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'CGIAR cassava trait ontology', 'cassava_trait')->cvterm_id();
	my $cvterm_relationship_rs = $schema->resultset("Cv::CvtermRelationship")->search( { subject_id => $subject_id });
	$cvterm_relationship_rs->delete();
	
	my $cvterm = $schema->resultset( "Cv::Cvterm" )->find({ cvterm_id  => $subject_id  });
	$cvterm->delete();
	
    };
    
    try {
	$schema->txn_do($coderef);
    } catch {
	die "Load failed! " . $_ .  "\n" ;
    };
    
    print "You're done!\n";
}


####
1; #
####
