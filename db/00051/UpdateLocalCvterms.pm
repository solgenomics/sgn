#!/usr/bin/env perl


=head1 NAME

 UpdateLocalCvterms

=head1 SYNOPSIS

mx-run ThisPackageName [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch changes the cv of local cvterms to the correct one

This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

 Naama Menda<nm249@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package UpdateLocalCvterms;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;

extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch will update the cv id of the following cvterms that currently have a local cv name 
cross_type
breeding_program
breeding_program_trial_relationship
harvest_date
number_of_flowers
number_of_seeds
planting_date
this is important for making CVterms uniform and having an explicit cv name that provides the right context

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
	my $cvterm_rs = $schema->resultset("Cv::Cvterm");
	my $cv_rs = $schema->resultset("Cv::Cv");
	
	my $nd_experiment_property_cv = $cv_rs->find_or_create( { name => 'nd_experiment_property' });
	
	my $cross_type_cvterm = $cvterm_rs->search( 
	    { name => 'cross_type', } );
	
	if ( $cross_type_cvterm->count() == 0 ) {
	    print "Creating new cvterm 'cross_type' cv = 'nd_experiment_property' \n";
	    $cvterm_rs->create_with(
		{
		    name => 'cross_type',
		    cv   => 'nd_experiment_property',
		} );
	} else { 
	    print "Updating existing cvterm 'cross_type' cv = 'nd_experiment_property' \n";
	    $cross_type_cvterm->first->update( { cv_id => $nd_experiment_property_cv->cv_id }, );
	}
	####
	my $number_of_flowers_cvterm = $cvterm_rs->search( 
	    { name => 'number_of_flowers', } );
	
	if ( $number_of_flowers_cvterm->count() == 0 ) {
	    print "Creating new cvterm 'number_of_flowers' cv = 'nd_experiment_property' \n";
	    $cvterm_rs->create_with(
		{
		    name => 'number_of_flowers',
		    cv   => 'nd_experiment_property',
		} );
	} else { 
	    print "Updating existing cvterm 'number_of_flowers' cv = 'nd_experiment_property' \n";
	    $number_of_flowers_cvterm->first->update( { cv_id => $nd_experiment_property_cv->cv_id }, );
	}
	##########
	my $number_of_seeds_cvterm = $cvterm_rs->search( 
	    { name => 'number_of_seeds', } );
	
	if ( $number_of_seeds_cvterm->count() == 0 ) {
	    print "Creating new cvterm 'number_of_seeds' cv = 'nd_experiment_property' \n";
	    $cvterm_rs->create_with(
		{
		    name => 'number_of_seeds',
		    cv   => 'nd_experiment_property',
		} );
	} else { 
	    print "Updating existing cvterm 'number_of_seeds' cv = 'nd_experiment_property' \n";
	    $number_of_seeds_cvterm->first->update( { cv_id => $nd_experiment_property_cv->cv_id }, );

	}
#####
	    
	    my $project_property_cv = $cv_rs->find_or_create( { name => 'project_property' });
	    my $breeding_program_cvterm = $cvterm_rs->search( 
		{ name => 'breeding_program', } );
	    
	    if ( $breeding_program_cvterm->count() == 0 ) {
	    print "Creating new cvterm 'breeding_program' cv = 'project_property' \n";
	    $cvterm_rs->create_with(
		{
		    name => 'breeding_program',
		    cv   => 'project_property',
		} );
	} else { 
	    print "Updating existing cvterm 'breeding_program' cv = 'project_property' \n";
	    $breeding_program_cvterm->first->update( { cv_id => $project_property_cv->cv_id }, );
	   } 
	    ##############
	    my $harvest_date_cvterm = $cvterm_rs->search( 
		{ name => 'harvest_date', } );
	    
	    if ( $harvest_date_cvterm->count() == 0 ) {
	    print "Creating new cvterm 'harvest_date' cv = 'project_property' \n";
	    $cvterm_rs->create_with(
		{
		    name => 'harvest_date',
		    cv   => 'project_property',
		} );
	} else { 
	    print "Updating existing cvterm 'harvest_date' cv = 'project_property' \n";
	    $harvest_date_cvterm->first->update( { cv_id => $project_property_cv->cv_id }, );
	  }  
	    ####
	    my $planting_date_cvterm = $cvterm_rs->search( 
		{ name => 'planting_date', } );
	    
	    if ( $planting_date_cvterm->count() == 0 ) {
	    print "Creating new cvterm 'planting_date' cv = 'project_property' \n";
	    $cvterm_rs->create_with(
		{
		    name => 'planting_date',
		    cv   => 'project_property',
		} );
	} else { 
	    print "Updating existing cvterm 'planting_date' cv = 'project_property' \n";
	    $planting_date_cvterm->first->update( { cv_id => $project_property_cv->cv_id }, );
	 }   
	    ###########
	    
	    my $project_relationship_cv = $cv_rs->find_or_create( { name => 'project_relationship' });
	    my $breeding_program_trial_cvterm = $cvterm_rs->search( 
		{ name => 'breeding_program_trial_relationship', } );
	    
	    if ( $breeding_program_trial_cvterm->count() == 0 ) {
	    print "Creating new cvterm 'breeding_program_trial_relationship' cv = 'project_relationship' \n";
	    $cvterm_rs->create_with(
		{
		    name => 'breeding_program_trial_relationship',
		    cv   => 'project_relationship',
		} );
	} else { 
	    print "Updating existing cvterm 'breeding_program_trial_relationship' cv = 'project_relationship' \n";
	    $breeding_program_trial_cvterm->first->update( { cv_id => $project_relationship_cv->cv_id }, );
	}
	    
	    ##############
	    
	if ($self->trial) {
            print "Trial mode! Rolling back transaction\n\n";
            $schema->txn_rollback;
	    return 0;
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
