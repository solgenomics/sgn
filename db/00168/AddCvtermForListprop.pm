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


package AddCvtermForListprop;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;

extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch creates cv term for  listprop table to allow


sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";
    my $schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );

    my $coderef = sub {
        $self->dbh->do(<<EOSQL);

 --do your SQL here
INSERT into db (name)
select 'null' where not exists(
    select name from db where name = 'null'
);

INSERT into public.dbxref (db_id, accession)
select db_id, 'list_additional_info'
from public.db
WHERE name = 'null'
and not exists(
  select accession from dbxref where accession = 'list_additional_info' and db_id = (select db_id from db where name = 'null')
);

INSERT INTO public.cv (name)
select 'list_properties' where not exists (
    select name from cv where name = 'list_properties'
);

INSERT INTO public.cvterm (cv_id, name, dbxref_id)
select (SELECT cv_id FROM public.cv WHERE cv.name = 'list_properties'), 'list_additional_info', (SELECT dbxref_id FROM public.dbxref WHERE accession = 'list_additional_info')
where not exists (
    select * from cvterm where name = 'list_additional_info' and cv_id = (SELECT cv_id FROM public.cv WHERE cv.name = 'list_properties') and dbxref_id = (SELECT dbxref_id FROM public.dbxref WHERE accession = 'list_additional_info')
);

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
