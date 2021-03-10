#!/usr/bin/env perl


=head1 NAME

AddNdProtocolTerms.pm

=head1 SYNOPSIS

mx-run AddNdProtocolTerms [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch adds a sequence_metadata_protocol term to the protocol_type cv and a sequence_metadata_protocol_properties term to the protocol_property cv
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddNdProtocolTerms;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch adds a sequence_metadata_protocol term to the protocol_type cv and a sequence_metadata_protocol_properties term to the protocol_property cv

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
    my $cvterm_rs = $schema->resultset("Cv::Cvterm");

    print STDERR "ADDING CVTERMS...\n";
    $cvterm_rs->create_with({
		name => 'sequence_metadata_protocol',
		cv => 'protocol_type'
	});
    $cvterm_rs->create_with({
		name => 'sequence_metadata_protocol_properties',
		cv => 'protocol_property'
	});
    
    print "You're done!\n";
}


####
1; #
####
