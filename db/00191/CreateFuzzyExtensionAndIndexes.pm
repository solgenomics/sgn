#!/usr/bin/env perl


=head1 NAME

 CreateFuzzyExtension

=head1 SYNOPSIS

mx-run CreateFuzzyExtensionAndIndexes [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch creates the extension pg_trgm for use of the similarity function for fuzzy search, as well as GIN index and btree index on LOWER(uniquename) on the stock table.
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

 Ben Maza

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package CreateFuzzyExtensionAndIndexes;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch creates the extension pg_trgm for use of the similarity function for fuzzy search, as well as GIN index and btree index on LOWER(uniquename) on the stock table.

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

CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX gin_trgm_idx ON stock USING gin (LOWER(uniquename) gin_trgm_ops);
CREATE INDEX stock_type_id_lower_uniquename_idx ON stock (type_id, LOWER(uniquename));

SET pg_trgm.similarity_threshold = 0.5;

EOSQL

print "You're done!\n";
}

####
1; #
####