#!/usr/bin/env perl


=head1 NAME

 AlterDescriptionToText.pm

=head1 SYNOPSIS

mx-run AlterDescriptionToText [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

Alters project table description column from varchar(255) to text

This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

Bryan Ellerbrock<bje24@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AlterDescriptionToText;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
Alters project table description column from varchar(255) to text
has '+prereq' => (
    default => sub {
        [''],
    },
  );

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    $self->dbh->do(<<EOSQL);
--do your SQL here
/*
Running just "ALTER TABLE project ALTER COLUMN description TYPE text"
produces

ERROR:  cannot alter type of a column used by a view or rule
DETAIL:  rule _RETURN on materialized view materialized_phenotype_jsonb_table depends on column "description"

so the following function drops the view, does the edit, then restores the view
*/

do \$\$
    DECLARE phenotype_jsonb_def text;
    DECLARE exec_text text;
begin
    phenotype_jsonb_def = pg_get_viewdef('materialized_phenotype_jsonb_table');
    DROP MATERIALIZED VIEW public.materialized_phenotype_jsonb_table;

    ALTER TABLE project ALTER COLUMN description TYPE text;

    exec_text = FORMAT('CREATE MATERIALIZED VIEW public.materialized_phenotype_jsonb_table AS %s',
      phenotype_jsonb_def);
    EXECUTE exec_text;
    CREATE UNIQUE INDEX materialized_phenotype_jsonb_table_obsunit_stock_idx ON public.materialized_phenotype_jsonb_table(observationunit_stock_id) WITH (fillfactor=100);
    CREATE INDEX materialized_phenotype_jsonb_table_obsunit_uniquename_idx ON public.materialized_phenotype_jsonb_table(observationunit_uniquename) WITH (fillfactor=100);
    CREATE INDEX materialized_phenotype_jsonb_table_germplasm_stock_idx ON public.materialized_phenotype_jsonb_table(germplasm_stock_id) WITH (fillfactor=100);
    CREATE INDEX materialized_phenotype_jsonb_table_germplasm_uniquename_idx ON public.materialized_phenotype_jsonb_table(germplasm_uniquename) WITH (fillfactor=100);
    CREATE INDEX materialized_phenotype_jsonb_table_trial_idx ON public.materialized_phenotype_jsonb_table(trial_id) WITH (fillfactor=100);
    CREATE INDEX materialized_phenotype_jsonb_table_trial_name_idx ON public.materialized_phenotype_jsonb_table(trial_name) WITH (fillfactor=100);
    ALTER MATERIALIZED VIEW public.materialized_phenotype_jsonb_table OWNER TO web_usr;
end \$\$;


EOSQL

print "You're done!\n";
}


####
1; #
####
