#!/usr/bin/env perl


=head1 NAME

 AddGraftingCvterms.pm

=head1 SYNOPSIS

mx-run ThisPackageName [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION
This patch adds the necessary cvterms that are used for storing grafted stocks,
rootstock-scion stock_relationship, grafting_experiment ,and missing project types 


This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

 Naama Menda<nm249@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddGraftingCvterms;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
Add missing cvterms for storing grafted stocks, and grafting experiments or projects 

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


    print STDERR "INSERTING CVTERMS...\n";

    my $terms = {
	'stock_type' => [
	    'grafted_accession',
	    ],
	    'stock_relationship'  => [
		'rootstock_of',
		'scion_of',
	    ],
	    'experiment_type'  => [
		'grafting_experiment',
	    ],
	    'project_type'     => [
		'crossing_trial',
		'grafting_trial',
		'pollinating_trial'
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
