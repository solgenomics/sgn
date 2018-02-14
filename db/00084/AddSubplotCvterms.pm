#!/usr/bin/env perl


=head1 NAME

 AddSubplotCvterms.pm

=head1 SYNOPSIS

mx-run AddSubplotCvterms [options] -H hostname -D dbname -u username [-F]

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


package AddSubplotCvterms;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
Adds subplot stock_type, subplot_index_number stockprop, and subplot_of stock_relationship cvterms.

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
		'stock_type' => [
			'subplot',
		],
		'stock_property' => [
			'subplot_index_number',
		],
		'stock_relationship' => [
			'subplot_of',
			'plant_of_subplot'
		],
		'list_types' => [
			'subplots'
		],
		'project_property' => [
			'project_has_subplot_entries'
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
