#!/usr/bin/env perl


=head1 NAME

AddScriptFactoryRecipeTable.pm

=head1 SYNOPSIS

mx-run AddScriptFactoryRecipeTable [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch adds the table sgn_people.sp_script_factory_recipe, which stores the
analysis scripts ("recipes") built with the Script Factory tool
(/tools/script_factory), so they can be reused on other datasets or years.
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

Chris Simoes <ccs263@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2026 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddScriptFactoryRecipeTable;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
Adds the sgn_people.sp_script_factory_recipe table used by the Script Factory to store reusable analysis scripts

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

    my $dbuser = 'web_usr';

    $self->dbh->do(<<EOSQL);
CREATE TABLE IF NOT EXISTS sgn_people.sp_script_factory_recipe (
    sp_script_factory_recipe_id SERIAL PRIMARY KEY,
    sp_person_id BIGINT NOT NULL REFERENCES sgn_people.sp_person(sp_person_id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    recipe JSONB NOT NULL,
    is_public BOOLEAN NOT NULL DEFAULT FALSE,
    create_date TIMESTAMP NOT NULL DEFAULT now(),
    modified_date TIMESTAMP NOT NULL DEFAULT now(),
    UNIQUE (sp_person_id, name)
);

CREATE INDEX IF NOT EXISTS sp_script_factory_recipe_public_idx ON sgn_people.sp_script_factory_recipe (is_public);

GRANT SELECT, UPDATE, DELETE, INSERT ON sgn_people.sp_script_factory_recipe TO $dbuser;

GRANT USAGE ON SEQUENCE sgn_people.sp_script_factory_recipe_sp_script_factory_recipe_id_seq TO $dbuser;

EOSQL

    print "You're done!\n";
}


####
1; #
####
