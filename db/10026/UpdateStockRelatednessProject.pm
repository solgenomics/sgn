#!/usr/bin/env perl


=head1 NAME

 UpdateStockRelatednessProject.pm

=head1 SYNOPSIS

mx-run UpdateStockRelatednessProject [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

Adds the project_id field to stock_relatedness
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package UpdateStockRelatednessProject;

use Moose;
use SGN::Model::Cvterm;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
Adds the project_id field to stock_relatedness

has '+prereq' => (
    default => sub {
        [],
    },
  );

sub patch {
    my $self=shift;
    my $schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    $self->dbh->do(<<EOSQL);
--do your SQL here
--

ALTER TABLE stock_relatedness ADD COLUMN nd_experiment_id INT REFERENCES nd_experiment (nd_experiment_id) ON DELETE CASCADE;
ALTER TABLE stock_relatedness ADD COLUMN project_id INT REFERENCES project (project_id) ON DELETE SET NULL;

EOSQL


print "You're done!\n";
}


####
1; #
####
