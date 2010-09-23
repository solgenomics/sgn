package SGN::Test::Data;

use strict;
use warnings;
use Bio::Chado::Schema::Sequence::Feature;
use SGN::Context;
use base 'Exporter';
use Test::More;

our $schema;

BEGIN {
    my $db_profile = 'sgn_test';
    eval {
        $schema = SGN::Context->new->dbic_schema('Bio::Chado::Schema', $db_profile)
    };
    if ($@) {
        plan skip_all => "Could not create a db connection. Do  you have the $db_profile db profile?";
    }
}

our $num_features = 0;
our $num_cvterms = 0;
our $num_dbxrefs = 0;
our $num_dbs = 0;
our $num_cvs = 0;
our $num_organisms = 0;
our $test_data;
our @EXPORT_OK = qw/
                    create_test_dbxref create_test_cvterm
                    create_test_organism create_test_feature
                    create_test_db create_test_cv
                    /;

sub create_test_db {
    my ($values) = @_;
    my $db = $schema->resultset('General::Db')
           ->create( { name => $values->{name} || "db_$num_dbs-$$" } );
    push @$test_data, $db;
    $num_dbs++;
    return $db;
}

sub create_test_dbxref {
    my ($values) = @_;
    $values->{db} ||= create_test_db();

    my $dbxref = $schema->resultset('General::Dbxref')
           ->create(
            {
                db_id     => $values->{db}->db_id,
                accession => $values->{accession} || "dbxref_$num_dbxrefs-$$",
            });
    push @$test_data, $dbxref;
    $num_dbxrefs++;
    return $dbxref;
}

sub create_test_cv {
    my ($values) = @_;
    unless ($values->{name}) {
        $values->{name} = "cv_$num_cvs-$$";
    }
    my $cv = $schema->resultset('Cv::Cv')
           ->create( { name => $values->{name} } );

    push @$test_data, $cv;
    $num_cvs++;
    return $cv;
}

sub create_test_cvterm {
    my ($values) = @_;
    unless ($values->{name}) {
        $values->{name} = "cvterm_$num_cvterms-$$";
    }
    $values->{dbxref} ||= create_test_dbxref();
    $values->{cv} ||= create_test_cv();
    my $cvterm = $schema->resultset('Cv::Cvterm')
           ->create(
            {
                name   => $values->{name},
                dbxref => $values->{dbxref},
                cv_id  => $values->{cv}->cv_id,
            });
    push @$test_data, $cvterm;
    $num_cvterms++;
    return $cvterm;
}

sub create_test_organism {
    my ($values) = @_;
    unless ($values->{genus}) {
        $values->{genus} = "organism_$num_organisms-$$";
    }
    unless ($values->{species}) {
        $values->{species} = $values->{genus} . ' fooii';
    }
    my $organism = $schema->resultset('Organism::Organism')
                          ->create( $values );
    push @$test_data, $organism;
    $num_organisms++;
    return $organism;

}

sub create_test_feature {
    my ($values) = @_;

    # provide some defaults for things we don't care about
    $values->{residues} = 'ATCG' unless $values->{residues};
    $values->{seqlen} = length($values->{residues}) unless $values->{seqlen};
    unless ($values->{name}) {
        $values->{name} = "feature_$num_features-$$";
        $num_features++;
    }
    unless ($values->{uniquename}) {
        $values->{uniquename} = "unique_feature_$num_features-$$";
        $num_features++;
    }

    $values->{organism} ||= create_test_organism();
    $values->{type}     ||= create_test_cvterm();

    my $organism = $schema->resultset('Sequence::Feature')
           ->create({
                residues    => $values->{residues},
                seqlen      => $values->{seqlen},
                name        => $values->{name},
                uniquename  => $values->{uniquename},
                type_id     => $values->{type}->cvterm_id,
                organism_id => $values->{organism}->organism_id,
           });
    push @$test_data, $organism;
    return $organism;
}

sub END {
    diag("deleting " . scalar(@$test_data) . " test data objects") if @$test_data;
    # delete objects in the reverse order we created them
    # TODO: catch signals?
    map {
        diag("deleting $_") if $ENV{DEBUG};
        my $deleted = $_->delete;
    } reverse @$test_data;
}

1;
