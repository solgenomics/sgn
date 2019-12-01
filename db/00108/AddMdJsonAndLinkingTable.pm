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

CREATE TABLE metadata.md_json (
    json_id SERIAL PRIMARY KEY,
    json_type character varying(250),
    json jsonb
);
ALTER TABLE metadata.md_json OWNER TO postgres;
COMMENT ON TABLE md_json IS 'md_json is a table for storing variable json datasets and linking them to related data in other tables. For example storing nirs spectra (wavelength:value pairs) and linking to the relevant nd_experiment which in turn links to the plot and derived phenotype values.';
GRANT SELECT,UPDATE,INSERT,DELETE ON metadata.md_json TO web_usr;
GRANT USAGE ON md_json_json_id_seq TO web_usr;

CREATE TABLE phenome.nd_experiment_md_json (
    nd_experiment_md_json_id SERIAL PRIMARY KEY,
    nd_experiment_id integer REFERENCES public.nd_experiment (nd_experiment_id),
    json_id integer REFERENCES metadata.md_json (json_id)
);
ALTER TABLE phenome.nd_experiment_md_json OWNER TO postgres;
GRANT SELECT,UPDATE,INSERT,DELETE ON phenome.nd_experiment_md_json TO web_usr;
GRANT USAGE ON phenome.nd_experiment_md_json_nd_experiment_md_json_id_seq TO web_usr;


EOSQL

print "You're done!\n";
}


####
1; #
####
