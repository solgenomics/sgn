#!/usr/bin/env perl

=head1 NAME

MakeAllPhenotypedTraitsVariables.pm

=head1 SYNOPSIS

mx-run MakeAllPhenotypedTraitsVariables [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

Variables are cvterms with a 'variable_of' relationship in the cvterm_relationship table. This patch will ensure that all cvterms associated to a phenotype have a 'variable_of' relationship.

 
=head1 AUTHOR

Nicolas Morales<nm529@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package MakeAllPhenotypedTraitsVariables;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;
extends 'CXGN::Metadata::Dbpatch';
use SGN::Model::Cvterm;

has '+description' => ( default => <<'' );
Variables are cvterms with a 'variable_of' relationship in the cvterm_relationship table. This patch will ensure that all cvterms associated to a phenotype have a 'variable_of' relationship.

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    my $chado_schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );

    my $coderef = sub {

        my $is_a_term_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'is_a', 'relationship')->cvterm_id();

        my $variable_term_id;
        try {
            $variable_term_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'VARIABLE_OF', 'cassava_trait')->cvterm_id();
        } catch {
            my $variable_term = $chado_schema->resultset("Cv::Cvterm")->create_with({
                name => 'VARIABLE_OF',
                cv   => 'relationship',
            });
            $variable_term_id = $variable_term->cvterm_id();
        };

        my $q = "SELECT cvterm.cvterm_id FROM phenotype JOIN cvterm on (phenotype.cvalue_id=cvterm.cvterm_id);";
        my $h = $chado_schema->storage->dbh()->prepare($q);
        $h->execute();
        my %cvterm_ids;
        while (my ($cvterm) = $h->fetchrow_array()) {
            $cvterm_ids{$cvterm} = 1;
        }


        my $count_q = "SELECT count(*) FROM cvterm_relationship WHERE subject_id=? and type_id=$is_a_term_id;";
        my $count_h = $chado_schema->storage->dbh()->prepare($count_q);

        foreach (keys %cvterm_ids) {

            my $count = $count_h->execute($_);
            if ($count == 0){
                my $create_q = "INSERT INTO cvterm_relationship (type_id, subject_id, object_id) VALUES ($variable_term_id, ?, ?);";
                my $create_h = $chado_schema->storage->dbh()->prepare($create_q);
                $create_h->execute($_, $_);
            } elsif ($count == 1) {
                my $update_q = "UPDATE cvterm_relationship SET type_id=$variable_term_id WHERE subject_id=? and type_id=$is_a_term_id;";
                my $update_h = $chado_schema->storage->dbh()->prepare($update_q);
                $update_h->execute($_);
            } else {
                die "More than one is_a relationship already saved...\n";
            }

        }
    };

    try {
        $chado_schema->txn_do($coderef);
    } catch {
        die "Patch failed! Transaction exited." . $_ .  "\n" ;
    };

    print "You're done!\n";

}

####
1; #
####
