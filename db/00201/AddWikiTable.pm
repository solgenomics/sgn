#!/usr/bin/env perl


=head1 NAME

 AddWikiTable.pm

=head1 SYNOPSIS

mx-run AddWikiTable [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This is a test dummy patch.
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

 Naama Menda<nm249@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddWikiTable;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
Description of this patch goes here

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
CREATE TABLE sgn_people.sp_wiki (sp_wiki_id serial primary key, page_name varchar(255) unique,  sp_person_id bigint references sgn_people.sp_person not null, is_public boolean default false, create_date timestamp without time zone default now());

CREATE TABLE sgn_people.sp_wiki_content (sp_wiki_content_id serial primary key, sp_wiki_id bigint references sgn_people.sp_wiki on delete cascade, page_content text, page_version bigint,  create_date timestamp without time zone default now());


EOSQL

print "You're done!\n";
}


####
1; #
####
