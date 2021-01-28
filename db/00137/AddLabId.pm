#!/usr/bin/env perl


=head1 NAME

 AddLabId.pm

=head1 SYNOPSIS

mx-run ThisPackageName [options] -H hostname -D dbname -u username [-F]

This patch add new cvterm lab_id to nd_experiment_property

=head1 DESCRIPTION

This dbpatch adds lab_id to the public_ndexperimentprop mainly for NIRs and metabolite upload tool.


=head1 AUTHOR

 Chris Simoes<ccs263@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddLabId;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;
extends 'CXGN::Metadata::Dbpatch';

has '+description' => ( default => <<'' );
This patch add new cvterm lab_id to nd_experiment_property

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

	my $term = 'lab_id';


	$schema->resultset("Cv::Cvterm")->create_with( {
		name => $term,
		cv => 'nd_experiment_property', }
		);


print "You're done!\n";
}


####
1; #
####
