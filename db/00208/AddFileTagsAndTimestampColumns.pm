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
use Config::Any;
use Data::Dumper;
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

    my $test_conf  = "../../sgn_test.conf";
    my $conf_file  = "../../sgn.conf";
    my $local_conf = "../../sgn_local.conf";

    my $cfg = Config::Any->load_files({files=> [$test_conf, $conf_file, $local_conf], use_ext=>1 });

    my $sgn_test_conf   = $cfg->[0]->{$test_conf};
    my $sgn_conf        = $cfg->[1]->{$conf_file};
    my $sgn_local_conf  = $cfg->[2]->{$local_conf};

    my $archive_path = $sgn_local_conf->{archive_path} ? $sgn_local_conf->{archive_path} : $sgn_conf->{archive_path};

    # this is an assumption. sgn_test.conf is git-tracked, and dbname=db in that file. Since I assume no actual 
    # site or dev environmment uses dbname=db, I will guess that if our dbname is just db, we are inside of a test.
    if ($self->dbname() eq "db") {
      $archive_path = $sgn_test_conf->{archive_path};
    }


    $self->dbh()->do( <<'EOSQL');
--do your SQL here
--
ALTER TABLE metadata.md_files ADD COLUMN create_timestamp TIMESTAMP NOT NULL DEFAULT NOW();
ALTER TABLE metadata.md_files ADD COLUMN tags TEXT;

WITH timestamped_files AS (
    SELECT file_id,
           substring(basename from '^([0-9]{4}-(?:0[1-9]|1[0-2])-(?:0[1-9]|[12][0-9]|3[01])_(?:[01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9])_') AS file_timestamp
      FROM metadata.md_files
)
UPDATE metadata.md_files AS f
   SET create_timestamp = replace(t.file_timestamp, '_', ' ')::timestamp
  FROM timestamped_files AS t
 WHERE t.file_id = f.file_id
   AND t.file_timestamp IS NOT NULL;

EOSQL

    # md_files.dirname used to hold the full path of the folder, archive_path included. It should only hold
    # what comes after archive_path, which is added back from the config wherever a file is read. Only a leading
    # archive_path (ending at a folder boundary) is removed, and the rest of the dirname is left as it is.
    if ($archive_path) {
        (my $archive_path_prefix = $archive_path) =~ s/\/+$//;

        if (length $archive_path_prefix) {
            print STDOUT "\nRemoving $archive_path_prefix from md_files.dirname.\n";

            $self->dbh()->do( <<'EOSQL', undef, ($archive_path_prefix) x 4);
UPDATE metadata.md_files
   SET dirname = substr(dirname, length(?::text) + 1)
 WHERE dirname = ?::text
    OR left(dirname, length(?::text) + 1) = ?::text || '/';

EOSQL
        }
    }
    else {
        print STDERR "\nNo archive_path found in the configuration, so md_files.dirname was not changed.\n";
    }

print "You're done!\n";
}


####
1; #
####
