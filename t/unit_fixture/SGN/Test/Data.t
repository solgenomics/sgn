#!/usr/bin/env perl

use strict;
use warnings;
use lib 't/lib';
use Test::Most;
#use Carp::Always;

use_ok('SGN::Test::Data', qw/ create_test /);

my $schema = SGN::Context->new->dbic_schema('Bio::Chado::Schema', 'sgn_test');

{
    my $db = create_test('General::Db', {
                    name => "SGNTESTDATA_$$",
                });

    my $rs = $schema->resultset('General::Db')
        ->search({
            name  => "SGNTESTDATA_$$",
            db_id => $db->db_id,
    });
    is($rs->count, 1, 'found exactly one db that was created');
}
{
    my %options = (
        version     => 42,
        accession   => "SGNTESTDATA_$$",
        description => "A bunch of nonsense",
    );
    my $dbxref = create_test('General::Dbxref',{
                    %options,
                });

    is( $dbxref->result_source->source_name, 'General::Dbxref');

    my $rs = $schema->resultset('General::Dbxref')
        ->search({
            %options,
            dbxref_id => $dbxref->dbxref_id
    });
    is($rs->count, 1, 'found exactly one dbxref that was created');
}

{
    my $cv = create_test('Cv::Cv',{
                    name       => "SGNTESTDATA_$$",
                    definition => "blah",
                });

    is( $cv->result_source->source_name, 'Cv::Cv');

    my $rs = $schema->resultset('Cv::Cv')
        ->search({
            name       => "SGNTESTDATA_$$",
            definition => "blah",
            cv_id => $cv->cv_id,
    });
    is($rs->count, 1, 'found exactly one cv that was created');
}

{
    my $dbxref = create_test('General::Dbxref');
    my %options = (
        name                => "SGNTESTDATA_$$",
        definition          => "stuff",
        is_obsolete         => 1,
        is_relationshiptype => 1,
    );
    my $cvterm = create_test('Cv::Cvterm',{
                    %options,
                    dbxref => $dbxref,
                });

    is( $cvterm->result_source->source_name, 'Cv::Cvterm');

    my $rs = $schema->resultset('Cv::Cvterm')
        ->search({
            %options,
            cvterm_id => $cvterm->cvterm_id,
            dbxref_id => $dbxref->dbxref_id,
    });
    is($rs->count, 1, 'found exactly one cvterm that was created');
}

{
    my $cvterm = create_test('Cv::Cvterm');
    my $f1 = create_test('Sequence::Feature');
    my $f2 = create_test('Sequence::Feature');
    my %options = (
        rank => 42,
        value => 'blarg',
    );
    my $f = create_test('Sequence::FeatureRelationship',{
        subject => $f1,
        object  => $f2,
        type    => $cvterm,
        %options,
    });
    is( $f->result_source->source_name, 'Sequence::FeatureRelationship');

    my $rs = $schema->resultset('Sequence::FeatureRelationship')
        ->search({
            feature_relationship_id  => $f->feature_relationship_id,
            subject_id => $f1->feature_id,
            object_id  => $f2->feature_id,
            type_id    => $cvterm->cvterm_id,
            %options,
        });
    is($rs->count, 1, 'found one feature_relationship with correct data');
}

{
    my %options = (
        residues          => 'GATTACA',
        is_obsolete       => 1,
        is_analysis       => 1,
        name              => 'Bob',
        seqlen            => 7,
        md5checksum       => 'c0decafe',
        timeaccessioned   => '2010-10-07 17:28:54.756113',
        timelastmodified  => '2000-10-07 17:28:54.756113',
    );
    my $organism = create_test('Organism::Organism');
    my $dbxref   = create_test('General::Dbxref');
    my $feature = create_test('Sequence::Feature',{
        organism => $organism,
        dbxref   => $dbxref,
        %options,
    });
    is( $feature->result_source->source_name, 'Sequence::Feature');

    my $rs = $schema->resultset('Sequence::Feature')
        ->search({
            organism_id => $organism->organism_id,
            feature_id  => $feature->feature_id,
            dbxref_id   => $dbxref->dbxref_id,
            %options,
        });
    is($rs->count, 1, 'found one feature with correct data');
}
{
    my %options = (
        fmin            => 42,
        fmax            => 69,
        rank            => 2,
        strand          => 1,
        phase           => 2,
        residue_info    => "stain",
        is_fmax_partial => 1,
        locgroup        => 19,
    );
    my $featureloc = create_test('Sequence::Featureloc',{
        %options,
    });
    is( $featureloc->result_source->source_name, 'Sequence::Featureloc');

    my $rs = $schema->resultset('Sequence::Featureloc')
        ->search({
            %options,
            featureloc_id => $featureloc->featureloc_id,
        });
    is($rs->count, 1, 'found featureloc with correct options');
}

{
    my $featureprop = create_test('Sequence::Featureprop',{
        value => 42,
        rank => 69,
    });
    is( $featureprop->result_source->source_name, 'Sequence::Featureprop');

    my $rs = $schema->resultset('Sequence::Featureprop')
        ->search({
            featureprop_id => $featureprop->featureprop_id,
            value          => 42,
            rank           => 69,
        });
    is($rs->count, 1, 'found featureprop with correct value and rank');
}

{
    my %options = (
        genus       => 'Tyrannosaurus',
        species     => 'Tyrannosaurus rex',
        common_name => 'Tyrant King',
        comment     => 'Small hands',
        abbreviation=> 'Trex',
    );
    my $organism = create_test('Organism::Organism',{
        %options,
    });
    is( $organism->result_source->source_name, 'Organism::Organism');

    my $rs = $schema->resultset('Organism::Organism')
        ->search({
            %options,
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

{

    my $cv  = create_test('Cv::Cv', { name => "The best CV ever" } );
    my @cvterms;
    # pre-created objects can be passed in, to specify linking objects
    lives_ok {
        @cvterms = map { create_test('Cv::Cvterm', { name  => "cvterm_$_", cv_id => $cv->cv_id, } ) } (1..3)
    } "can create a bunch of cvterms in one cv";

    is(@cvterms,3, "got 3 cvterms");
    map { is($cvterms[$_]->cv->cv_id, $cv->cv_id, "got the correct cv_id") } (0 .. 2);

}

{
    my %options = (
        description => "A bunch of nonsense",
        name        => "Stocky Stockstein",
    );
    my $stock = create_test('Stock::Stock',{
        %options,
    });
    is( $stock->result_source->source_name, 'Stock::Stock');
    my $rs = $schema->resultset('Stock::Stock')
        ->search({
            %options,
    });
    is($rs->count, 1, 'found exactly one stock that was created');
}

{
    my $cv = create_test('Cv::Cv');
    my %options = (
        pathdistance => 42,
        cv_id        => $cv->cv_id
    );
    my $cvtermpath = create_test('Cv::Cvtermpath',{
        %options,
    });
    is( $cvtermpath->result_source->source_name, 'Cv::Cvtermpath');
    my $rs = $schema->resultset('Cv::Cvtermpath')
        ->search({
            %options,
    });
    is($rs->count, 1, 'found exactly one cvtermpath that was created');
}

done_testing;
