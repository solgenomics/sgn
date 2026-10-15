#!/usr/bin/env perl


=head1 NAME

  AddFileTagsAndTimestampColumns

=head1 SYNOPSIS

mx-run AddFileTagsAndTimestampColumns [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch adds the create_timestamp and tags columns to metadata.md_files. These
columns allow old files to be suppressed from searches while retaining their
data as well as storing other modifiers on a file, like whether it has 
been successfully used to parse data. 
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

Ryan Preble <rsp98@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddFileTagsAndTimestampColumns;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
Adds the tags and create_timestamp columns to metadata.md_files

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


    $self->dbh()->do( <<'EOSQL');
--do your SQL here
--
ALTER TABLE metadata.md_files ADD COLUMN create_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW();
ALTER TABLE metadata.md_files ADD COLUMN tags TEXT;

WITH timestamped_files AS (
    SELECT file_id,
           substring(basename from '^([0-9]{4}-(?:0[1-9]|1[0-2])-(?:0[1-9]|[12][0-9]|3[01])_(?:[01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9])_') AS file_timestamp
      FROM metadata.md_files
)
UPDATE metadata.md_files AS f
   SET create_timestamp = replace(t.file_timestamp, '_', ' ')::timestamptz
  FROM timestamped_files AS t
 WHERE t.file_id = f.file_id
   AND t.file_timestamp IS NOT NULL;

EOSQL

print "You're done!\n";
}


####
1; #
####
