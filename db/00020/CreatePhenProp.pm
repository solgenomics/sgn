#!/usr/bin/env perl


=head1 NAME

CreatePhenProp.pm

=head1 SYNOPSIS

mx-run ThisPackageName [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

Create new phenotypeprop table nad grant web_usr permission
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

 Naama Menda<nm249@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2011 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package CreatePhenProp;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
Create new phenotypeprop table nad grant web_usr permission


sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    $self->dbh->do(<<EOSQL);

    set search_path to public;
create table phenotypeprop (
       phenotypeprop_id serial not null,
       primary key (phenotypeprop_id),
       phenotype_id int not null,
       foreign key (phenotype_id) references phenotype (phenotype_id) on delete cascade INITIALLY DEFERRED,
       type_id int not null,
       foreign key (type_id) references cvterm (cvterm_id) on delete cascade INITIALLY DEFERRED,
       value text null,
       rank int not null default 0,
       constraint phenotypeprop_c1 unique (phenotype_id,type_id,rank)
);
create index phenotypeprop_idx1 on phenotypeprop (phenotype_id);
create index phenotypeprop_idx2 on phenotypeprop (type_id);

COMMENT ON TABLE phenotypeprop IS 'A phenotype can have any number of
slot-value property tags attached to it. This is an alternative to
hardcoding a list of columns in the relational schema, and is
completely extensible. There is a unique constraint, phenotypeprop_c1, for
the combination of phenotype_id, rank, and type_id. Multivalued property-value pairs must be differentiated by rank.';


GRANT all ON phenotypeprop TO web_usr;
GRANT usage ON phenotypeprop_phenotypeprop_id_seq TO web_usr;

EOSQL

print "You're done!\n";
}


####
1; #
####
