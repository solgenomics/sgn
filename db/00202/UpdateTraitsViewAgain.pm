#!/usr/bin/env perl


=head1 NAME

UpdateTraitsViewAgain.pm

=head1 SYNOPSIS

mx-run UpdateTraitsViewAgain [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.



=head1 DESCRIPTION

A previous patch did not update the trait view correctly ( for example, AddSubplotToMatview.pm)
This is essentially a copy of dbpatch db/00195/UpdateTraitsView.pm, which fixed the same issue
previously.

=head1 AUTHOR

Naama Menda <nm249@cornell.edu> - original patch
Lukas Mueller <lam87@cornell.edu> for this copy

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package UpdateTraitsViewAgain;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch updates the public.traits view


sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    $self->dbh->do(<<EOSQL);
--do your SQL here


DROP VIEW IF EXISTS public.traits CASCADE;
CREATE VIEW public.traits AS
  SELECT cvterm.cvterm_id AS trait_id,
  (((cvterm.name::text || '|'::text) || db.name::text) || ':'::text) || dbxref.accession::text AS trait_name
	FROM cv
    JOIN cvprop ON(cv.cv_id = cvprop.cv_id AND cvprop.type_id IN (SELECT cvterm_id from cvterm where cvterm.name = 'trait_ontology'))
    JOIN cvterm ON(cvprop.cv_id = cvterm.cv_id)
	  JOIN dbxref USING(dbxref_id)
    JOIN db ON(dbxref.db_id = db.db_id)
    LEFT JOIN cvterm_relationship is_variable ON cvterm.cvterm_id = is_variable.subject_id AND is_variable.type_id = (SELECT cvterm_id FROM cvterm WHERE name = 'VARIABLE_OF' AND cv_id = (SELECT cv_id FROM cv where cv.name = 'relationship') )
    WHERE is_variable.subject_id IS NOT NULL
    GROUP BY 1,2
  UNION
  SELECT cvterm.cvterm_id AS trait_id,
  (((cvterm.name::text || '|'::text) || db.name::text) || ':'::text) || dbxref.accession::text AS trait_name
  FROM cv
    JOIN cvprop ON(cv.cv_id = cvprop.cv_id AND cvprop.type_id IN (SELECT cvterm_id from cvterm where cvterm.name = 'composed_trait_ontology'))
    JOIN cvterm ON(cvprop.cv_id = cvterm.cv_id)
    JOIN dbxref USING(dbxref_id)
    JOIN db ON(dbxref.db_id = db.db_id)
    LEFT JOIN cvterm_relationship is_subject ON cvterm.cvterm_id = is_subject.subject_id
    WHERE is_subject.subject_id IS NOT NULL
    GROUP BY 1,2 ORDER BY 2;
    ALTER VIEW traits OWNER TO web_usr;

EOSQL

print "You're done!\n";
}


####
1; #
####
