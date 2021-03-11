#!/usr/bin/env perl


=head1 NAME

AddSequenceMetadataTypes.pm

=head1 SYNOPSIS

mx-run AddSequenceMetadataTypes [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch adds the CV and CVTerms for the Sequence Metadata Types (used by the featureprop_json table)
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddSequenceMetadataTypes;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch adds the CV and CVTerms for the Sequence Metadata Types (used by the featureprop_json table)

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
    my $cvterm_rs = $schema->resultset("Cv::Cvterm");
	my $cv_rs = $schema->resultset("Cv::Cv");

    print STDERR "CREATING CV...\n";
    my $cv = $cv_rs->find_or_create({ name => 'sequence_metadata_types' });

    print STDERR "ADDING CVTERMS...\n";
    $cvterm_rs->create_with({
		name => 'Gene Annotation',
		cv => 'sequence_metadata_types'
	});
    $cvterm_rs->create_with({
		name => 'GWAS Results',
		cv => 'sequence_metadata_types'
	});
    $cvterm_rs->create_with({
		name => 'MNase',
		cv => 'sequence_metadata_types'
	});

    print STDERR "UPDATING DEFINITIONS...\n";
    $self->dbh->do(<<EOSQL);
UPDATE public.cvterm SET definition = 'Provides sequence features (gene, mRNA, UTR, exon, CDS) and annotations based on alignments of biological evidence.' 
WHERE name = 'Gene Annotation' AND cv_id = (SELECT cv_id FROM cv WHERE name = 'sequence_metadata_types');

UPDATE public.cvterm SET definition = 'Report of quantitative trait loci (QTLs) indentified by running rrBLUP analysis on phenotype trials and genotype trials within the T3 database.' 
WHERE name = 'GWAS Results' AND cv_id = (SELECT cv_id FROM cv WHERE name = 'sequence_metadata_types');

UPDATE public.cvterm SET definition = 'Report of chromatine accessibility score.  The report can be used to prioritize genomic variants and explain phenotypes. (https://genomebiology.biomedcentral.com/track/pdf/10.1186/s13059-020-02093-1)' 
WHERE name = 'MNase' AND cv_id = (SELECT cv_id FROM cv WHERE name = 'sequence_metadata_types');
EOSQL

    print "You're done!\n";
}


####
1; #
####
