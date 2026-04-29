#!/usr/bin/env perl

=head1 NAME

AddTreeImprovementTrials.pm

=head1 SYNOPSIS

mx-run AddTreeImprovementTrials [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch:
 - Adds new trial types: Progeny, Provenance, Wild Tree Selection

=head1 AUTHOR

Katherine Eaton

=head1 COPYRIGHT & LICENSE

Copyright 2025 University of Alberta

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

package AddTreeImprovementTrials;

use Moose;
use Bio::Chado::Schema;
extends 'CXGN::Metadata::Dbpatch';

has '+description' => ( default => <<'' );
This patch adds new cvterms for tree improvement trial types.

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";
    my $schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );

    print STDERR "INSERTING CV TERMS...\n";

    $schema->resultset("Cv::Cvterm")->create_with({ name => 'Progeny Trial', cv => 'project_type' });
    $schema->resultset("Cv::Cvterm")->create_with({ name => 'Provenance Trial', cv => 'project_type' });
    $schema->resultset("Cv::Cvterm")->create_with({ name => 'Wild Tree Selection', cv => 'project_type' });

    print "You're done!\n";
}

####
1; #
####
