#!/usr/bin/env perl


=head1 NAME

MigrateTraitsExternalReferences.pm

=head1 SYNOPSIS

mx-run MigrateLocationsExternalReferences [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch migrates external references for traits to the new external references dbxref storage solution.

=head1 AUTHOR

Chris Tucker

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package MigrateTraitsExternalReferences;

use Moose;
use Try::Tiny;
use Bio::Chado::Schema;

extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch migrates external references for traits to the new external references dbxref storage solution.


sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";
    my $schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );

    my $coderef = sub {

        $self->dbh->do(<<EOSQL);

 --do your SQL here
--
-- Create new dbxref records for unique reference source, reference id combos
with external_references as (
	-- Get existing external references from additional info
	select cvterm.cvterm_id, reference_source, reference_id from cvterm
	join
	(
		select dbxrefprop.dbxref_id, dbxrefprop.value as reference_source from
		dbxrefprop
		join cvterm on cvterm.cvterm_id = dbxrefprop.type_id and cvterm.name = 'reference_source'
	) as reference_source_table on cvterm.dbxref_id = reference_source_table.dbxref_id
	join
	(
		select dbxrefprop.dbxref_id, dbxrefprop.value as reference_id from
		dbxrefprop
		join cvterm on cvterm.cvterm_id = dbxrefprop.type_id and cvterm.name = 'reference_id'
	) as reference_id_table on cvterm.dbxref_id = reference_id_table.dbxref_id
),
db_inserts as (
	insert into db (name)
	select distinct reference_source from external_references
	on conflict do nothing
	returning db_id
),
dxref_inserts as (
	insert into dbxref (db_id, accession)
	select distinct db.db_id, reference_id from external_references
	join db on db.name = reference_source
	on conflict do nothing
	returning dbxref.dbxref_id
)
insert into cvterm_dbxref (cvterm_id, dbxref_id)
select cvterm_id, dbxref.dbxref_id from external_references
join dbxref on reference_id = dbxref.accession
join db on reference_source = db.name
on conflict do nothing;
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
