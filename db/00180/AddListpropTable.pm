#!/usr/bin/env perl


=head1 NAME

  AddListpropTable

=head1 SYNOPSIS

mx-run AddListpropTable [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch creates a listprop table to allow lists to store  additional info for brapi

=head1 AUTHOR

 Dave Phillips<drp227@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddListpropTable;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;

extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch creates a listprop table to allow lists to store additional info for brapi


sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";
    my $schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );

    my $coderef = sub {
        $self->dbh->do(<<EOSQL);

 --do your SQL here

CREATE TABLE IF NOT EXISTS sgn_people.listprop (
   listprop_id serial primary key,
   list_id int references sgn_people.list(list_id),
   type_id int references public.cvterm(cvterm_id),
   value text,
   rank int not null DEFAULT 0
);

GRANT select,insert,update,delete ON sgn_people.listprop TO web_usr;
GRANT USAGE ON sgn_people.listprop_listprop_id_seq TO web_usr;

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
