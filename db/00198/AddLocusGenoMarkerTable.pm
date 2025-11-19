#!/usr/bin/env perl

=head1 NAME

AddLocusGenoMarker

=head1 SYNOPSIS

mx-run AddLocusGenoMarker [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch adds the phenome.locus_geno_marker table which will be used to link a marker from an nd_protocol to 
a locus (and then alleles) in the phenome.locus table.

=head1 AUTHOR

David Waring <djw64@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddLocusGenoMarkerTable;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;

extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch creates the phenome.locus_geno_marker table


sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";
    my $schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );

    my $coderef = sub {
        $self->dbh->do(<<EOSQL);

--do your SQL here

CREATE TABLE IF NOT EXISTS phenome.locus_geno_marker (
   locus_geno_marker_id serial primary key,
   nd_protocol_id int references public.nd_protocol(nd_protocol_id),
   marker_name text,
   locus_id int references phenome.locus(locus_id)
);

GRANT select,insert,update,delete ON phenome.locus_geno_marker TO web_usr;
GRANT USAGE ON phenome.locus_geno_marker_locus_geno_marker_id_seq TO web_usr;

EOSQL

        return 1;
    };

    try {
        $schema->txn_do($coderef);
    } catch {
        die "Load failed! " . $_ .  "\n" ;
    };
    print "You're done!\n";
}


####
1; #
####
