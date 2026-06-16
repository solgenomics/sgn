#!/usr/bin/env perl

=head1 NAME

CreateStockPropsView.pm

=head1 SYNOPSIS

mx-run CreateStockPropsView [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch:
 - Creates a new view stockprops, that aggregates stockprops for a stock into
   one column.

=head1 AUTHOR

Katherine Eaton

=head1 COPYRIGHT & LICENSE

Copyright 2026 University of Alberta

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

package CreateStockPropsView;

use Moose;
use Bio::Chado::Schema;
extends 'CXGN::Metadata::Dbpatch';

has '+description' => ( default => <<'' );
This patch creates a new view stockprops, that aggregates stockprops for a stock into one column.

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    $self->dbh->do(<<EOSQL);
create view public.stockprops as (
    select stock_id, jsonb_object_agg(cvterm.name, stockprop.value) as stockprops
    from stockprop
    join cvterm on (type_id = cvterm_id) and cv_id = (select cv_id from cv where cv.name = 'stock_property')
    group by stock_id
);
alter view public.stockprops owner to web_usr;

EOSQL

    print "You're done!\n";
}

####
1; #
####
