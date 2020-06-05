#!/usr/bin/env perl


=head1 NAME

 AddAnalysisAndMixedModelCvterms

=head1 SYNOPSIS

mx-run  AddAnalysisAndMixedModelCvterms [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This dbpatch adds cvterms required for mixed models and analysis features.

=head1 AUTHOR

  Lukas Mueller <lam87@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2019 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddAnalysisAndMixedModelCvterms;

use Moose;
use Bio::Chado::Schema;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
Adds cvterms required for mixed models and analysis features

has '+prereq' => (
    default => sub {
        [],
    },
  );

sub patch {
    my $self=shift;
    
    print STDERR "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";
    
    print STDERR "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";
    
    print STDERR "\nExecuting the SQL commands.\n";
    
    my $schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );
    
    
    
    print STDERR "INSERTING CV TERMS...\n";
    
    $self->dbh->do("INSERT INTO nd_geolocation (description) values ('[Computation]')");
    
    my $terms = { 
	project_property => 
	    [
	     "analysis_project",
	     "project_sp_person_id",
	     "analysis_metadata_json",
	    ],
	    
	    stock_type => 
	    [
	     "analysis_instance",
	    ],
	    experiment_type =>
	    [
	     "analysis_experiment",
	    ],
	    stock_relationship =>
	    [
	     "analysis_of",
	    ],
    };
    

    
    foreach my $t (sort keys %$terms){
	foreach (@{$terms->{$t}}){
	    $schema->resultset("Cv::Cvterm")->create_with(
		{
		    name => $_,
		    cv => $t
		});
	}
    }
    print STDERR "Patch complete\n";
}


####
1; #
####
