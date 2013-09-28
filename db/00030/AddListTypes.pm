#!/usr/bin/env perl


=head1 NAME

 AddListTypes.pm 

=head1 SYNOPSIS

mx-run AddListTypes [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch adds a type_id field to the list table (sgn_people.list).
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

 Naama Menda<nm249@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddListTypes;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
Description of this patch goes here

has '+prereq' => (
    default => sub {
        [ ],
    },
  );

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    $self->dbh->do(<<EOSQL);
--do your SQL here
--

ALTER TABLE sgn_people.list ADD COLUMN type_id bigint REFERENCES cvterm;

INSERT INTO cv (name, definition) VALUES ('list_types', '');

INSERT INTO dbxref (db_id, accession) VALUES ((SELECT db_id FROM db WHERE name='local'), 'plots');

INSERT INTO cvterm (cv_id, name, definition, dbxref_id) VALUES ( (SELECT currval('cv_cv_id_seq')), 'plots', 'Plot names', (SELECT dbxref_id FROM dbxref WHERE accession='plots'));

INSERT INTO dbxref (db_id, accession) VALUES ((SELECT db_id FROM db WHERE name='local'), 'accessions');

INSERT INTO cvterm (cv_id, name, definition, dbxref_id) VALUES ( (SELECT currval('cv_cv_id_seq')), 'accessions', 'Accession names', (SELECT dbxref_id FROM dbxref WHERE accession='accessions'));


INSERT INTO dbxref (db_id, accession) VALUES ((SELECT db_id FROM db WHERE name='local'), 'locations');

INSERT INTO cvterm (cv_id, name, definition, dbxref_id) VALUES ( (SELECT currval('cv_cv_id_seq') ), 'locations', 'Locations', (SELECT dbxref_id FROM dbxref WHERE accession='locations'));


INSERT INTO dbxref (db_id, accession) VALUES ((SELECT db_id FROM db WHERE name='local'), 'trials' );

INSERT INTO cvterm (cv_id, name, definition, dbxref_id) VALUES ( (SELECT currval('cv_cv_id_seq') ), 'trials', 'Trial names', (SELECT dbxref_id FROM dbxref WHERE accession='trials'));


INSERT INTO dbxref (db_id, accession) VALUES ((SELECT db_id FROM db WHERE name='local'), 'traits');

INSERT INTO cvterm (cv_id, name, definition, dbxref_id) VALUES ( (SELECT currval('cv_cv_id_seq')), 'traits', 'Trait names', (SELECT dbxref_id FROM dbxref WHERE accession='traits'));


INSERT INTO dbxref (db_id, accession) VALUES ((SELECT db_id FROM db WHERE name='local'), 'years');

INSERT INTO cvterm (cv_id, name, definition, dbxref_id) VALUES ( (SELECT currval('cv_cv_id_seq') ), 'years', 'Trial years', (SELECT dbxref_id FROM dbxref WHERE accession='years'));


INSERT INTO dbxref (db_id, accession) VALUES ((SELECT db_id FROM db WHERE name='local'), 'sgn_unigene_ids');

INSERT INTO cvterm (cv_id, name, definition, dbxref_id) VALUES ( (SELECT currval('cv_cv_id_seq')), 'sgn_unigene_ids', 'SGN unigene IDs', (SELECT dbxref_id FROM dbxref WHERE accession='sgn_unigene_ids'));


INSERT INTO dbxref (db_id, accession) VALUES ((SELECT db_id FROM db WHERE name='local'), 'sgn_locus_ids');

INSERT INTO cvterm (cv_id, name, definition, dbxref_id) VALUES ( (SELECT currval('cv_cv_id_seq')), 'sgn_locus_ids', 'SGN locus IDs', (SELECT dbxref_id FROM dbxref WHERE accession='sgn_locus_ids'));


INSERT INTO dbxref (db_id, accession) VALUES ((SELECT db_id FROM db WHERE name='local'), 'organisms');

INSERT INTO cvterm (cv_id, name, definition, dbxref_id) VALUES ( (SELECT currval('cv_cv_id_seq')), 'organisms', 'Organism names', (SELECT dbxref_id FROM dbxrefs WHERE accession='organisms'));


EOSQL

print "Done!\n";
}


####
1; #
####
