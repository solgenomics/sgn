#!/usr/bin/env perl


=head1 NAME

 FixDroneImageryPartialTemplates

=head1 SYNOPSIS

mx-run FixDroneImageryPartialTemplates [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION
This patch fixes the drone imagery partial template storage info to contain a template name and the image_id.
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR


=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package FixDroneImageryPartialTemplates;

use Moose;
use Bio::Chado::Schema;
use CXGN::People::Schema;
use Try::Tiny;
use CXGN::Genotype::Search;
use JSON;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch fixes the drone imagery partial template storage info to contain a template name and the image_id.

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
    my $people_schema = CXGN::People::Schema->connect( sub { $self->dbh->clone } );

    my $manual_plot_polygon_template_partial = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_plot_polygons_partial', 'project_property')->cvterm_id();

    my $previous_plot_polygons_rs = $schema->resultset('Project::Projectprop')->search({type_id=>$manual_plot_polygon_template_partial});

    while (my $p = $previous_plot_polygons_rs->next) {
        my @previous_stock_polygons = @{decode_json $p->value};
        my @new_stock_polygons;
        foreach (@previous_stock_polygons) {
            push @new_stock_polygons, {
                template_name => "NA",
                image_id => 0,
                polygon => $_
            };
        }

        my $drone_run_band_plot_polygons = $schema->resultset('Project::Projectprop')->update_or_create({
            type_id=>$manual_plot_polygon_template_partial,
            project_id=>$p->project_id(),
            rank=>0,
            value=> encode_json(\@new_stock_polygons)
        },
        {
            key=>'projectprop_c1'
        });
    }

    print "You're done!\n";
}


####
1; #
####
