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


package AlterListTimestampType;

use Moose;
use Try::Tiny;
use Bio::Chado::Schema;

extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch modify create/modified date to be timestamp types in the database


sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";
    my $schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );

    my $coderef = sub {
        $self->dbh->do(<<EOSQL);

 --do your SQL here
    alter table sgn_people.list add column modified_date timestamp NULL DEFAULT now();

    update sgn_people.list set create_date = to_timestamp("timestamp", 'YYYY-MM-DD_hh24:mi:ss') where timestamp ~ '\\d\\d\\d\\d-\\d\\d-\\d\\d_\\d\\d\\:\\d\\d\\:\\d\\d';
    update sgn_people.list set modified_date = to_timestamp(modify_timestamp, 'YYYY-MM-DD_hh24:mi:ss');

    alter table sgn_people.list drop column "timestamp";
    alter table sgn_people.list drop column modify_timestamp;
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
