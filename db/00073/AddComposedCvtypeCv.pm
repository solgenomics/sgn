#!/usr/bin/env perl


=head1 NAME

AddComposedCvtypeCv

=head1 SYNOPSIS

mx-run AddComposedCvtypeCv [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

Adds a cv type cv for distinguisihing composable ontologies
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

Bryan Ellerbrock<bje24@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2011 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddComposedCvtypeCv;

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

INSERT into cv (name) values ('composable_cvtypes');
ALTER TABLE sgn.cvprop SET SCHEMA public;
GRANT ALL ON cvprop to web_usr;
INSERT into dbxref (db_id, accession) select db_id, 'trait_ontology' from db where name = 'null';
INSERT into cvterm (cv_id,name,dbxref_id) select cv_id, 'trait_ontology', dbxref_id from cv join dbxref on true where cv.name = 'composable_cvtypes' and dbxref.accession = 'trait_ontology';
INSERT into dbxref (db_id, accession) select db_id, 'composed_trait_ontology' from db where name = 'null';
INSERT into cvterm (cv_id,name,dbxref_id) select cv_id, 'composed_trait_ontology', dbxref_id from cv join dbxref on true where cv.name = 'composable_cvtypes' and dbxref.accession = 'composed_trait_ontology';
INSERT into dbxref (db_id, accession) select db_id, 'object_ontology' from db where name = 'null';
INSERT into cvterm (cv_id,name,dbxref_id) select cv_id, 'object_ontology', dbxref_id from cv join dbxref on true where cv.name = 'composable_cvtypes' and dbxref.accession = 'object_ontology';
INSERT into dbxref (db_id, accession) select db_id, 'attribute_ontology' from db where name = 'null';
INSERT into cvterm (cv_id,name,dbxref_id) select cv_id, 'attribute_ontology', dbxref_id from cv join dbxref on true where cv.name = 'composable_cvtypes' and dbxref.accession = 'attribute_ontology';
INSERT into dbxref (db_id, accession) select db_id, 'method_ontology' from db where name = 'null';
INSERT into cvterm (cv_id,name,dbxref_id) select cv_id, 'method_ontology', dbxref_id from cv join dbxref on true where cv.name = 'composable_cvtypes' and dbxref.accession = 'method_ontology';
INSERT into dbxref (db_id, accession) select db_id, 'unit_ontology' from db where name = 'null';
INSERT into cvterm (cv_id,name,dbxref_id) select cv_id, 'unit_ontology', dbxref_id from cv join dbxref on true where cv.name = 'composable_cvtypes' and dbxref.accession = 'unit_ontology';
INSERT into dbxref (db_id, accession) select db_id, 'time_ontology' from db where name = 'null';
INSERT into cvterm (cv_id,name,dbxref_id) select cv_id, 'time_ontology', dbxref_id from cv join dbxref on true where cv.name = 'composable_cvtypes' and dbxref.accession = 'time_ontology';

EOSQL

print "You're done!\n";
}


####
1; #
####
