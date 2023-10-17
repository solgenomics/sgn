#!/usr/bin/env perl


=head1 NAME

 AddCamelinaSativaOrganism

=head1 SYNOPSIS

mx-run AddCamelinaSativaOrganism [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION
This patch saves camelina sativa species
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

Nick Morales<nm529@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddCamelinaSativaOrganism;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;
use SGN::Model::Cvterm;
use JSON;
use Data::Dumper;

extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch saves saves camelina sativa species

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

    try {
        my $q_vendor = "INSERT INTO organism (abbreviation, genus, species, common_name) VALUES (?,?,?,?);";
        my $h_vendor = $schema->storage->dbh()->prepare($q_vendor);
        $h_vendor->execute('C. sativa', 'Camelina', 'Camelina sativa', 'false flax,gold-of-pleasure');
    };

    print "You're done!\n";
}


####
1; #
####
