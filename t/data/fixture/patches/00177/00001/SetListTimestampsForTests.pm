#!/usr/bin/env perl


=head1 NAME

AddListCreateDate.pm

=head1 SYNOPSIS

mx-run AddListCreateDate [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch add create date to list objects

=head1 AUTHOR

Chris Tucker

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package SetListTimestampsForTests;

use Moose;
use Try::Tiny;
use Bio::Chado::Schema;

extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch sets the created/modified dates of lists used for testing


sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";
    my $schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );

    my $coderef = sub {
        $self->dbh->do(<<EOSQL);

 --do your SQL here
    -- update lists used for tests to have a known create/modified date
    update sgn_people.list set create_date = to_timestamp('0001-01-01 00:00:00', 'YYYY-MM-DD hh24:mi:ss'),
    modified_date = to_timestamp('0001-01-01 00:00:00', 'YYYY-MM-DD hh24:mi:ss')
    where list_id in (11, 9, 3, 5, 4, 10, 6, 14, 13, 808, 7, 12, 810, 811, 809, 8);
EOSQL

        return 1;
    };

    try {
        $schema->txn_do($coderef);
    } catch {
        die "Load failed! " . $_ .  "\n" ;
    };
    print "You're done!\n";
}


####
1; #
####
