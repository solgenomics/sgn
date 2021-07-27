#!/usr/bin/env perl


=head1 NAME

 FixPhenomeGenotypingTable.pm

=head1 SYNOPSIS

mx-run ThisPackageName [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This is a test dummy patch.
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

 Naama Menda<nm249@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package FixPhenomeGenotypingTable;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
Rename phenome.genotype table to phenome.phenome_genotype along with all genotype_id fields in the phenome schema

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

ALTER TABLE phenome.genotype RENAME TO phenome_genotype;
ALTER TABLE phenome.phenome_genotype RENAME COLUMN genotype_id TO phenome_genotype_id;
ALTER TABLE phenome.genotype_region RENAME COLUMN genotype_id TO phenome_genotype_id;    
ALTER TABLE phenome.polymorphic_fragment RENAME COLUMN genotype_id TO phenome_genotype_id;    
      
EOSQL
	

print "You're done!\n";
}


####
1; #
####
