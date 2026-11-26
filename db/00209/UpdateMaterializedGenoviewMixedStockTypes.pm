#!/usr/bin/env perl


=head1 NAME

UpdateMaterializedGenoviewMixedStockTypes.pm

=head1 SYNOPSIS

mx-run UpdateMaterializedGenoviewMixedStockTypes [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch rebuilds materialized_genoview so that genotypes stored on plots,
subplots, plants and tissue samples are mapped to their accession:

 - subplots (subplot_of) are now included; previously only tissue_sample, plant
   and plot were mapped, so subplot genotypes never reached the wizard
 - stocks one level removed from the accession (e.g. a tissue sample whose
   only link is tissue_sample_of -> plant/subplot/plot -> accession) are mapped
 - the accession_id column now only ever holds accession stock_ids (before,
   tissue_sample_of -> plot rows put the plot's id in accession_id)

The views that depend on materialized_genoview are saved and recreated
unchanged, since the matview has to be dropped with CASCADE.

=head1 AUTHOR

=head1 COPYRIGHT & LICENSE

Copyright 2026 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

package UpdateMaterializedGenoviewMixedStockTypes;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
Rebuild materialized_genoview so subplot, plant, plot and tissue_sample genotypes map to their accession in the search wizard


sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    $self->dbh->do(<<'EOSQL');
-- save the definitions of all views built on materialized_genoview
CREATE TEMP TABLE genoview_dependent_views AS
SELECT DISTINCT c.relname AS view_name,
    pg_get_viewdef(c.oid) AS view_def,
    pg_get_userbyid(c.relowner) AS view_owner
FROM pg_depend d
JOIN pg_rewrite r ON r.oid = d.objid
JOIN pg_class c ON c.oid = r.ev_class
WHERE d.refobjid = 'public.materialized_genoview'::regclass
  AND c.oid <> 'public.materialized_genoview'::regclass
  AND c.relkind = 'v';

DROP MATERIALIZED VIEW IF EXISTS public.materialized_genoview CASCADE;
CREATE MATERIALIZED VIEW public.materialized_genoview AS
    WITH genotyped AS (
        SELECT nd_experiment_stock.stock_id,
            nd_experiment_protocol.nd_protocol_id AS genotyping_protocol_id,
            nd_experiment_project.project_id AS genotyping_project_id,
            nd_experiment_genotype.genotype_id
        FROM nd_experiment_genotype
        JOIN nd_experiment_stock ON nd_experiment_stock.nd_experiment_id = nd_experiment_genotype.nd_experiment_id
        JOIN nd_experiment_protocol ON nd_experiment_protocol.nd_experiment_id = nd_experiment_genotype.nd_experiment_id
        LEFT JOIN nd_experiment_project ON nd_experiment_project.nd_experiment_id = nd_experiment_genotype.nd_experiment_id
    ),
    genotyped_stock AS (
        SELECT DISTINCT stock.stock_id, stock.type_id
        FROM genotyped JOIN stock ON stock.stock_id = genotyped.stock_id
    ),
    stock_accession AS (
        -- genotype stored directly on the accession
        SELECT gs.stock_id, gs.stock_id AS accession_id
        FROM genotyped_stock gs
        WHERE gs.type_id = (SELECT cvterm_id FROM cvterm WHERE name = 'accession' AND cv_id = (SELECT cv_id FROM cv WHERE name = 'stock_type'))
        UNION
        -- plot/subplot/plant/tissue_sample linked directly to its accession
        SELECT gs.stock_id, sr.object_id
        FROM genotyped_stock gs
        JOIN stock_relationship sr ON sr.subject_id = gs.stock_id
            AND sr.type_id IN (SELECT cvterm_id FROM cvterm WHERE name IN ('plot_of','subplot_of','plant_of','tissue_sample_of'))
        JOIN stock acc ON acc.stock_id = sr.object_id
            AND acc.type_id = (SELECT cvterm_id FROM cvterm WHERE name = 'accession' AND cv_id = (SELECT cv_id FROM cv WHERE name = 'stock_type'))
        WHERE gs.type_id IN (SELECT cvterm_id FROM cvterm WHERE name IN ('plot','subplot','plant','tissue_sample') AND cv_id = (SELECT cv_id FROM cv WHERE name = 'stock_type'))
        UNION
        -- one level removed, e.g. tissue_sample -> plant/subplot/plot -> accession
        SELECT gs.stock_id, sr2.object_id
        FROM genotyped_stock gs
        JOIN stock_relationship sr1 ON sr1.subject_id = gs.stock_id
            AND sr1.type_id IN (SELECT cvterm_id FROM cvterm WHERE name IN ('plot_of','subplot_of','plant_of','plant_of_subplot','tissue_sample_of'))
        JOIN stock_relationship sr2 ON sr2.subject_id = sr1.object_id
            AND sr2.type_id IN (SELECT cvterm_id FROM cvterm WHERE name IN ('plot_of','subplot_of','plant_of','tissue_sample_of'))
        JOIN stock acc ON acc.stock_id = sr2.object_id
            AND acc.type_id = (SELECT cvterm_id FROM cvterm WHERE name = 'accession' AND cv_id = (SELECT cv_id FROM cv WHERE name = 'stock_type'))
        WHERE gs.type_id IN (SELECT cvterm_id FROM cvterm WHERE name IN ('plot','subplot','plant','tissue_sample') AND cv_id = (SELECT cv_id FROM cv WHERE name = 'stock_type'))
    )
    SELECT stock_accession.accession_id,
        genotyped.genotyping_protocol_id,
        genotyped.genotyping_project_id,
        genotyped.genotype_id,
        stock_type.name AS stock_type
    FROM genotyped
    JOIN stock_accession ON stock_accession.stock_id = genotyped.stock_id
    JOIN stock ON stock.stock_id = genotyped.stock_id
    JOIN cvterm AS stock_type ON stock_type.cvterm_id = stock.type_id
    GROUP BY 1,2,3,4,5
WITH DATA;
CREATE UNIQUE INDEX unq_geno_idx ON public.materialized_genoview(accession_id,genotype_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.materialized_genoview OWNER TO web_usr;

-- recreate the dependent views exactly as they were
DO $$
DECLARE
    v RECORD;
BEGIN
    FOR v IN SELECT * FROM genoview_dependent_views LOOP
        EXECUTE format('CREATE VIEW public.%I AS %s', v.view_name, v.view_def);
        EXECUTE format('ALTER VIEW public.%I OWNER TO %I', v.view_name, v.view_owner);
    END LOOP;
END
$$;

DROP TABLE genoview_dependent_views;
EOSQL

print "You're done!\n";
}


####
1; #
####
