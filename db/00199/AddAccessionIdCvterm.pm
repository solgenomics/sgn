#!/usr/bin/env perl

=head1 NAME

AddAccessionIdCvterm

=head1 SYNOPSIS

mx-run AddAccessionIdCvterm [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION
This patch adds accession ids to cvterm - support list generation with accessions ids.
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

Chris Simoes <ccs263@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddAccessionIdCvterm;

use Moose;
use Try::Tiny;
use Bio::Chado::Schema;
extends 'CXGN::Metadata::Dbpatch';

has '+description' => ( default => <<'DESC' );
Adds the cvterm "accessions_ids" under cv "list_types", linked to dbxref "local:accessions_ids".
DESC

has '+prereq' => ( default => sub { [] } );

sub patch {
    my $self = shift;

    print STDOUT "\nExecuting patch: ".$self->name."\n".$self->description."\n\n";
    my $schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );

    my $accession   = 'accessions_ids';
    my $definition  = 'accessions_ids for lists';
    my $target_db   = 'local';
    my $target_cv   = 'list_types';

    try {
        $schema->txn_do(sub {

            # 1) get db_id (db.name = 'local')
            my $db = $schema->resultset('General::Db')->find({ name => $target_db })
                or die "DB '$target_db' not found.\n";
            my $db_id = $db->db_id;

            # 2) insert/find dbxref (db_id, accession)
            my $dbxref = $schema->resultset('General::Dbxref')->find_or_create({
                db_id     => $db_id,
                accession => $accession,
            });
            my $dbxref_id = $dbxref->dbxref_id;

            # 3) get cv_id (cv.name = 'list_types')
            my $cv = $schema->resultset('Cv::Cv')->find({ name => $target_cv })
                or die "CV '$target_cv' not found.\n";
            my $cv_id = $cv->cv_id;

            # 4) insert/find cvterm
            my $cvterm_rs = $schema->resultset('Cv::Cvterm');
            my $cvterm = $cvterm_rs->find({
                name  => $accession,
                cv_id => $cv_id,
            });

            if ($cvterm) {
                # Ensure dbxref_id/definition are set as desired
                my $needs_update = 0;
                if ((!defined $cvterm->dbxref_id) || ($cvterm->dbxref_id != $dbxref_id)) {
                    $cvterm->dbxref_id($dbxref_id);
                    $needs_update = 1;
                }
                if ((!defined $cvterm->definition) || ($cvterm->definition // '') ne $definition) {
                    $cvterm->definition($definition);
                    $needs_update = 1;
                }
                if (!defined $cvterm->is_obsolete) {
                    $cvterm->is_obsolete(0);
                    $needs_update = 1;
                }
                if (!defined $cvterm->is_relationshiptype) {
                    $cvterm->is_relationshiptype(0);
                    $needs_update = 1;
                }
                $cvterm->update if $needs_update;
                print STDERR "cvterm '$accession' already existed; updated if needed.\n";
            } else {
                $cvterm = $cvterm_rs->create({
                    cv_id               => $cv_id,
                    name                => $accession,
                    definition          => $definition,
                    dbxref_id           => $dbxref_id,
                    is_obsolete         => 0,
                    is_relationshiptype => 0,
                });
                print STDERR "Inserted cvterm '$accession' in cv '$target_cv'.\n";
            }

        });
        print STDOUT "You're done!\n";
    }
    catch {
        die "Patch failed: $_";
    };
}

1;
