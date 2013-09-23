#!/usr/bin/env perl


=head1 NAME

 ChangeMetadataPerms.pm

=head1 SYNOPSIS

mx-run ThisPackageName [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

Change permissions to allow web_usr to write, update, and delete on metadata.md_files and phenome.nd_experiment_files and metadata.md_metadata
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

 Naama Menda<nm249@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package ChangeMetadataPerms;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
Change permissions to allow web_usr to write, update, and delete on metadata.md_files and phenome.nd_experiment_files and metadata.md_metadata

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
grant select, update, insert, delete on metadata.md_files to web_usr;
grant usage on metadata.md_files_file_id_seq to web_usr;
grant select, update, insert, delete on metadata.md_metadata to web_usr;
grant usage on metadata.md_metadata_metadata_id_seq to web_usr;
grant select, update, insert, delete on phenome.nd_experiment_md_files to web_usr;
grant usage on phenome.nd_experiment_md_files_nd_experiment_md_files_id_seq to web_usr;


EOSQL

print "You're done!\n";
}


####
1; #
####
