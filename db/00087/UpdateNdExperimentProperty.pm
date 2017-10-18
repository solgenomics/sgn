#!/usr/bin/env perl


=head1 NAME

 UpdateNdExperimentProperty.pm

=head1 SYNOPSIS

mx-run ThisPackageName [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION
This patch updates the cvterm "crossing_metadata_json" by changing from  cv = "nd_experiment_property" to cv = "stock_property"  and removes unused cvterms related to crossing experiments.
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

 Titima Tantikanjana<tt15@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package UpdateNdExperimentProperty;

use Moose;
use Bio::Chado::Schema;
use SGN::Model::Cvterm;
use Try::Tiny;
extends 'CXGN::Metadata::Dbpatch';



has '+description' => ( default => <<'' );
This patch updates the cvterm "crossing_metadata_json" by changing from  cv = "nd_experiment_property" to cv = "stock_property"  and removes unused cvterms related to crossing experiments.

has '+prereq' => (
	default => sub {
        ['AddCrossingExperimentCvterms', 'AddNewCrossCvterms', 'AddSystemCvterms'],
    },

  );

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";
    my $schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );

    # update crossing_metadata_json cvterm

    my $crossing_metadata_json_cvterm = $schema->resultset("Cv::Cvterm")->find(
        { name => 'crossing_metadata_json'});

    my $stock_property_cv = $schema->resultset("Cv::Cv")->find(
        { name => 'stock_property'});

    $crossing_metadata_json_cvterm->update({cv_id => $stock_property_cv->cv_id});

    # delete unused cvterms related to crossing experiment

    my $nd_experiment_property_id = $schema->resultset("Cv::Cv")->find(
        { name => 'nd_experiment_property'})->cv_id();

    my $cvterm_rs = $schema->resultset("Cv::Cvterm")->search(
        { cv_id => $nd_experiment_property_id,

          name => ['date_of_embryo_rescue',
                 'date_of_harvest',
                 'date_of_pollination',
                 'date_of_seed_extraction',
                 'days_from_extraction_to_embryo_rescue',
                 'days_from_harvest_to_extraction',
                 'days_to_maturity',
                 'number_of_embryos_contaminated',
                 'number_of_embryos_germinated',
                 'number_of_embryos_rescued',
                 'number_of_flowers',
                 'number_of_fruits',
                 'number_of_nonviable_seeds',
                 'number_of_seedlings_transplanted',
                 'number_of_seeds',
                 'number_of_seeds_extracted',
                 'number_of_seeds_germinated',
                 'number_of_seeds_planted',
                 'number_of_viable_seeds'],
        });

    $cvterm_rs->delete_all;

    print "You're done!\n";
}


####
1; #
####
