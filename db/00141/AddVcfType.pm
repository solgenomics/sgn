#!/usr/bin/env perl


=head1 NAME

 AddVcfType.pm

=head1 SYNOPSIS

mx-run ThisPackageName [options] -H hostname -D dbname -u username [-F]

This patch add new cvterm vcf_snp_dbxref to nd_protocol

=head1 DESCRIPTION

This dbpatch adds vcf_snp_dbxref to nd_protocol and nd_protocolprop to provide external links to marker_names


=head1 AUTHOR

 Clay Birkett<clb343@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddVcfType;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;
extends 'CXGN::Metadata::Dbpatch';

has '+description' => ( default => <<'' );
This patch add new cvterm vcf_snp_dbxref to nd_protocol

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

	my $term = 'vcf_snp_dbxref';

	$schema->resultset("Cv::Cvterm")->create_with( {
		name => $term,
		cv => 'protocol_property', }
		);


print "You're done!\n";
}


####
1; #
####
