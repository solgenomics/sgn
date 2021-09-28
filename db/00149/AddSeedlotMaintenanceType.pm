#!/usr/bin/env perl


=head1 NAME

 AddSeedlotMaintenanceType.pm

=head1 SYNOPSIS

mx-run AddSeedlotMaintenanceType [options] -H hostname -D dbname -u username [-F]

=head1 DESCRIPTION

This patch adds the cvterm 'seedlot_maintenance_json' to the 'stock_property' cv

=head1 AUTHOR

David Waring <djw64@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddSeedlotMaintenanceType;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;
extends 'CXGN::Metadata::Dbpatch';

has '+description' => ( default => <<'' );
This patch adds the cvterm 'seedlot_maintenance_json' to the 'stock_property' cv

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
    my $term = 'seedlot_maintenance_json';
    $schema->resultset("Cv::Cvterm")->create_with({
      name => $term,
      cv => 'stock_property'
    });

    print "You're done!\n";
}


####
1; #
####
