#!/usr/bin/env perl


=head1 NAME

RedefineStockViews.pm

=head1 SYNOPSIS

mx-run RedefineStockViews [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch updates the materialized views that store stocks (accessions, plots, plants) to exclude obsolete stocks

=head1 AUTHOR

Bryan Ellerbrock<bje24@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package RedefineStockViews;

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

DROP MATERIALIZED VIEW public.accessions;

CREATE MATERIALIZED VIEW public.accessions AS
  SELECT stock.stock_id AS accession_id,
  stock.uniquename AS accession_name
  FROM stock
  WHERE stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'accession') AND is_obsolete = 'f'
  GROUP BY stock.stock_id, stock.uniquename
  WITH DATA;
CREATE UNIQUE INDEX accessions_idx ON public.accessions(accession_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW accessions OWNER TO web_usr;

DROP MATERIALIZED VIEW public.plots;

CREATE MATERIALIZED VIEW public.plots AS
SELECT stock.stock_id AS plot_id,
    stock.uniquename AS plot_name
   FROM stock
   WHERE stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plot') AND is_obsolete = 'f'
  GROUP BY public.stock.stock_id, public.stock.uniquename
WITH DATA;
CREATE UNIQUE INDEX plots_idx ON public.plots(plot_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW plots OWNER TO web_usr;

DROP MATERIALIZED VIEW public.plants;

CREATE MATERIALIZED VIEW public.plants AS
SELECT stock.stock_id AS plant_id,
    stock.uniquename AS plant_name
   FROM stock
   WHERE stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plant') AND is_obsolete = 'f'
  GROUP BY public.stock.stock_id, public.stock.uniquename
WITH DATA;
CREATE UNIQUE INDEX plants_idx ON public.plants(plant_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW plants OWNER TO web_usr;

--

EOSQL

print "You're done!\n";
}


####
1; #
####
