#!/usr/bin/env perl

=head1 NAME

AddTimeOntologyYear.pm

=head1 SYNOPSIS

mx-run AddTimeOntologyYear [options] [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch:
 - Adds new cvterm for time ontology: year

=head1 AUTHOR

Katherine Eaton

=head1 COPYRIGHT & LICENSE

Copyright 2026 University of Alberta

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

package AddTimeOntologyYear;

use Moose;
use Bio::Chado::Schema;
use SGN::Model::Cvterm;
extends 'CXGN::Metadata::Dbpatch';

has '+description' => ( default => <<'' );
Adds new cvterm for time ontology age in years: year 1-100.

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";
    my $schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );

    print STDERR "INSERTING CV TERMS...\n";
    my $is_a_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'is_a', 'relationship')->cvterm_id();
    my $time_ontology_rs = $schema->resultset("Cv::Cvterm")->find({name => "Time"});

    # Create the root cvterm
    # next available dbxref accession in time ontology is '0000481'
    my $dbxref_accession = 481;
    my $time_in_years_rs = $schema->resultset("Cv::Cvterm")->create_with({
        name => "time in years",
        definition=> "Time in years",
        cv => 'cxgn_time_ontology',
        db => 'TIME',
        dbxref => sprintf("%07d", $dbxref_accession)
    });
    # Link root cvterm to the time ontology
    $schema->resultset("Cv::CvtermRelationship")->find_or_create({
            subject_id => $time_in_years_rs->cvterm_id(),
            type_id    => $is_a_cvterm_id,
            object_id  => $time_ontology_rs->cvterm_id()
    });

    # Create years 1 through 100
    foreach my $year (1..100) {
        $dbxref_accession += 1;
        my $year_rs = $schema->resultset("Cv::Cvterm")->create_with({
            name => "year $year",
            cv => 'cxgn_time_ontology',
            db => 'TIME',
            dbxref => sprintf("%07d", $dbxref_accession)
        });
        # link to time in years root cvterm
        $schema->resultset("Cv::CvtermRelationship")->find_or_create({
            subject_id => $year_rs->cvterm_id(),
            type_id    => $is_a_cvterm_id,
            object_id  => $time_in_years_rs->cvterm_id()
        });
    }

    print "You're done!\n";
}

####
1; #
####
