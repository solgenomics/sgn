#!/usr/bin/env perl


=head1 NAME

 AddPrivateCompanyMdImage.pm

=head1 SYNOPSIS

mx-run AddPrivateCompanyMdImage [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

Creates the sgn_people.private_company links to md_image, md_json, md_files tables
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddPrivateCompanyMdImage;

use Moose;
use SGN::Model::Cvterm;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch creates the sgn_people.private_company links to md_image, md_json, md_files tables

has '+prereq' => (
    default => sub {
        [],
    },
  );

sub patch {
    my $self=shift;
    my $schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    $self->dbh->do(<<EOSQL);
--do your SQL here
--

ALTER TABLE metadata.md_image ADD COLUMN "is_private" BOOLEAN DEFAULT FALSE;
ALTER TABLE metadata.md_json ADD COLUMN "is_private" BOOLEAN DEFAULT FALSE;
ALTER TABLE metadata.md_files ADD COLUMN "is_private" BOOLEAN DEFAULT FALSE;

ALTER TABLE metadata.md_image ADD COLUMN "private_company_id" INT NOT NULL DEFAULT(1);
ALTER TABLE metadata.md_json ADD COLUMN "private_company_id" INT NOT NULL DEFAULT(1);
ALTER TABLE metadata.md_files ADD COLUMN "private_company_id" INT NOT NULL DEFAULT(1);

ALTER TABLE metadata.md_image ADD CONSTRAINT md_image_private_company_private_company_id_fkey FOREIGN KEY (private_company_id) REFERENCES sgn_people.private_company(private_company_id) ON DELETE CASCADE;
ALTER TABLE metadata.md_json ADD CONSTRAINT md_json_private_company_private_company_id_fkey FOREIGN KEY (private_company_id) REFERENCES sgn_people.private_company(private_company_id) ON DELETE CASCADE;
ALTER TABLE metadata.md_files ADD CONSTRAINT md_files_private_company_private_company_id_fkey FOREIGN KEY (private_company_id) REFERENCES sgn_people.private_company(private_company_id) ON DELETE CASCADE;

EOSQL


print "You're done!\n";
}


####
1; #
####
