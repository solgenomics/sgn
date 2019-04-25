#!/usr/bin/env perl


=head1 NAME

 AddMdJsonAndLinkingTable.pm

=head1 SYNOPSIS

mx-run ThisPackageName [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddMdJsonAndLinkingTable;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
Adds md_json table for storing jsonb to Metadata schema and a linking table between md_json and nd_experiment to Phenome schema

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
--do your SQL here
--

CREATE TABLE md_json (
    json_id integer NOT NULL,
    json_type character varying(250),
    json jsonb
);
ALTER TABLE md_json OWNER TO postgres;
COMMENT ON TABLE md_json IS 'md_json is a table for storing variable json datasets and linking them to related data in other tables. For example storing nirs spectra (wavelength:value pairs) and linking to the relevant nd_experiment which in turn links to the plot and derived phenotype values.';
DROP SEQUENCE IF EXISTS md_json_json_id_seq CASCADE;
CREATE SEQUENCE md_json_json_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER TABLE md_json_json_id_seq OWNER TO postgres;
ALTER SEQUENCE md_json_json_id_seq OWNED BY md_json.json_id;

CREATE TABLE nd_experiment_md_json (
    nd_experiment_md_json_id integer NOT NULL,
    nd_experiment_id bigint,
    json_id bigint
);
ALTER TABLE nd_experiment_md_json OWNER TO postgres;
CREATE SEQUENCE nd_experiment_md_json_nd_experiment_md_json_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER TABLE nd_experiment_md_json_nd_experiment_md_json_id_seq OWNER TO postgres;
ALTER SEQUENCE nd_experiment_md_json_nd_experiment_md_json_id_seq OWNED BY nd_experiment_md_json.nd_experiment_md_json_id;

EOSQL

print "You're done!\n";
}


####
1; #
####
