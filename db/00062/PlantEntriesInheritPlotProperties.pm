#!/usr/bin/env perl

=head1 NAME

PlantEntriesInheritPlotProperties.pm

=head1 SYNOPSIS

mx-run PlantEntriesInheritPlotProperties [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch updates the way that plant entries were being created and stored. Previously, plant entries did not inherit plot properties (block, replicate, plot number), as well as a relationship to the accession. Now they are created with these associations.

 
=head1 AUTHOR

Nicolas Morales<nm529@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package PlantEntriesInheritPlotProperties;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;
extends 'CXGN::Metadata::Dbpatch';
use SGN::Model::Cvterm;

has '+description' => ( default => <<'' );
This patch updates the way that plant entries were being created and stored. Previously, plant entries did not inherit plot properties (block, replicate, plot number), as well as a relationship to the accession. Now they are created with these associations.

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    my $chado_schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );

    my $coderef = sub {

        my $plant_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plant', 'stock_type')->cvterm_id();
		my $plot_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plot', 'stock_type')->cvterm_id();
        my $plant_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plant_of', 'stock_relationship')->cvterm_id();
        my $plot_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plot_of', 'stock_relationship')->cvterm_id();
        my $block_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'block', 'stock_property')->cvterm_id();
		my $plot_number_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plot number', 'stock_property')->cvterm_id();
		my $replicate_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'replicate', 'stock_property')->cvterm_id();
        my $field_layout_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'field_layout', 'experiment_type')->cvterm_id();

        my $plots_of_plants = $chado_schema->resultset("Stock::StockRelationship")->search({ type_id=>$plant_of_cvterm_id });

        while (my $p = $plots_of_plants->next() ) {

            #The plant inherits the properties of the plot.
            if ($p->subject()->type_id() == $plot_cvterm && $p->object()->type_id() == $plant_cvterm) {
                my $plot_props = $chado_schema->resultset("Stock::Stockprop")->search({ stock_id => $p->subject()->stock_id(), type_id => [$block_cvterm, $plot_number_cvterm, $replicate_cvterm] });
                while (my $prop = $plot_props->next() ) {
                    print $p->subject()->uniquename()." ".$prop->type_id()." ".$p->object()->uniquename()."\n";
                    my $plantprop = $chado_schema->resultset("Stock::Stockprop")->find( {
                        stock_id => $p->object()->stock_id(),
                        type_id => $prop->type_id(),
                    });
                    if ($plantprop) {
                        $plantprop->delete();
                    }
                    $plantprop = $chado_schema->resultset("Stock::Stockprop")->create( {
                        stock_id => $p->object()->stock_id(),
                        type_id => $prop->type_id(),
                        value => $prop->value(),
                    });
                }
            }

            my $plot_accession = $chado_schema->resultset("Stock::StockRelationship")->find({subject_id=>$p->subject()->stock_id(), type_id=>$plot_of_cvterm_id });
            if ($plot_accession) {
                my $stock_relationship = $chado_schema->resultset("Stock::StockRelationship")->find_or_create({
                    subject_id => $p->object()->stock_id(),
                    object_id => $plot_accession->object()->stock_id(),
                    type_id => $plant_of_cvterm_id,
                });
            }
        }
        
        
        #For greenhouse trials
        my $greenhouses = $chado_schema->resultset("Project::Projectprop")->search({ value=>'greenhouse' });
        while(my $g = $greenhouses->next() ) {
            my $number = 1;
            my $project_id = $g->project_id();
            my $field_layout_experiment = $chado_schema->resultset("Project::Project")->search( { 'me.project_id' => $project_id }, {select=>['nd_experiment.nd_experiment_id']})->search_related('nd_experiment_projects')->search_related('nd_experiment', { type_id => $field_layout_cvterm })->single();
            my $plant_nd_experiment_stocks = $chado_schema->resultset("NaturalDiversity::NdExperimentStock")->search({
                nd_experiment_id => $field_layout_experiment->nd_experiment_id(),
                type_id => $field_layout_cvterm,
            });
            while (my $s = $plant_nd_experiment_stocks->next() ) {
                print STDERR $s->search_related('stock')->single()->uniquename()."\n";
                my $plantprop = $chado_schema->resultset("Stock::Stockprop")->find( {
                    stock_id => $s->stock_id(),
                    type_id => $block_cvterm,
                });
                if ($plantprop) {
                    $plantprop->delete();
                }
                $plantprop = $chado_schema->resultset("Stock::Stockprop")->create( {
                    stock_id => $s->stock_id(),
                    type_id => $block_cvterm,
                    value => 1,
                });
                $plantprop = $chado_schema->resultset("Stock::Stockprop")->find( {
                    stock_id => $s->stock_id(),
                    type_id => $replicate_cvterm,
                });
                if ($plantprop) {
                    $plantprop->delete();
                }
                $plantprop = $chado_schema->resultset("Stock::Stockprop")->create( {
                    stock_id => $s->stock_id(),
                    type_id => $replicate_cvterm,
                    value => 1,
                });
                $plantprop = $chado_schema->resultset("Stock::Stockprop")->find( {
                    stock_id => $s->stock_id(),
                    type_id => $plot_number_cvterm,
                });
                if ($plantprop) {
                    $plantprop->delete();
                }
                $plantprop = $chado_schema->resultset("Stock::Stockprop")->create( {
                    stock_id => $s->stock_id(),
                    type_id => $plot_number_cvterm,
                    value => $number,
                });
    			$number ++;
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
