#!/usr/bin/env perl


=head1 NAME

 FixRedundantCvterms.pm

=head1 SYNOPSIS

mx-run ThisPackageName [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch cleans up system cvterms terms that are 
1. not being used
2. confusing
3. are used in the wrong context (e.g. stock_relationship cvterm used in the nd_experimentprop table) 

This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

 Naama Menda<nm249@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package FixRedundantCvterms;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;

extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch will do the following:
1. Set cv_id = nd_experiment_property for the cvterm cross_name
2. Update the type_id of nd_experiment rows to cross_experiment where the type_id = cross , and then obsolete this stock_relationship cross cvterm
3. Create a new term called cross_relationship cv= stock_relationship to be used 
in the stock_relationship table instead of the term cross_name which now 
has a nd_experiment_property cv and is used as type_id in nd_experimentprop
this is important for making CVterms uniform and less room for errors when using these

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
	
	#############

	#############1
	my $nd_experiment_property_cv = $cv_rs->find_or_create( { name => 'nd_experiment_property' } ) ;
	
	my $cross_name_cvterm = $cvterm_rs->find(
	    {
		name => 'cross_name' , 
	    });
	if ($cross_name_cvterm) { 
	    print "UPDATING cv_id of cvterm cross_name to nd_experiment_property\n";
	    $cross_name_cvterm->update( { cv_id => $nd_experiment_property_cv->cv_id } ) ;
	}
	###############2

	my $cross_experiment_cvterm = $cvterm_rs->create_with( 
	    {
		name => 'cross_experiment',
		cv   => 'experiment_type',
	    } ) ;
	
	my $nd_experiment_rs = $schema->resultset("NaturalDiversity::NdExperiment")->search(
	    {
		'type.name' => 'cross'
	    },
	    {
		join => 'type',
	    } );
	if ( $nd_experiment_rs->count ) {
	    print "UPDATING nd_experiment with type_id = cross to type_id = cross_experiment\n";
<<<<<<< HEAD
	    $nd_experiment_rs->update( type_id => $cross_experiment_cvterm->cvterm_id );
=======
	    $nd_experiment_rs->update( { type_id => $cross_experiment_cvterm->cvterm_id }  );
>>>>>>> 37cf2d065e7082fc6235917d11c1c1ef4eff65c1
	}
	### OBSOLETE name of cross cvterm cv = stock_relationship
	my $cross_cvterm = $cvterm_rs->find(
	    {
		'me.name' => 'cross',
		'cv.name' => 'stock_relationship',
	    },
	    { 
		join => 'cv' ,
	    } );
	if ( $cross_cvterm ) { 
	    print "UPDATING term cross cv= stock_relationship to name = OBSOLETE_cross. No one should use this term. There is a cross term with stock_type cv\n";
	    $cross_cvterm->update( { name => 'OBSOLETE_cross' } ) ;
	}
	##################3
	
	my $cross_relationship_cvterm = $cvterm_rs->create_with(
	    {
		name => 'cross_relationship' ,
		cv   => 'stock_relationship',
	    } ) ;
	
	my $stock_relationship_rs = $schema->resultset("Stock::StockRelationship")->search(
	    {
		'type.name' => 'cross_name',
	    } , 
	    { join => 'type', }
	    );
	if ( $stock_relationship_rs->count ) { 
	    print "UPDATING stock_relationships with type = cross_name to new cvterm = cross_relationship. You should not use the term cross in stock_relationship. It should be only a stock.type \n";
	    $stock_relationship_rs->update( { type_id => $cross_relationship_cvterm->cvterm_id } );
	}
	
	###################
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
