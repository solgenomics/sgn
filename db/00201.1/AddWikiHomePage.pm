#!/usr/bin/env perl

=head1 NAME

AddWikiHomePage.pm

=head1 SYNOPSIS

mx-run AddWikiHomePage [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch:
 - Adds a home page for the wiki system.

=head1 AUTHOR

Katherine Eaton

=head1 COPYRIGHT & LICENSE

Copyright 2025 University of Alberta

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

package AddWikiHomePage;

use Moose;
use Bio::Chado::Schema;
extends 'CXGN::Metadata::Dbpatch';

has '+description' => ( default => <<'' );
This patch adds a home page for the wiki system.

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";
    my $schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );

    $self->dbh->do(<<EOSQL);
--do your SQL here
--

-- Create homepage
insert into sgn_people.sp_wiki (
select 1 as sp_wiki_content_id, 'WikiHome' as page_name, sp_person_id
from sgn_people.sp_person_roles where sp_role_id = (select sp_role_id from sgn_people.sp_roles where name = 'curator') limit 1
);

-- Create homepage content
insert into sgn_people.sp_wiki_content (
    select 1 as sp_wiki_content_id, 1 as sp_wiki_id, '<h1>Wiki Home Page</h1>' as page_content, 1 as page_version
);

EOSQL

    print "You're done!\n";
}

####
1; #
####
