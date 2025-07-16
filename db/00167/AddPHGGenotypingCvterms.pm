#!/usr/bin/env perl


=head1 NAME

 AddPHGGenotypingCvterms

=head1 SYNOPSIS

mx-run AddPHGGenotypingCvterms [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION
This patch adds pcr_marker_details, pcr_marker_genotyping and pcr_marker_protocol cvterms
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

Isaak Y Tecle <iyt2@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddPHGGenotypingCvterms;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch adds the 'vcf_phg_genotyping' and 'phg genotyping'  genotype_property cvterms.

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
            'vcf_phg_genotyping',
            'phg genotyping'
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
