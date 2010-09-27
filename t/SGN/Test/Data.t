#!/usr/bin/env perl

use strict;
use warnings;
use lib 't/lib';
use Test::More;

use_ok('SGN::Test::Data', qw/ create_test /);

my $schema = SGN::Context->new->dbic_schema('Bio::Chado::Schema', 'sgn_test');

{
    my $db = create_test('General::Db', {
                    name => "SGNTESTDATA_$$",
                });

    isa_ok($db, 'Bio::Chado::Schema::General::Db');
    my $rs = $schema->resultset('General::Db')
        ->search({
            name  => "SGNTESTDATA_$$",
            db_id => $db->db_id,
    });
    is($rs->count, 1, 'found exactly one db that was created');
}
{
    my $dbxref = create_test('General::Dbxref',{
                    accession => "SGNTESTDATA_$$",
                });

    isa_ok($dbxref, 'Bio::Chado::Schema::General::Dbxref');

    my $rs = $schema->resultset('General::Dbxref')
        ->search({
            accession => "SGNTESTDATA_$$",
            dbxref_id => $dbxref->dbxref_id
    });
    is($rs->count, 1, 'found exactly one dbxref that was created');
}

{
    my $cv = create_test('Cv::Cv',{
                    name => "SGNTESTDATA_$$",
                });

    isa_ok($cv, 'Bio::Chado::Schema::Cv::Cv');

    my $rs = $schema->resultset('Cv::Cv')
        ->search({
            name      => "SGNTESTDATA_$$",
            cv_id => $cv->cv_id,
    });
    is($rs->count, 1, 'found exactly one cv that was created');
}

{
    my $cvterm = create_test('Cv::Cvterm',{
                    name => "SGNTESTDATA_$$",
                });

    isa_ok($cvterm, 'Bio::Chado::Schema::Cv::Cvterm');

    my $rs = $schema->resultset('Cv::Cvterm')
        ->search({
            name      => "SGNTESTDATA_$$",
            cvterm_id => $cvterm->cvterm_id,
    });
    is($rs->count, 1, 'found exactly one cvterm that was created');
}

{
    my $feature = create_test('Sequence::Feature',{
        residues => 'GATTACA',
    });
    isa_ok($feature, 'Bio::Chado::Schema::Sequence::Feature');

    my $rs = $schema->resultset('Sequence::Feature')
        ->search({
            residues => "GATTACA",
            feature_id => $feature->feature_id,
        });
    is($rs->count, 1, 'found feature with sequence = GATTACA');
}
{
    my $featureloc = create_test('Sequence::Featureloc',{
        fmin => 42,
        fmax => 69,
    });
    isa_ok($featureloc, 'Bio::Chado::Schema::Sequence::Featureloc');

    my $rs = $schema->resultset('Sequence::Featureloc')
        ->search({
            fmin => 42,
            fmax => 69,
            featureloc_id => $featureloc->featureloc_id,
        });
    is($rs->count, 1, 'found featureloc with correct fmin/fmax');
}

{
    my $organism = create_test('Organism::Organism',{
        genus   => 'Tyrannosaurus',
        species => 'Tyrannosaurus rex',
    });
    isa_ok($organism, 'Bio::Chado::Schema::Organism::Organism');

    my $rs = $schema->resultset('Organism::Organism')
        ->search({
            genus       => 'Tyrannosaurus',
            species     => 'Tyrannosaurus rex',
            organism_id => $organism->organism_id,
        });
    is($rs->count, 1, 'found a T.rex organism');
}

{
    my @f = map { create_test('Sequence::Feature') } (1..2);
    isnt($f[0]->name,$f[1]->name,'two features created have different names');
    isnt($f[0]->uniquename,$f[1]->uniquename,'two features created have different unique names');
}
{
    my @o = map { create_test('Organism::Organism') } (1..2);
    isnt($o[0]->genus,$o[1]->genus,'two organisms created have different genus');
    isnt($o[0]->species,$o[1]->species,'two organisms created have different species');
}

done_testing;
