#!/usr/bin/env perl


=head1 NAME

 UpdateNewProjectProps

=head1 SYNOPSIS

mx-run ThisPackageName [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch updates cvterm name from 
Genetic Gain to genetic_gain_trial, 
Health Status to health_status_trial,
Heterosis to heterosis_trial
Storage to storage_trial

This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

 Alex Ogbonna<aco46@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package UpdateNewProjectProps;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;

extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch will update the cvterm name of 
Genetic Gain -> genetic_gain_trial
Health Status -> health_status_trial
Heterosis -> heterosis_trial
Storage -> storage_trial


has '+prereq' => (
    default => sub {
        ['AddNewProjectType'],
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
  	       my $project_type_cv = $cv_rs->find( { name => 'project_type' });
           
          my %cvterm_hash = ( 
                               'Genetic Gain' => 'genetic_gain_trial',
                               'Health Status' => 'health_status_trial',
                               'Heterosis'     => 'heterosis_trial',
                               'Storage'       => 'storage_trial',
                           );

        foreach my $key (keys %cvterm_hash) { 
             my $cvterm = $cvterm_rs->search( { name => $key ,  cv_id => $project_type_cv->cv_id() });
             if ($cvterm) {
              print STDERR "Updating cvterm $key to " . $cvterm_hash{$key} . "\n";
              my $cvterm_row = $cvterm->first();
              $cvterm->update( { name => $cvterm_hash{$key} } ) ;
             }
             else { print "Cannot find cvterm $key in the database \n" ; } 
        }
        
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
  
