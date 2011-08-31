#!/usr/bin/env perl


=head1 NAME

 AddOrganismImage.pm

=head1 SYNOPSIS

mx-run ThisPackageName [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

Adds an image_organism table in the metadata schema.

This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

 Naama Menda<nm249@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

package AddOrganismImage;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This page adds an image_organism table to the metadata schema, so that images can be associated with organisms and displayed on the organism detail page.

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

CREATE TABLE metadata.md_image_organism (
    md_image_organism_id serial primary key,
    image_id bigint references metadata.md_image not null,
    organism_id bigint references public.organism not null,
    sp_person_id bigint references sgn_people.sp_person,
    obsolete boolean default false
);
    
    GRANT UPDATE, INSERT, SELECT ON metadata.md_image_organism TO web_usr;
    GRANT USAGE ON metadata.md_image_organism_md_image_organism_id_seq to web_usr;

EOSQL

print "You're done!\n";
}


####
1; #
####
