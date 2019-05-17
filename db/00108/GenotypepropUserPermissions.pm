#!/usr/bin/env perl


=head1 NAME

 GenotypepropUserPermissions

=head1 SYNOPSIS

mx-run GenotypepropUserPermissions [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION
This patch gives web_usr permissions for inserting and using genotypeprop table. Your database may already have been modified manually, but this patch explicitly grants the needed permissions.
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR


=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package GenotypepropUserPermissions;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch gives web_usr permissions for inserting and using genotypeprop table. Your database may already have been modified manually, but this patch explicitly grants the needed permissions.

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
    my $schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );


    my $sql = <<SQL;
grant insert on genotype to web_usr;
grant usage on genotype_genotype_id_seq to web_usr;
grant insert on genotypeprop to web_usr;
grant usage on genotypeprop_genotypeprop_id_seq to web_usr;
SQL

    $schema->storage->dbh->do($sql);


print "You're done!\n";
}


####
1; #
####
