#!/usr/bin/env perl


=head1 NAME

 AddPCRMarkerCvterms

=head1 SYNOPSIS

mx-run AddPCRMarkerCvterms [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION
This patch adds pcr_marker_details, pcr_marker_genotyping and pcr_marker_protocol cvterms
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

Titima Tantikanjana <tt15@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddPCRMarkerCvterms;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch adds the 'pcr_marker_details' protocol_property cvterm, 'pcr_marker_genotyping' genotype_property cvterm and pcr_marker_protocol protocol_type cvterm.

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
        'genotype_property' => [
            'pcr_marker_genotyping',
        ],
        'protocol_property' => [
            'pcr_marker_details'
        ],
        'protocol_type' => [
            'pcr_marker_protocol'
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
