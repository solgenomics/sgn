#!/usr/bin/env perl


=head1 NAME

AddGenotypeProjectViews.pm

=head1 SYNOPSIS

mx-run AddGenotypeProjectViews [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch:
 - updates the materialized_genoview matview to include genotype project id column
 - adds the binary genotype_project views

=head1 AUTHOR

David Waring <djw64@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddGenotypeProjectViews;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch updates the materialized_genoview matview and adds the genotype project binary views


sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    $self->dbh->do(<<EOSQL);
--do your SQL here


-- drop and recreate genoview with new column for genotype project id

DROP MATERIALIZED VIEW IF EXISTS public.materialized_genoview CASCADE;
CREATE MATERIALIZED VIEW public.materialized_genoview AS
SELECT stock.stock_id AS accession_id,
     nd_experiment_protocol.nd_protocol_id AS genotyping_protocol_id,
     nd_experiment_project.project_id AS genotyping_project_id,
     genotype.genotype_id AS genotype_id,
     stock_type.name AS stock_type
    FROM stock
      JOIN cvterm AS stock_type ON (stock_type.cvterm_id = stock.type_id AND stock_type.name = 'accession')
      JOIN nd_experiment_stock ON stock.stock_id = nd_experiment_stock.stock_id
      JOIN nd_experiment_protocol ON nd_experiment_stock.nd_experiment_id = nd_experiment_protocol.nd_experiment_id
      LEFT JOIN nd_experiment_project ON nd_experiment_stock.nd_experiment_id = nd_experiment_project.nd_experiment_id
      JOIN nd_protocol ON nd_experiment_protocol.nd_protocol_id = nd_protocol.nd_protocol_id
      JOIN nd_experiment_genotype ON nd_experiment_stock.nd_experiment_id = nd_experiment_genotype.nd_experiment_id
      JOIN genotype ON genotype.genotype_id = nd_experiment_genotype.genotype_id
   GROUP BY 1,2,3,4,5
UNION
SELECT accession.stock_id AS accession_id,
    nd_experiment_protocol.nd_protocol_id AS genotyping_protocol_id,
    nd_experiment_project.project_id AS genotyping_project_id,
    nd_experiment_genotype.genotype_id AS genotype_id,
    stock_type.name AS stock_type
    FROM stock AS accession
      JOIN stock_relationship ON accession.stock_id = stock_relationship.object_id AND stock_relationship.type_id IN (SELECT cvterm_id from cvterm where cvterm.name IN ('tissue_sample_of', 'plant_of', 'plot_of') )
      JOIN stock ON stock_relationship.subject_id = stock.stock_id AND stock.type_id IN (SELECT cvterm_id from cvterm where cvterm.name IN ('tissue_sample', 'plant', 'plot') )
      JOIN cvterm AS stock_type ON (stock_type.cvterm_id = stock.type_id)
     JOIN nd_experiment_stock ON stock.stock_id = nd_experiment_stock.stock_id
     JOIN nd_experiment_protocol ON nd_experiment_stock.nd_experiment_id = nd_experiment_protocol.nd_experiment_id
     LEFT JOIN nd_experiment_project ON nd_experiment_stock.nd_experiment_id = nd_experiment_project.nd_experiment_id
     JOIN nd_protocol ON nd_experiment_protocol.nd_protocol_id = nd_protocol.nd_protocol_id
     JOIN nd_experiment_genotype ON nd_experiment_stock.nd_experiment_id = nd_experiment_genotype.nd_experiment_id
  GROUP BY 1,2,3,4,5 ORDER BY 1,2,3,4;
CREATE UNIQUE INDEX unq_geno_idx ON public.materialized_genoview(accession_id,genotype_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW materialized_genoview OWNER TO web_usr;
REFRESH MATERIALIZED VIEW materialized_genoview;



EOSQL

print "You're done!\n";
}


####
1; #
####
