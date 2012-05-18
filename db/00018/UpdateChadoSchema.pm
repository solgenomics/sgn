#!/usr/bin/env perl


=head1 NAME

UpdateChadoSchema

=head1 SYNOPSIS

mx-run ThisPackageName [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

Patch for bringing our Chado schema up to date with BCS version 0.09010
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

 Naama Menda<nm249@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2011 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package UpdateChadoSchema;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
Patch for bringing our Chado schema up to date with BCS version 0.09010



sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    $self->dbh->do(<<EOSQL);
--do your SQL here
--

ALTER TABLE stock_relationship_cvterm RENAME COLUMN stock_relatiohship_id TO stock_relationship_id ;

ALTER TABLE stock_relationship_cvterm ADD FOREIGN KEY (stock_relationship_id) REFERENCES stock_relationship ON DELETE CASCADE INITIALLY DEFERRED;

ALTER TABLE phenotype ADD COLUMN name text DEFAULT NULL;

ALTER TABLE nd_experimentprop ALTER COLUMN value TYPE text ;

ALTER TABLE nd_geolocationprop ALTER COLUMN value TYPE text ;

ALTER TABLE nd_protocolprop ALTER COLUMN value TYPE text ;

ALTER TABLE nd_reagentprop ALTER COLUMN value TYPE text ;

ALTER TABLE nd_experiment_stockprop ALTER COLUMN value TYPE text ;


ALTER TABLE genotype ADD COLUMN type_id INT NOT NULL REFERENCES cvterm(cvterm_id) ON DELETE CASCADE;

create table public.genotypeprop (
genotypeprop_id serial not null,
primary key (genotypeprop_id),
genotype_id int not null,
foreign key (genotype_id) references genotype (genotype_id) on delete cascade INITIALLY DEFERRED,
type_id int not null,
foreign key (type_id) references cvterm (cvterm_id) on delete cascade INITIALLY DEFERRED,
value text null,
rank int not null default 0,
constraint genotypeprop_c1 unique (genotype_id,type_id,rank)
);
create index genotypeprop_idx1 on genotypeprop (genotype_id);
create index genotypeprop_idx2 on genotypeprop (type_id);

create table public.cvprop (
    cvprop_id serial not null,
    primary key (cvprop_id),
    cv_id int not null,
    foreign key (cv_id) references cv (cv_id) INITIALLY DEFERRED,
    type_id int not null,
    foreign key (type_id) references cvterm (cvterm_id) INITIALLY DEFERRED,
    value text,
    rank int not null default 0,
    constraint cvprop_c1 unique (cv_id,type_id,rank)
);

COMMENT ON TABLE cvprop IS 'Additional extensible properties can be attached to a cv using this table.  A notable example would be the cv version';

COMMENT ON COLUMN cvprop.type_id IS 'The name of the property or slot is a cvterm. The meaning of the property is defined in that cvterm.';
COMMENT ON COLUMN cvprop.value IS 'The value of the property, represented as text. Numeric values are converted to their text representation.';

COMMENT ON COLUMN cvprop.rank IS 'Property-Value ordering. Any
cv can have multiple values for any particular property type -
these are ordered in a list using rank, counting from zero. For
properties that are single-valued rather than multi-valued, the
default 0 value should be used.';

create table public.chadoprop (
    chadoprop_id serial not null,
    primary key (chadoprop_id),
    type_id int not null,
    foreign key (type_id) references cvterm (cvterm_id) INITIALLY DEFERRED,
    value text,
    rank int not null default 0,
    constraint chadoprop_c1 unique (type_id,rank)
);

COMMENT ON TABLE chadoprop IS 'This table is different from other prop tables in the database, as it is for storing information about the database itself, like schema version';

COMMENT ON COLUMN chadoprop.type_id IS 'The name of the property or slot is a cvterm. The meaning of the property is defined in that cvterm.';
COMMENT ON COLUMN chadoprop.value IS 'The value of the property, represented as text. Numeric values are converted to their text representation.';

COMMENT ON COLUMN chadoprop.rank IS 'Property-Value ordering. Any
cv can have multiple values for any particular property type -
these are ordered in a list using rank, counting from zero. For
properties that are single-valued rather than multi-valued, the
default 0 value should be used.';


EOSQL

print "You're done!\n";
}


####
1; #
####
