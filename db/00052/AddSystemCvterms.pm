#!/usr/bin/env perl


=head1 NAME

 AddSystemCvterms

=head1 SYNOPSIS

mx-run ThisPackageName [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch creates the system cvterms that are needed for the cxgn databases. 
Without these many pages and functions would not work since we are not using anymore the create_with BCS function for auto-creating new cvterms.
Instead all the needed cvterms need to be predefined in the databases.
This is important for the functionality and integrity of the databases, and for preventing overloading with redundant or obscure cvterms.

This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

 Naama Menda<nm249@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddSystemCvterms;

use Moose;
use Try::Tiny;
use Bio::Chado::Schema;

extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch will add system cvterms required for the functionality of the cxgn databases

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
	'calendar' => ['Planning Event', 
		       'Fertilizer Event',  
		       'Genotyping Event',
		       'Harvest Event',
		       'Meeting Event',
		       'Phenotyping Event',
		       'Planting Event',
		       'Presentation Event' ],
	
	'experiment_type' => [ 'cross_experiment',
			       'field_layout',
			       'genotyping_experiment',
			       'genotyping_layout',
			       'phenotyping_experiment' ],
	'genotype_property' => ['igd number',
				'snp genotyping' ],
	
	'local' => ['sp_person_id',
		    'visible_to_role' ],
	
	'nd_experiment_property' => [ 'cross_name',
				      'cross_type',
				      'genotyping_project_name',
				      'genotyping_user_id',
				      'number_of_flowers',
				      'number_of_seeds' ],

	'organism_property' => [ 'organism_synonym' ],
	
	'project_property'  => [ 'breeding_program',
				 'harvest_date',
				 'planting_date',
				 'trial_folder' ],

	'project_relationship' => [ 'breeding_program_trial_relationship' ] ,

	'project_type'         => ['Advance Yield Trial',
				   'Preliminary Yield Trial',
				   'Uniform Yield Trial' ],
	
	'stock_property'      => ['block',
				  'col_number',
				  'igd_synonym',
				  'is a control',
				  'location_code',
				  'organization',
				  'plot number',
				  'range',
				  'replicate',
				  'row_number',
				  'stock_synonym',
				  'T1',
				  'T2',
				  'transgenic' ],
	
     'stock_relationship'  =>   [ 'cross_relationship',
				  'female_parent',
				  'male_parent',
				  'member_of',
				  'offspring_of',
				  'plant_of',
				  'plot_of',
				  'tissue_sample_of' ],
     
     'stock_type'    =>  ['accession',
			  'backcross population',
			  'cross',
			  'f2 population',
			  'mutant population',
			  'plant',
			  'plot',
			  'population',
			  'tissue_sample',
			  'training population',
			  'vector_construct'  ],
     
     'trait_property' => [ 'trait_categories',
			   'trait_default_value',
			   'trait_details',
			   'trait_format',
			   'trait_maximum',
			   'trait_minimum' ]
     
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
