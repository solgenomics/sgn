#!/usr/bin/env perl


=head1 NAME

 UpdateProjectTypes.pm

=head1 SYNOPSIS

mx-run ThisPackageName [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION
This patch updates the cvterms phenotypeing_trial and genotyping_trial with cv = project_type to be consistent with other projectprops in the database
cvterm crossing_trial is redundant and is now deleted, as well as the cv.name trial_type. All trial types in the database should use the project_type cvterm since these are stored in the project table 


This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

 Naama Menda<nm249@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package UpdateProjectTypes;

use Moose;
use Bio::Chado::Schema;
use SGN::Model::Cvterm;
use Try::Tiny;
extends 'CXGN::Metadata::Dbpatch';



has '+description' => ( default => <<'' );
This patch updates the cvterms phenotypeing_trial and genotyping_trial with cv = project_type to be consistent with other projectprops in the database
cvterm crossing_trial is redundant and is now deleted, as well as the cv.name trial_type. All trial types in the database should use the project_type cvterm since these are stored in the project table 

has '+prereq' => (
	default => sub {
        ['AddGraftingCvterms', 'AddTrialTypes'],
    },

  );

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";
    my $schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );


 
    my $phenotyping_cvterm =  SGN::Model::Cvterm->get_cvterm_row($schema, 'phenotyping_trial', 'trial_type');
    my $genotyping_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'genotyping_trial' , 'trial_type' ) ;
    my $crossing_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'crossing_trial' , 'trial_type' ) ;
    my $trial_type_cv = $schema->resultset("Cv::Cv")->find(
	{ name => 'trial_type' });
    my $project_type_cv = $schema->resultset("Cv::Cv")->find(
	{ name => 'project_type' } );

    $phenotyping_cvterm->update( { cv_id => $project_type_cv->cv_id  } );
    $genotyping_cvterm->update( { cv_id =>  $project_type_cv->cv_id } );
    $crossing_cvterm->delete;
    $trial_type_cv->delete;

    print "You're done!\n";
}


####
1; #
####
