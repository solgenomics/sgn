#!/usr/bin/env perl


=head1 NAME

    DefaultMdImageCreateDateTimestamp.pm

=head1 SYNOPSIS

mx-run DefaultMdImageCreateDateTimestamp [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch sets a default NOW() value for the create_date and modified_date columns in metadata.md_images, metadata.md_tag_image, and metadata.md_tag
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR


=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package DefaultMdImageCreateDateTimestamp;

use Moose;

extends 'CXGN::Metadata::Dbpatch';

has '+description' => ( default => <<'');
This patch sets a default NOW() value for the create_date and modified_date columns in metadata.md_images, metadata.md_tag_image, and metadata.md_tag


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

alter table metadata.md_image alter column create_date set default now();
alter table metadata.md_image alter column modified_date set default now();
alter table metadata.md_tag_image alter column create_date set default now();
alter table metadata.md_tag_image alter column modified_date set default now();
alter table metadata.md_tag alter column create_date set default now();
alter table metadata.md_tag alter column modified_date set default now();

EOSQL

print "You're done!\n";
}


####
1; #
####
