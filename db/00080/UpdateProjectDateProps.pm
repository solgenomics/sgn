#!/usr/bin/env perl


=head1 NAME

 UpdateProjectDateProps

=head1 SYNOPSIS

mx-run ThisPackageName [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch deletes resundant project_property 'project harvest date' and 'project planting date' , adds 'project_' prefix to the existing cvterms, and updates the rows in teh projectprop table to point to the correct cvterm

This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

 Naama Menda<nm249@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package UpdateProjectDateProps;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;

extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch will update the cvterm name of 
harvest_date -> project_harvest_date
planting_date -> project_planting_date
and remove the redundant terms
project harvest date
project planting date
Rows in projectprop that point to the redundant cvterms will be updated to point to the correct ones

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
	
	my $project_property_cv = $cv_rs->find( { name => 'project_property' });
	
	my $harvest_date_cvterm = $cvterm_rs->search( 
	    { name => 'harvest_date', } )->single;
	
	print "Updating existing cvterm 'harvest_date' \n";
	if ($harvest_date_cvterm) {
	    $harvest_date_cvterm->update( { name => 'project_harvest_date' }, );
	} else { 
	    $harvest_date_cvterm = $cvterm_rs->search( { name => 'project_harvest_date' } )->single;
	}
	my $harvest_date_cvterm_id = $harvest_date_cvterm->cvterm_id;


	my $planting_date_cvterm = $cvterm_rs->search( 
	    { name => 'planting_date', } )->single;
	
	print "Updating existing cvterm 'planting_date' \n";
	if ($planting_date_cvterm) {
	    $planting_date_cvterm->update( { name => 'project_planting_date'},);
	} else { 
	    $planting_date_cvterm = $cvterm_rs->search( { name => 'project_planting_date' } )->single;
	}
	my $planting_date_cvterm_id = $planting_date_cvterm->cvterm_id;
	####
	
	#redundant cvterms that should nopt be used
	my $old_harvest_cvterm = $cvterm_rs->search( 
	    { name => 'project harvest date', } )->single;
	my $old_planting_cvterm = $cvterm_rs->search(
	    { name => 'project planting date' , })->single;
	
	#update type_ids in projecprop table
	if ($old_harvest_cvterm ) {
	    my $harvest_projectprops = $schema->resultset("Project::Projectprop")->search(
		{ type_id => $old_harvest_cvterm->cvterm_id , } );
	    $harvest_projectprops->update( { type_id => $harvest_date_cvterm_id , });
	    $old_harvest_cvterm->delete;
	}
	if ($old_planting_cvterm) {
	    my $planting_projectprops = $schema->resultset("Project::Projectprop")->search(
		{ type_id => $old_planting_cvterm->cvterm_id , } );
	    $planting_projectprops->update( { type_id => $planting_date_cvterm_id , });
	   
	    #delete redundant cvterms
	    $old_planting_cvterm->delete; 
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
