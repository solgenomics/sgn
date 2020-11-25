#!/usr/bin/env perl


=head1 NAME

 AddProtocolColumnToNdExperimentPhenotypeBridge.pm

=head1 SYNOPSIS

mx-run ThisPackageName [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This is a patch to adds a nd_protocol_id column to the nd_experiment_phenotype_bridge table.
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR


=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddProtocolColumnToNdExperimentPhenotypeBridge;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This is a patch to adds a nd_protocol_id column to the nd_experiment_phenotype_bridge table

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

    $self->dbh->do(<<EOSQL);

ALTER TABLE public.nd_experiment_phenotype_bridge 
      ADD COLUMN nd_protocol_id integer, 
      ADD CONSTRAINT nd_experiment_phenotype_bridge_nd_protocol_id_fkey
        FOREIGN KEY (nd_protocol_id) 
            REFERENCES nd_protocol (nd_protocol_id)
            ON DELETE CASCADE;

EOSQL

print "You're done!\n";
}


####
1; #
####
