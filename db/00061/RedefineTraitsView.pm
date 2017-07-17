#!/usr/bin/env perl


=head1 NAME

RedefineTraitsView.pm

=head1 SYNOPSIS

mx-run RedefineTraitsView [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch updates the materialized view that stores traits

=head1 AUTHOR

Bryan Ellerbrock<bje24@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package RedefineTraitsView;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch updates the materialized view that stores traits

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    $self->dbh->do(<<EOSQL);
--do your SQL here

DROP MATERIALIZED VIEW public.traits;

CREATE MATERIALIZED VIEW public.traits AS
SELECT   cvterm.cvterm_id AS trait_id,
  (((cvterm.name::text || '|'::text) || db.name::text) || ':'::text) || dbxref.accession::text AS trait_name
  FROM cvterm
  JOIN dbxref ON cvterm.dbxref_id = dbxref.dbxref_id
  JOIN db ON dbxref.db_id = db.db_id
  WHERE cvterm.cvterm_id IN (SELECT cvterm_relationship.subject_id FROM cvterm_relationship JOIN cvterm on (cvterm_relationship.subject_id = cvterm.cvterm_id) where cvterm_relationship.type_id = (SELECT cvterm_id from cvterm where name = 'VARIABLE_OF') GROUP BY 1)
  AND db.db_id =
(SELECT dbxref.db_id
   FROM stock
   JOIN nd_experiment_stock USING(stock_id)
   JOIN nd_experiment_phenotype USING(nd_experiment_id)
   JOIN phenotype USING(phenotype_id)
   JOIN cvterm ON phenotype.cvalue_id = cvterm.cvterm_id
   JOIN dbxref ON cvterm.dbxref_id = dbxref.dbxref_id LIMIT 1)
   GROUP BY public.cvterm.cvterm_id, trait_name
WITH DATA;
CREATE UNIQUE INDEX traits_idx ON public.traits(trait_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW traits OWNER TO web_usr;

--

EOSQL

print "You're done!\n";
}


####
1; #
####
