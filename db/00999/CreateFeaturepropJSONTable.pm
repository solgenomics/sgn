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
--do your SQL here

-- feature table might be missing primary key?
-- ALTER TABLE public.feature ADD PRIMARY KEY (feature_id);

-- table definition
CREATE TABLE IF NOT EXISTS public.featureprop_json (
    "feature_json_id" SERIAL PRIMARY KEY,
    "feature_id" int8 REFERENCES feature,
    "type_id" int8 REFERENCES cvterm,
    "start_pos" int8,
    "end_pos" int8,
    "json" jsonb
);

EOSQL

print "You're done!\n";
}


####
1; #
####
