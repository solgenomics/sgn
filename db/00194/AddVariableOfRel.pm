#!/usr/bin/env perl


=head1 NAME

AddVariableOfRel

=head1 SYNOPSIS

mx-run AddVariableOfRel [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION
This patch adds VARIABLE_OF, method_of, scale_of cvterms using the relationship ontology cv
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

Naama Menda <nm249@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddVariableOfRel;

use Moose;
use Bio::Chado::Schema;
use SGN::Model::Cvterm;
use Try::Tiny;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch adds the following cvterms to the relationship ontology: VARIABLE_OF, method_of, scale_of

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
        print STDERR "INSERTING CVTERMS...\n";
        my @terms =  ("VARIABLE_OF", "method_of", "scale_of");
        foreach my $term (@terms) {
            my $new_cvterm = $schema->resultset("Cv::Cvterm")->create_with({
                name => $term,
                cv => 'relationship',
                dbxref => $term,
                db => 'OBO_REL'
            });
            $new_cvterm->update({ is_relationshiptype => 1 });
        }
        return 1;
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
