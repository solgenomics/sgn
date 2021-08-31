#!/usr/bin/env perl


=head1 NAME

CreateMaterializedMarkerviewUpdated2.pm

=head1 SYNOPSIS

mx-run CreateMaterializedMarkerviewUpdated2 [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch adds a public.create_materialized_markerview(boolean) function which can be used to build 
and refresh the unified marker materialized view.  The function uses all of the reference genomes / species 
from the currently stored genotype data in the nd_protocolprop table to build the query for the marker 
materialized view.  If new genotype data is added, this function should be used to rebuild the marker 
materialized view rather than simply refreshing it in case there are new references or species in the data.

Update: does not cast the marker position to int, in case it is not defined or not an int...

Update 2: it does cast the marker position to int, but handles cases when the position is not defined, so that 
way the query properly sorts positions numerically and is more efficient

=head1 AUTHOR

David Waring <djw64@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package CreateMaterializedMarkerviewUpdated2;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch adds the create_materialized_markerview function to build and populate the materialized_markerview mat view

has '+prereq' => (
	default => sub {
        [],
    },

);

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";
    
    $self->dbh->do(<<EOSQL);

-- Remove existing matview and function
DROP MATERIALIZED VIEW IF EXISTS public.materialized_markerview;
DROP FUNCTION IF EXISTS public.create_materialized_markerview(boolean);

-- Create the function to build the materialized markerview
CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;
CREATE OR REPLACE FUNCTION public.create_materialized_markerview(refresh boolean)
 RETURNS boolean
 LANGUAGE plpgsql
AS \$function\$
	DECLARE
		maprow RECORD;
		querystr TEXT;
		queries TEXT[];
		emptyquery TEXT;
		matviewquery TEXT;
	BEGIN
	
		-- Remove exsiting materialized view, if it exists
		DROP MATERIALIZED VIEW IF EXISTS public.materialized_markerview;

		-- Get the unique species / reference genome combinations from the nd_protocolprop table
		FOR maprow IN (
			SELECT value->>'species_name' AS species,
				concat(
					substring(split_part(value->>'species_name', ' ', 1), 1, 1),
					substring(split_part(value->>'species_name', ' ', 2), 1, 1)
				) AS species_abbreviation,
				value->>'reference_genome_name' AS reference_genome,
				replace(replace(value->>'reference_genome_name', '_', ''), ' ', '') AS reference_genome_cleaned
			FROM nd_protocolprop 
			WHERE type_id = (SELECT cvterm_id FROM public.cvterm WHERE name = 'vcf_map_details')
			GROUP BY species, reference_genome
		)
		
		-- Loop through each unique combination of species / reference genome and build the marker query
		LOOP
			querystr := 'SELECT nd_protocolprop.nd_protocol_id, ''' || maprow.species || ''' AS species_name, ''' || maprow.reference_genome || ''' AS reference_genome_name, s.value->>''name'' AS marker_name, s.value->>''chrom'' AS chrom, cast(coalesce(nullif(s.value->>''pos'',''''),NULL) as numeric) AS pos, s.value->>''ref'' AS ref, s.value->>''alt'' AS alt, CASE WHEN s.value->>''alt'' < s.value->>''ref'' THEN concat(''' || maprow.species_abbreviation || ''', ''' || maprow.reference_genome_cleaned || ''', ''_'', REGEXP_REPLACE(s.value->>''chrom'', ''^chr?'', ''''), ''_'', s.value->>''pos'', ''_'', s.value->>''alt'', ''_'', s.value->>''ref'') ELSE concat(''' || maprow.species_abbreviation || ''', ''' || maprow.reference_genome_cleaned || ''', ''_'', REGEXP_REPLACE(s.value->>''chrom'', ''^chr?'', ''''), ''_'', s.value->>''pos'', ''_'', s.value->>''ref'', ''_'', s.value->>''alt'') END AS variant_name FROM nd_protocolprop, LATERAL jsonb_each(nd_protocolprop.value) s(key, value) WHERE type_id = (SELECT cvterm_id FROM public.cvterm WHERE name = ''vcf_map_details_markers'') AND nd_protocol_id IN (SELECT nd_protocol_id FROM nd_protocolprop WHERE value->>''species_name'' = ''' || maprow.species || ''' and value->>''reference_genome_name'' = ''' || maprow.reference_genome || ''' AND type_id = (SELECT cvterm_id FROM public.cvterm WHERE name = ''vcf_map_details''))';
			queries := array_append(queries, querystr);

		END LOOP;

		-- Add an empty query in case there is no existing marker data
		emptyquery := 'SELECT column1::int AS nd_protocol_id, column2::text AS species_name, column3::text AS reference_genome_name, column4::text AS marker_name, column5::text AS chrom, column6::numeric AS pos, column7::text AS ref, column8::text AS alt, column9::text AS variant_name FROM (values (null,null,null,null,null,null,null,null,null)) AS x WHERE false';
		queries := array_append(queries, emptyquery);
		
		-- Combine queries with a UNION
		matviewquery := array_to_string(queries, ' UNION ');

		-- Build the materialized view
		EXECUTE 'CREATE MATERIALIZED VIEW public.materialized_markerview AS (' || matviewquery || ') WITH NO DATA';
		ALTER MATERIALIZED VIEW public.materialized_markerview OWNER TO web_usr;

		-- Add indexes
		CREATE INDEX materialized_markerview_idx1 ON public.materialized_markerview(nd_protocol_id);
		CREATE INDEX materialized_markerview_idx2 ON public.materialized_markerview(species_name);
		CREATE INDEX materialized_markerview_idx3 ON public.materialized_markerview(reference_genome_name);
		CREATE INDEX materialized_markerview_idx4 ON public.materialized_markerview(marker_name);
		CREATE INDEX materialized_markerview_idx5 ON public.materialized_markerview(UPPER(marker_name));
		CREATE INDEX materialized_markerview_idx6 ON public.materialized_markerview(chrom);
		CREATE INDEX materialized_markerview_idx7 ON public.materialized_markerview(pos);
		CREATE INDEX materialized_markerview_idx8 ON public.materialized_markerview(variant_name);
		CREATE INDEX materialized_markerview_idx9 ON public.materialized_markerview(UPPER(variant_name));
		CREATE INDEX materialized_markerview_idx10 ON public.materialized_markerview USING GIN(marker_name gin_trgm_ops);
		CREATE INDEX materialized_markerview_idx11 ON public.materialized_markerview USING GIN(variant_name gin_trgm_ops);

		-- Refresh materialzied view, if requested with function argument
		IF \$1 THEN
			EXECUTE 'REFRESH MATERIALIZED VIEW public.materialized_markerview';
		END IF;

		-- Return true if the materialized view is refreshed
		RETURN \$1;

	END
\$function\$;

-- Build a populated materialized view
SELECT public.create_materialized_markerview(true);

-- Change ownership of matview to web_usr (so it can be rebuilt when needed)
ALTER MATERIALIZED VIEW public.materialized_markerview OWNER TO web_usr;


EOSQL
    
    print "You're done!\n";
}


####
1; #
####
