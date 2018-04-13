#!/usr/bin/env perl


=head1 NAME

 AddBrAPIPropertyCvterms.pm

=head1 SYNOPSIS

mx-run ThisPackageName [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION
This patch adds the necessary cvterms that are used for brapi germplasm, programs, and studies.
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

 Nick Morales

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddBrAPIPropertyCvterms;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
Description of this patch goes here

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


    print STDERR "INSERTING CV TERMS...\n";

    my $terms = {
		'stock_property' => [
			'accession number',
			'PUI',
			'donor',
			'donor institute',
			'donor PUI',
			'seed source',
			'institute code',
			'institute name',
			'biological status of accession code',
			'country of origin',
			'type of germplasm storage code',
			'entry number',
			'acquisition date'
		],
		'project_property' => [
			'active',
			'breeding_program_abbreviation'
		],
		'cvterm_property' => [
			'uri',
			#'date determined',
			'datatype',
			'code'
		],
		'geolocation_property' => [
			'country_name',
			'country_code',
			'abbreviation',
			'location_type',
			'annual_total_precipitation',
			'continent',
			'annual_mean_temperature',
			'adm1',
			'adm2',
			'adm3',
			'local_name',
			'region',
			'alternative_name'
		],
		'organism_property' => [
			'species authority',
			'subtaxa',
			'subtaxa authority',
		],
		'protocol_property' => [
			'published date',
			'protocol type',
			'protocol unit',
			'protocol comment'
		]
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
