#!/usr/bin/env perl


=head1 NAME

    CreateFeaturepropJSONTable.pm

=head1 SYNOPSIS

mx-run CreateFeaturepropJSONTable [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch creates the featureprop_json table used for storing sequence metadata as JSON objects
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR


=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package CreateFeaturepropJSONTable;

use Moose;

extends 'CXGN::Metadata::Dbpatch';

has '+description' => ( default => <<'');
This patch creates the featureprop_json table used for storing sequence metadata as JSON objects


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

-- table definition
CREATE TABLE IF NOT EXISTS public.featureprop_json (
    "featureprop_json_id" SERIAL PRIMARY KEY,
    "feature_id" int8 REFERENCES feature,
    "type_id" int8 REFERENCES cvterm,
    "nd_protocol_id" int8 REFERENCES nd_protocol,
    "start_pos" int8,
    "end_pos" int8,
    "json" jsonb
);

-- add indices
CREATE INDEX feaureprop_json_idx1 ON featureprop_json(feature_id);
CREATE INDEX feaureprop_json_idx2 ON featureprop_json(type_id);
CREATE INDEX feaureprop_json_idx3 ON featureprop_json(nd_protocol_id);
CREATE INDEX feaureprop_json_idx4 ON featureprop_json(start_pos);
CREATE INDEX feaureprop_json_idx5 ON featureprop_json(end_pos);

-- grant usage to web_usr
GRANT ALL on public.featureprop_json to web_usr;
GRANT USAGE ON public.featureprop_json_featureprop_json_id_seq to web_usr;

EOSQL

print "You're done!\n";
}


####
1; #
####
