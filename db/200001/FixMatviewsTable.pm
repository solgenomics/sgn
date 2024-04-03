#!/usr/bin/env perl


=head1 NAME

FixMatViewstable.pm

=head1 SYNOPSIS

mx-run FixMatviewsTable [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch updates the matviews table with a mv_name unique constraint and insert all the matviews that need to be refreshed

=head1 AUTHOR

Naama Menda

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package FixMatviewsTable;

use Moose;
use Try::Tiny;
use Bio::Chado::Schema;

extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch updates the matviews table making each mv_name unique


sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";
    my $schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );

    my $coderef = sub {
	$self->dbh->do(<<EOSQL);

 --do your SQL here
DELETE FROM public.matviews WHERE mv_dependents IS NULL;

ALTER TABLE public.matviews DROP CONSTRAINT IF EXISTS mv_name_c1;
ALTER TABLE public.matviews ADD CONSTRAINT mv_name_c1 UNIQUE (mv_name);

ALTER TABLE public.matviews ADD COLUMN IF NOT EXISTS refresh_start timestamp with time zone;

INSERT INTO public.matviews (mv_name) VALUES
('materialized_stockprop'),
('materialized_phenotype_jsonb_table'),
('accessions'),
('breeding_programs'),
('genotyping_protocols'),
('locations'),
('plants'),
('plots'),
('seedlots'),
('trait_components'),
('traits'),
('trial_designs'),
('trial_types'),
('trials'),
('genotyping_projects'),
('years'),
('accessionsXbreeding_programs'),
('accessionsXlocations'),
('accessionsXgenotyping_protocols'),
('accessionsXplants'),
('accessionsXplots'),
('accessionsXseedlots'),
('accessionsXtrait_components'),
('accessionsXtraits'),
('accessionsXtrial_designs'),
('accessionsXtrial_types'),
('accessionsXtrials'),
('accessionsxgenotyping_projects'),
('accessionsXyears'),
('breeding_programsXlocations'),
('breeding_programsXgenotyping_protocols'),
('breeding_programsXplants'),
('breeding_programsXplots'),
('breeding_programsXseedlots'),
('breeding_programsXtrait_components'),
('breeding_programsXtraits'),
('breeding_programsXtrial_designs'),
('breeding_programsXtrial_types'),
('breeding_programsXtrials'),
('breeding_programsxgenotyping_projects'),
('breeding_programsXyears'),
('genotyping_protocolsXlocations'),
('genotyping_protocolsXplants'),
('genotyping_protocolsXplots'),
('genotyping_protocolsXseedlots'),
('genotyping_protocolsXtrait_components'),
('genotyping_protocolsXtraits'),
('genotyping_protocolsXtrial_designs'),
('genotyping_protocolsXtrial_types'),
('genotyping_protocolsXtrials'),
('genotyping_protocolsXyears'),
('genotyping_protocolsxgenotyping_projects'),
('genotyping_projectsxaccessions'),
('genotyping_projectsxbreeding_programs'),
('genotyping_projectsxgenotyping_protocols'),
('genotyping_projectsxlocations'),
('genotyping_projectsxtraits'),
('genotyping_projectsxtrials'),
('genotyping_projectsxyears'),
('locationsXplants'),
('locationsXplots'),
('locationsXseedlots'),
('locationsXtrait_components'),
('locationsXtraits'),
('locationsXtrial_designs'),
('locationsXtrial_types'),
('locationsXtrials'),
('locationsxgenotyping_projects'),
('locationsXyears'),
('plantsXplots'),
('plantsXseedlots'),
('plantsXtrait_components'),
('plantsXtraits'),
('plantsXtrial_designs'),
('plantsXtrial_types'),
('plantsXtrials'),
('plantsXyears'),
('plotsXseedlots'),
('plotsXtrait_components'),
('plotsXtraits'),
('plotsXtrial_designs'),
('plotsXtrial_types'),
('plotsXtrials'),
('plotsXyears'),
('seedlotsXtrait_components'),
('seedlotsXtraits'),
('seedlotsXtrial_designs'),
('seedlotsXtrial_types'),
('seedlotsXtrials'),
('seedlotsXyears'),
('trait_componentsXtraits'),
('trait_componentsXtrial_designs'),
('trait_componentsXtrial_types'),
('trait_componentsXtrials'),
('trait_componentsXyears'),
('traitsXtrial_designs'),
('traitsXtrial_types'),
('traitsXtrials'),
('traitsXyears'),
('trialsxgenotyping_projects'),
('trial_designsXtrial_types'),
('trial_designsXtrials'),
('trial_designsXyears'),
('trial_typesXtrials'),
('trial_typesXyears'),
('trialsXyears'),
('all_gs_traits')
;
EOSQL

    return 1;
    };

try {
    $schema->txn_do($coderef);
} catch {
    die "Load failed! " . $_ .  "\n" ;
};
print "You're done!\n";
}


####
1; #
####
