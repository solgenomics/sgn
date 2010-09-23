#!/usr/bin/env perl

use strict;
use warnings;
use lib 't/lib';
use Test::More;

use_ok('SGN::Test::Data',
    qw/
    create_test_organism create_test_dbxref
    create_test_feature create_test_cvterm
    create_test_db create_test_cv
    /);

my $schema = SGN::Context->new->dbic_schema('Bio::Chado::Schema', 'sgn_test');

{
    my $db = create_test_db({
                    name => "SGNTESTDATA_$$",
                });

    isa_ok($db, 'Bio::Chado::Schema::General::Db');
    my $rs = $schema->resultset('General::Db')
        ->search({ name => "SGNTESTDATA_$$" });
    is($rs->count, 1, 'found exactly one db that was created');
}
{
    my $dbxref = create_test_dbxref({
                    accession => "SGNTESTDATA_$$",
                });

    isa_ok($dbxref, 'Bio::Chado::Schema::General::Dbxref');

    my $rs = $schema->resultset('General::Dbxref')
        ->search({ accession => "SGNTESTDATA_$$" });
    is($rs->count, 1, 'found exactly one dbxref that was created');
}

{
    my $cvterm = create_test_cvterm({
                    name => "SGNTESTDATA_$$",
                });

    isa_ok($cvterm, 'Bio::Chado::Schema::Cv::Cvterm');

    my $rs = $schema->resultset('Cv::Cvterm')
        ->search({ name => "SGNTESTDATA_$$" });
    is($rs->count, 1, 'found exactly one cvterm that was created');
}

{
    my $feature = create_test_feature({
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
    my $organism = create_test_organism({
        genus   => 'Tyrannosaurus',
        species => 'rex',
    });
    isa_ok($organism, 'Bio::Chado::Schema::Organism::Organism');

    my $rs = $schema->resultset('Organism::Organism')
        ->search({
            genus   => 'Tyrannosaurus',
            species => 'rex',
        });
    is($rs->count, 1, 'found a T.rex organism');
}


done_testing;
