#!/usr/bin/env perl


=head1 NAME

 UpdateProgenyOffspringOfRelationship

=head1 SYNOPSIS

mx-run ThisPackageName [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

update relationship or cross stock to its progeny from member_of, which is used for populations, to offspring_of

This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

 Naama Menda<nm249@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2018 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package UpdateProgenyOffspringOfRelationship;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
Description of this patch goes here

has '+prereq' => (
    default => sub {
        ['AddSystemCvterms'],
    },
  );

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    $self->dbh->do(<<EOSQL);

UPDATE stock_relationship 
SET type_id = (SELECT cvterm_id FROM cvterm where cvterm.name = 'offspring_of' AND cv_id = (SELECT cv_id FROM cv WHERE name = 'stock_relationship')) 
WHERE object_id IN (SELECT stock_id FROM stock WHERE type_id = (SELECT cvterm_id FROM cvterm WHERE name = 'cross' AND cv_id = (SELECT cv_id FROM cv WHERE name = 'stock_type')))
AND type_id = (SELECT cvterm_id FROM cvterm WHERE name = 'member_of' AND cv_id = (SELECT cv_id FROM cv WHERE name = 'stock_relationship')); 

EOSQL

print "You're done!\n";
}


####
1; #
####
