#!/usr/bin/env perl


=head1 NAME

 AddNdExperimentProperty

=head1 SYNOPSIS

mx-run ThisPackageName [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch adds additional properties to the nd_experiment_property cvterm in the cxgn database

This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

 Alex Ogbonna<aco46@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddNdExperimentProperty;

use Moose;
use Try::Tiny;
use Bio::Chado::Schema;

extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch will add number_of_fruits, number_of_seeds_planted and number_of_seedlings_transplanted cvterms to the nd_experiment_property cv.

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


      my %cvterms =
      (

    	'nd_experiment_property' => [ 'number_of_fruits',
    				      'number_of_seeds_planted',
    				      'number_of_seedlings_transplanted' ]

        );


        my $schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );


        my $coderef = sub {


            foreach my $cv_name ( keys  %cvterms  ) {
    	    print "\nKEY = $cv_name \n\n";
    	    my @cvterm_names = @{$cvterms{ $cv_name } }  ;

    	    foreach  my $cvterm_name ( @cvterm_names ) {
    		print "cvterm= $cvterm_name \n";
    		my $new_cvterm = $schema->resultset("Cv::Cvterm")->create_with(
    		    {
    			name => $cvterm_name,
    			cv   => $cv_name,
    		    });
    	    }
    	}
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
