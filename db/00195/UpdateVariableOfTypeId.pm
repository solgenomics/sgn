#!/usr/bin/env perl


=head1 NAME

UpdateVariableOfTypeId

=head1 SYNOPSIS

mx-run UpdateVariableOfTypeId [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION
This patch updates the cvterm_relationship table and sets type_id =  VARIABLE_OF from the cv = relationship
Requires running db pathc 00194 first
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

Naama Menda <nm249@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package UpdateVariableOfTypeId;

use Moose;
use Bio::Chado::Schema;
use SGN::Model::Cvterm;
use Try::Tiny;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch updates cvterm_relationship.type_id = VARIABLE_OF from the cv.name = relationship ontology

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

    my $coderef = sub {
        print STDOUT "Updating cvterm_relationship table type_id to the new variable_of cvterm \n";
        my $variable_of_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'VARIABLE_OF', 'relationship')->cvterm_id();
        my $cvterm_relationship_rs = $schema->resultset("Cv::CvtermRelationship")->search(
            {
                'type.name' => 'VARIABLE_OF',
                'me.type_id' => { '!=' => $variable_of_id },
            },
            {  join => 'type' }
        );
        my $count = $cvterm_relationship_rs->count;
        $cvterm_relationship_rs->update( { type_id => $variable_of_id } );
        print STDOUT "Updated $count rows in cvterm_relationship table to new VARIABLE_OF type_id = $variable_of_id\n";

        my $old_cvterms_rs = $schema->resultset("Cv::Cvterm")->search(
            {
                name => 'VARIABLE_OF',
                is_relationshiptype => 1,
                cv_id => { '!=' => $variable_of_id },
            }
        );
        $old_cvterms_rs->delete(); 
        return 1;
    };
    try {
        $schema->txn_do($coderef);
    } catch {
        die "Load failed! " . $_ .  "\n" ;
    };
    print "Done updatating cvterm_relationship!\n";
}


####
1; #
####
