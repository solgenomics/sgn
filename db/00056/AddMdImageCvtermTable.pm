#!/usr/bin/env perl


=head1 NAME

 AddMdImageCvtermTable.pm

=head1 SYNOPSIS

mx-run ThisPackageName [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

 Naama Menda<nm249@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddMdImageCvtermTable;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
Adds a linking table between the metadata.md_image and cvterm table

has '+prereq' => (
    default => sub {
        [ ],
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

CREATE TABLE metadata.md_image_cvterm (
    md_image_cvterm_id serial primary key,
    image_id bigint REFERENCES metadata.md_image(image_id) NOT NULL,
    cvterm_id bigint REFERENCES cvterm(cvterm_id) NOT NULL,
    sp_person_id bigint REFERENCES sgn_people.sp_person(sp_person_id),
    obsolete boolean DEFAULT false
);


    GRANT select ON metadata.md_image_cvterm TO web_usr;
    GRANT USAGE ON metadata.md_image_cvterm_md_image_cvterm_id_seq to web_usr;
    
EOSQL

print "You're done!\n";
}


####
1; #
####
