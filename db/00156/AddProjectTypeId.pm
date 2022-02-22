#!/usr/bin/env perl


=head1 NAME

 AddProjectTypeId.pm

=head1 SYNOPSIS

mx-run ThisPackageName [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

Add type_id foreign key to the Chado project table
Based on this commit https://github.com/GMOD/Chado/commit/364ac74f88182bcff07efe5c47d549886645239b
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

 Naama Menda<nm249@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddProjectTypeId;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
Add type_id foreign key to the project table as added to the Chado 1.4 release
has '+prereq' => (
    default => sub {
        [''],
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
ALTER TABLE project
ADD COLUMN type_id bigint REFERENCES cvterm (cvterm_id) ON DELETE SET NULL;
CREATE INDEX project_idx1 ON project USING btree (type_id);
COMMENT ON COLUMN project.type_id IS 'An optional cvterm_id that specifies what type of project this record is.  Prior to 1.4, project type was set with an projectprop.';

EOSQL

print "You're done!\n";
}


####
1; #
####
