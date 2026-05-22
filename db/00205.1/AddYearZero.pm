#!/usr/bin/env perl

=head1 NAME

AddYearZero.pm

=head1 SYNOPSIS

mx-run AddYearZero [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch:
 - Add a new project property year_zero

=head1 AUTHOR

Katherine Eaton

=head1 COPYRIGHT & LICENSE

Copyright 2026 University of Alberta

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

package AddYearZero;

use Moose;
use Bio::Chado::Schema;
extends 'CXGN::Metadata::Dbpatch';

has '+description' => ( default => <<'' );
This patch adds a new project property year_zero.

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDERR "INSERTING CV TERMS...\n";

    my $schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );
    $schema->resultset("Cv::Cvterm")->create_with({ name => 'year_0', cv => 'project_property' });

    print "You're done!\n";
}

####
1; #
####
