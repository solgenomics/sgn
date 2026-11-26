#!/usr/bin/env perl


=head1 NAME

AddGenomicStatisticsTerms.pm

=head1 SYNOPSIS

mx-run AddGenomicStatisticsTerms [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch adds the statistical ontology (SGNSTAT) terms SGNSTAT:0000058 and
SGNSTAT:0000059 from ontology/cxgn_statistics.obo. The Analysis Pipeline uses
them to post-compose the traits of stored analyses whose genotype values are
genomic estimated breeding values (GEBVs) fitted with BLUPF90+: with the
genomic relationship matrix G (GBLUP) or with the single-step matrix H
(pedigree and genomic relationships, ssGBLUP).

This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

Chris Simoes <ccs263@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2026 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddGenomicStatisticsTerms;

use Moose;
use Bio::Chado::Schema;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
Adds the SGNSTAT terms used to post-compose the traits of Analysis Pipeline analyses with genomic (G) and single-step (H) BLUPF90+ models

has '+prereq' => (
    default => sub {
        [],
    },
  );

my @TERMS = (
    [ '0000058', 'GEBVs from genomic BLUPs (G matrix, GBLUP) using BLUPF90+' ],
    [ '0000059', 'GEBVs from single-step genomic BLUPs (H matrix, ssGBLUP) using BLUPF90+' ],
);

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";
    my $schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );

    my $coderef = sub {
        my $db = $schema->resultset('General::Db')->find_or_create({ name => 'SGNSTAT' });
        my $cv = $schema->resultset('Cv::Cv')->find_or_create({ name => 'SGNStatistics_ontology' });
        my $root = $schema->resultset('Cv::Cvterm')->find(
            { 'dbxref.db_id' => $db->db_id(), 'dbxref.accession' => '0000000' },
            { join => 'dbxref' }
        );
        my $relationship_cv = $schema->resultset('Cv::Cv')->find({ name => 'relationship' });
        my $is_a = $relationship_cv ? $schema->resultset('Cv::Cvterm')->find({ name => 'is_a', cv_id => $relationship_cv->cv_id() }) : undef;

        foreach my $t (@TERMS) {
            my ($accession, $name) = @$t;
            my $existing = $schema->resultset('Cv::Cvterm')->find(
                { 'dbxref.db_id' => $db->db_id(), 'dbxref.accession' => $accession },
                { join => 'dbxref' }
            );
            if ($existing) {
                print STDOUT "SGNSTAT:$accession already exists, skipping.\n";
                next;
            }
            my $dbxref = $schema->resultset('General::Dbxref')->find_or_create({ db_id => $db->db_id(), accession => $accession });
            # a term with this name but without its SGNSTAT accession gets the accession
            my $term = $schema->resultset('Cv::Cvterm')->find({ cv_id => $cv->cv_id(), name => $name, is_obsolete => 0 });
            if ($term) {
                $term->update({ dbxref_id => $dbxref->dbxref_id() });
                print STDOUT "Set the accession SGNSTAT:$accession of $name\n";
            } else {
                $term = $schema->resultset('Cv::Cvterm')->create({
                    cv_id => $cv->cv_id(),
                    name => $name,
                    dbxref_id => $dbxref->dbxref_id(),
                });
                print STDOUT "Added SGNSTAT:$accession $name\n";
            }
            if ($root && $is_a) {
                $schema->resultset('Cv::CvtermRelationship')->find_or_create({
                    subject_id => $term->cvterm_id(),
                    object_id => $root->cvterm_id(),
                    type_id => $is_a->cvterm_id(),
                });
            }
        }
    };

    $schema->txn_do($coderef);

    print "You're done!\n";
}


####
1; #
####
