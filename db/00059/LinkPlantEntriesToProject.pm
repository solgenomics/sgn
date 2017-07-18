#!/usr/bin/env perl

=head1 NAME

LinkPlantEntriesToProject.pm

=head1 SYNOPSIS

mx-run FixTrialTypes [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch updates the way that plant entries were being created and stored. Previously, plant entries were not linked directly to the project they are in. This made uploading of phenotypes slow because of additional searches to go from plant to plot to project. Now the connnection of plant to project is available.
 
=head1 AUTHOR

Nicolas Morales<nm529@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package LinkPlantEntriesToProject;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;
extends 'CXGN::Metadata::Dbpatch';
use SGN::Model::Cvterm;

has '+description' => ( default => <<'' );
This patch updates the way that plant entries were being created and stored. Previously, plant entries were not linked directly to the project they are in. This made uploading of phenotypes slow because of additional searches to go from plant to plot to project. Now the connnection of plant to project is available.

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    my $schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );

    my $coderef = sub {

        my $field_layout_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'field_layout', 'experiment_type')->cvterm_id();
        my $plot_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant_of', 'stock_relationship')->cvterm_id();

        my $plots_of_plants = $schema->resultset("Stock::StockRelationship")->search({ type_id=>$plot_of_cvterm_id });

        while (my $p = $plots_of_plants->next() ) {
            #Get project of plant from plot
            my $plant = $p->object();
            my $plot_of_plant = $p->subject();
            my $field_layout_experiment = $plot_of_plant
            ->search_related('nd_experiment_stocks')
            ->search_related('nd_experiment')
            ->find({'type.cvterm_id' => $field_layout_cvterm },
            { join => 'type' });
            my $project = $field_layout_experiment->nd_experiment_projects->single ; #there should be one project linked with the field experiment
            my $project_id = $project->project_id;

            #store nd_experiment_stock entry in same way as it is done when plant entries are created now.
            $field_layout_experiment = $schema->resultset("Project::Project")->search( { 'me.project_id' => $project_id }, {select=>['nd_experiment.nd_experiment_id']})->search_related('nd_experiment_projects')->search_related('nd_experiment', { type_id => $field_layout_cvterm })->single();
            my $plant_nd_experiment_stock = $schema->resultset("NaturalDiversity::NdExperimentStock")->create({
                nd_experiment_id => $field_layout_experiment->nd_experiment_id(),
                type_id => $field_layout_cvterm,
                stock_id => $plant->stock_id(),
            });
        }
    };

    try {
        $schema->txn_do($coderef);
    } catch {
        die "Patch failed! Transaction exited." . $_ .  "\n" ;
    };

    print "You're done!\n";

}

####
1; #
####
