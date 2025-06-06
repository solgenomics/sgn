#!/usr/bin/env perl

=head1 NAME

AddTrackingActivityRelatedCvterms.pm

=head1 SYNOPSIS

mx-run ThisPackageName [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION
This patch adds activity_record project_type cvterm, tracking_activity experiment_type cvterm, tracking_identifier stock_type cvterm, material_of stock_relationship cvterm, tracking_tissue_culture_json stock_property cvterm and tracking_identifiers list_type cvterm.
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

Titima Tantikanjana<tt15@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddTrackingActivityRelatedCvterms;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
Description of this patch goes here

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


    print STDERR "INSERTING CV TERMS...\n";

    my $terms = {
        'project_type' => [
            'activity_record'
        ],
        'project_property' => [
            'activity_type',
            'project_vendor',
            'folder_for_tracking_activities'
        ],
        'experiment_type' => [
            'tracking_activity'
        ],
        'stock_type' => [
            'tracking_identifier'
        ],
        'stock_relationship' => [
            'material_of'
        ],
        'stock_property' => [
            'tracking_tissue_culture_json',
            'terminated_metadata',
        ],
        'list_types' => [
            'tracking_identifiers'
        ],
        'sp_order_property' => [
            'order_tracking_identifiers'
        ],
    };

    foreach my $t (keys %$terms){
        foreach (@{$terms->{$t}}){
            $schema->resultset("Cv::Cvterm")->create_with({
                name => $_,
                cv => $t
            });
        }
    }

    print "You're done!\n";

}


####
1; #
####
