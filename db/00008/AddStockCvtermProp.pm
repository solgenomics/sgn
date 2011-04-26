package AddStockCvtermProp;

use Moose;
extends 'CXGN::Metadata::Dbpatch';

use Bio::Chado::Schema;

sub init_patch {

    my $self=shift;
    my $name = __PACKAGE__;
    print "dbpatch name is ':" .  $name . "\n\n";
    my $description = 'Adding rank column to stock_cvterm table, and a new stocl_cvtermprop tables';
    my @previous_requested_patches = (); #ADD HERE
    $self->name($name);
    $self->description($description);
    $self->prereq(\@previous_requested_patches);
}

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    $self->dbh->do( <<EOF );
alter table public.stock_cvterm add rank integer not null default 0;
alter table public.stock_cvterm add is_not boolean not null default false;
alter table public.stock_cvterm drop constraint stock_cvterm_c1;
alter table public.stock_cvterm add constraint stock_cvterm_c1 unique ( stock_id, cvterm_id, pub_id, rank );

create table public.stock_cvtermprop (
    stock_cvtermprop_id serial not null,
    primary key (stock_cvtermprop_id),
    stock_cvterm_id int not null,
    foreign key (stock_cvterm_id) references public.stock_cvterm (stock_cvterm_id) on delete cascade,
    type_id int not null,
    foreign key (type_id) references public.cvterm (cvterm_id) on delete cascade INITIALLY DEFERRED,
    value text null,
    rank int not null default 0,
    constraint stock_cvtermprop_c1 unique (stock_cvterm_id,type_id,rank)
);
create index stock_cvtermprop_idx1 on public.stock_cvtermprop (stock_cvterm_id);
create index stock_cvtermprop_idx2 on public.stock_cvtermprop (type_id);

COMMENT ON TABLE public.stock_cvtermprop IS 'Extensible properties for
stock to cvterm associations. Examples: GO evidence codes;
qualifiers; metadata such as the date on which the entry was curated
and the source of the association. See the stockprop table for
meanings of type_id, value and rank.';

COMMENT ON COLUMN public.stock_cvtermprop.type_id IS 'The name of the
property/slot is a cvterm. The meaning of the property is defined in
that cvterm. cvterms may come from the OBO evidence code cv.';

COMMENT ON COLUMN public.stock_cvtermprop.value IS 'The value of the
property, represented as text. Numeric values are converted to their
text representation. This is less efficient than using native database
types, but is easier to query.';

COMMENT ON COLUMN public.stock_cvtermprop.rank IS 'Property-Value
ordering. Any stock_cvterm can have multiple values for any particular
property type - these are ordered in a list using rank, counting from
zero. For properties that are single-valued rather than multi-valued,
the default 0 value should be used.';

    GRANT ALL on public.stock_cvtermprop to web_usr;
    GRANT usage on public.stock_cvtermprop_stock_cvtermprop_id_seq to web_usr;
EOF

    print "You're done!\n";
}


####
1; #
####

