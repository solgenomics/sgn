#!/usr/bin/env perl


=head1 NAME

AddComposedTraitCv

=head1 SYNOPSIS

mx-run AddComposedTraitCv [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

Adds a composed trait cv with namespace COMP
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

Bryan Ellerbrock<bje24@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2011 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddComposedTraitCv;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
Adds the Bio::Chado:Schema cvprop table to databases where it is missing, and adds a composed trait cv



sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    $self->dbh->do(<<EOSQL);
--do your SQL here


-- add cv and db for composed traits
INSERT into db (name) values ('COMP');
CREATE SEQUENCE postcomposed_trait_ids;
ALTER SEQUENCE postcomposed_trait_ids OWNER TO web_usr;
INSERT INTO cvprop (cv_id,type_id) values ()
GRANT ALL ON TABLE cvterm_relationship to web_usr;
INSERT into cv (name) values ('composed_traits');

INSERT into cv (name) values ('cv_type');
ALTER TABLE sgn.cvprop SET SCHEMA public;
INSERT into cvterm (cv_id,name) select cv_id, 'trait_component_ontology' from cv where cv.name = 'cv_type';
INSERT into cvterm (cv_id,name) select cv_id, 'entity_ontology' from cv where cv.name = 'cv_type';
INSERT into cvterm (cv_id,name) select cv_id, 'quality_ontology' from cv where cv.name = 'cv_type';
INSERT into cvterm (cv_id,name) select cv_id, 'unit_ontology' from cv where cv.name = 'cv_type';
INSERT into cvterm (cv_id,name) select cv_id, 'time_ontology' from cv where cv.name = 'cv_type';
INSERT INTO cvprop (cv_id,type_id) select cv_id, cvterm_id from cv join cvterm on true where cv.name = 'cass_tissue_ontology' AND cvterm.name = 'trait_component_ontology';
INSERT INTO cvprop (cv_id,type_id) select cv_id, cvterm_id from cv join cvterm on true where cv.name = 'cass_tissue_ontology' AND cvterm.name = 'entity_ontology';



INSERT into dbxref (db_id, accession) select db_id, nextval('postcomposed_trait_ids') from db where name = 'COMP';
INSERT into cvterm (cv_id,name,dbxref_id) select cv_id, 'Composed traits', dbxref_id from cv join db on true AND db.name = 'COMP' join dbxref using(db_id) where cv.name = 'composed_traits';



EOSQL

print "You're done!\n";
}


####
1; #
####
