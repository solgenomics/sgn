#!/usr/bin/env perl


=head1 NAME

 AddFilesStockLinkingTable.pm

=head1 SYNOPSIS

mx-run ThisPackageName [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

 Mirella Flores <mrf252@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2023 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddFilesStockLinkingTable;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
Adds the linking table between files and stock to Phenome

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

CREATE TABLE phenome.stock_file (
    stock_file_id serial primary key, 
    stock_id int4 NOT NULL REFERENCES stock ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED, 
    file_id int4 NOT NULL REFERENCES metadata.md_files ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED 
);

GRANT UPDATE, INSERT, SELECT ON phenome.stock_file TO web_usr;
GRANT USAGE ON phenome.stock_file_stock_file_id_seq to web_usr;

EOSQL

print "You're done!\n";
}


####
1; #
####
