#!/usr/bin/env perl


=head1 NAME

AddCvtypeCv

=head1 SYNOPSIS

mx-run AddCvtypeCv [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

Adds a cv type cv for distinguisihing postcomposed ontologies
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

Bryan Ellerbrock<bje24@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2011 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddCvtypeCv;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
Adds a cv type cv for distinguisihing postcomposed ontologies



sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    $self->dbh->do(<<EOSQL);
--do your SQL here


-- add cv and db for composed traits

INSERT into cv (name) values ('cv_type');
ALTER TABLE sgn.cvprop SET SCHEMA public;
INSERT into dbxref (db_id, accession) select db_id, 'trait_ontology' from db where name = 'null';
INSERT into cvterm (cv_id,name,dbxref_id) select cv_id, 'trait_ontology', dbxref_id from cv join dbxref on true where cv.name = 'cv_type' and dbxref.accession = 'trait_ontology';
INSERT into dbxref (db_id, accession) select db_id, 'composed_trait_ontology' from db where name = 'null';
INSERT into cvterm (cv_id,name,dbxref_id) select cv_id, 'composed_trait_ontology', dbxref_id from cv join dbxref on true where cv.name = 'cv_type' and dbxref.accession = 'composed_trait_ontology';
INSERT into dbxref (db_id, accession) select db_id, 'entity_ontology' from db where name = 'null';
INSERT into cvterm (cv_id,name,dbxref_id) select cv_id, 'entity_ontology', dbxref_id from cv join dbxref on true where cv.name = 'cv_type' and dbxref.accession = 'entity_ontology';
INSERT into dbxref (db_id, accession) select db_id, 'quality_ontology' from db where name = 'null';
INSERT into cvterm (cv_id,name,dbxref_id) select cv_id, 'quality_ontology', dbxref_id from cv join dbxref on true where cv.name = 'cv_type' and dbxref.accession = 'quality_ontology';
INSERT into dbxref (db_id, accession) select db_id, 'unit_ontology' from db where name = 'null';
INSERT into cvterm (cv_id,name,dbxref_id) select cv_id, 'unit_ontology', dbxref_id from cv join dbxref on true where cv.name = 'cv_type' and dbxref.accession = 'unit_ontology';
INSERT into dbxref (db_id, accession) select db_id, 'time_ontology' from db where name = 'null';
INSERT into cvterm (cv_id,name,dbxref_id) select cv_id, 'time_ontology', dbxref_id from cv join dbxref on true where cv.name = 'cv_type' and dbxref.accession = 'time_ontology';
INSERT INTO cvprop (cv_id,type_id) select cv.cv_id, cvterm_id from cv join cvterm on true where cv.name = 'cassava_trait' AND cvterm.name = 'trait_ontology';
INSERT INTO cvprop (cv_id,type_id) select cv.cv_id, cvterm_id from cv join cvterm on true where cv.name = 'composed_trait' AND cvterm.name = 'composed_trait_ontology';
INSERT INTO cvprop (cv_id,type_id) select cv.cv_id, cvterm_id from cv join cvterm on true where cv.name = 'cass_tissue_ontology' AND cvterm.name = 'entity_ontology';
INSERT INTO cvprop (cv_id,type_id) select cv.cv_id, cvterm_id from cv join cvterm on true where cv.name = 'chebi_ontology' AND cvterm.name = 'quality_ontology';
INSERT INTO cvprop (cv_id,type_id) select cv.cv_id, cvterm_id from cv join cvterm on true where cv.name = 'cass_unit_ontology' AND cvterm.name = 'unit_ontology';
INSERT INTO cvprop (cv_id,type_id) select cv.cv_id, cvterm_id from cv join cvterm on true where cv.name = 'cass_time_ontology' AND cvterm.name = 'time_ontology';

EOSQL

print "You're done!\n";
}


####
1; #
####
