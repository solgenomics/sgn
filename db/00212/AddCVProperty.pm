#!/usr/bin/env perl

=head1 NAME

AddCVProperty

=head1 SYNOPSIS

mx-run AddCVProperty [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch adds the 'cv_property' cv, with the cvterms 'cv_visible' and
'cv_editable', which control whether a CV is visible and editable through
the user interface. Relevant to ontology browser and trait designer.
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

Ryan Preble <rsp98@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddCVProperty;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch adds the 'cv_property' cv with the 'cv_visible' and 'cv_editable' cvterms

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
    my $schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );

    my $cv_name = 'cv_property';
    my @terms = (
        [ 'cv_visible',  'Whether a CV is visible through the user interface. 1 for visible, 0 for not.' ],
        [ 'cv_editable', 'Whether a CV is editable through the user interface. 1 for editable, 0 for not.' ],
    );

    my $coderef = sub {
        print STDERR "INSERTING CV $cv_name...\n";
        my $cv = $schema->resultset('Cv::Cv')->find_or_create({ name => $cv_name });

        print STDERR "INSERTING CV TERMS...\n";
        my %cvterm_id;
        foreach my $term (@terms) {
            my ($name, $definition) = @$term;
            my $cvterm = $schema->resultset('Cv::Cvterm')->create_with({
                name => $name,
                cv   => $cv,
            });
            # create_with() ignores 'definition', so set it explicitly
            $cvterm->update({ definition => $definition });
            $cvterm_id{$name} = $cvterm->cvterm_id;
        }

        # Use the schema's own handle so these statements run inside txn_do's transaction.
        my $dbh = $schema->storage->dbh;
        my $visible_id  = $cvterm_id{cv_visible};
        my $editable_id = $cvterm_id{cv_editable};

        # Each insert skips cvs that already have the property (cvprop_c1 is unique on cv_id, type_id, rank).

        # Step 1: Mark every cv that already has a row in cvprop as visible.
        print STDERR "MARKING CVS IN CVPROP AS VISIBLE...\n";
        $dbh->do(<<'EOSQL', undef, $visible_id, $visible_id);
INSERT INTO cvprop (cv_id, type_id, value)
SELECT DISTINCT cp.cv_id, ?::int, '1'
FROM cvprop cp
WHERE NOT EXISTS (
    SELECT 1 FROM cvprop existing
    WHERE existing.cv_id = cp.cv_id AND existing.type_id = ?
)
EOSQL

        # Step 2: Mark trait and experiment treatment ontologies (plain and composed) as editable.
        print STDERR "MARKING TRAIT AND TREATMENT ONTOLOGIES AS EDITABLE...\n";
        $dbh->do(<<'EOSQL', undef, $editable_id, $editable_id);
INSERT INTO cvprop (cv_id, type_id, value)
SELECT DISTINCT cp.cv_id, ?::int, '1'
FROM cvprop cp
JOIN cvterm type ON type.cvterm_id = cp.type_id
JOIN cv type_cv ON type_cv.cv_id = type.cv_id
WHERE type_cv.name = 'composable_cvtypes'
  AND type.name IN ('trait_ontology', 'composed_trait_ontology',
                    'experiment_treatment_ontology', 'composed_experiment_treatment_ontology')
  AND NOT EXISTS (
    SELECT 1 FROM cvprop existing
    WHERE existing.cv_id = cp.cv_id AND existing.type_id = ?
  )
EOSQL

        # Step 3: Mark the cvs whose terms come from the GO, PO, SO and PATO dbs as visible.
        print STDERR "MARKING GO, PO, SO AND PATO CVS AS VISIBLE...\n";
        $dbh->do(<<'EOSQL', undef, $visible_id, $visible_id);
INSERT INTO cvprop (cv_id, type_id, value)
SELECT DISTINCT cvterm.cv_id, ?::int, '1'
FROM db
JOIN dbxref ON dbxref.db_id = db.db_id
JOIN cvterm ON cvterm.dbxref_id = dbxref.dbxref_id
WHERE db.name IN ('GO', 'PO', 'SO', 'PATO')
  AND NOT EXISTS (
    SELECT 1 FROM cvprop existing
    WHERE existing.cv_id = cvterm.cv_id AND existing.type_id = ?
  )
EOSQL
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
