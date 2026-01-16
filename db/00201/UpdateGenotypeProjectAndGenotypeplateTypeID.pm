#!/usr/bin/env perl

=head1 NAME

UpdateGenotypeProjectAndGenotypingPlateTypeID

=head1 SYNOPSIS

mx-run UpdateGenotypeProjectAndGenotypingPlateTypeID [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch changes projectprop type_id for genotyping project from 'design' to 'genotyping_project' and changes projectprop type_id for genotyping plate from 'design' to 'genotyping_trial'.


=head1 AUTHOR

Titima Tantikanjana<tt15@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package UpdateGenotypeProjectAndGenotypingPlateTypeID;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;
extends 'CXGN::Metadata::Dbpatch';
use SGN::Model::Cvterm;

has '+description' => ( default => <<'' );
This patch changes projectprop type_id for genotyping project from 'design' to 'genotyping_project' type_id and changes projectprop type_id for genotyping plate from 'design' to 'genotyping_trial'.

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    my $chado_schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );

    my $coderef = sub {

        my $design_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'design', 'project_property')->cvterm_id();
		my $genotyping_project_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'genotyping_project', 'project_type')->cvterm_id();
        my $genotyping_trial_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'genotyping_trial', 'project_type')->cvterm_id();

        my $genotype_data_projects = $chado_schema->resultset("Project::Projectprop")->search({ type_id => $design_cvterm_id, value => ['genotype_data_project', 'pcr_genotype_data_project'] });
        while (my $genotype_project_rs = $genotype_data_projects->next() ) {
            $genotype_project_rs->update({type_id => $genotyping_project_cvterm_id});
        }

        my $genotyping_plates = $chado_schema->resultset("Project::Projectprop")->search({ type_id => $design_cvterm_id, value => 'genotyping_plate' });
        while (my $genotype_plate_rs = $genotyping_plates->next() ) {
            $genotyping_plate_rs->update({type_id => $genotyping_trial_cvterm_id});
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
