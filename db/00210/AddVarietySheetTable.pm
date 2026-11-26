#!/usr/bin/env perl


=head1 NAME

AddVarietySheetTable.pm

=head1 SYNOPSIS

mx-run AddVarietySheetTable [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch adds the table phenome.variety_sheet, which stores commercial
variety release profiles (see CXGN::VarietySheet). Each row belongs to one
accession and holds the profile content as JSON, a commercial name, the owner and
a status (draft or published).

This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

Breedbase

=head1 COPYRIGHT & LICENSE

Copyright 2026 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

package AddVarietySheetTable;

use Moose;
use Try::Tiny;

extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
Adds the phenome.variety_sheet table for commercial variety release profiles

has '+prereq' => (
    default => sub {
        [],
    },
  );

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nExecuting the SQL commands.\n";

    my $dbuser = 'web_usr';

    $self->dbh->do(<<EOSQL);
CREATE TABLE IF NOT EXISTS phenome.variety_sheet (
    variety_sheet_id SERIAL PRIMARY KEY,
    stock_id INTEGER NOT NULL REFERENCES public.stock(stock_id) ON DELETE CASCADE,
    sp_person_id INTEGER REFERENCES sgn_people.sp_person(sp_person_id) ON DELETE SET NULL,
    commercial_name TEXT,
    status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'published')),
    sheet JSONB NOT NULL DEFAULT '{}',
    create_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    modified_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS variety_sheet_stock_id_idx ON phenome.variety_sheet(stock_id);

GRANT SELECT,UPDATE,DELETE,INSERT ON phenome.variety_sheet TO $dbuser ;

GRANT USAGE ON SEQUENCE phenome.variety_sheet_variety_sheet_id_seq TO $dbuser ;

EOSQL

    print "You're done!\n";
}


####
1; #
####
