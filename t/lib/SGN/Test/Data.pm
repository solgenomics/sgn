package SGN::Test::Data;

use Bio::Chado::Schema::Sequence::Feature;
use SGN::Context;
use base 'Exporter';
use Test::More;

our $schema = SGN::Context->new->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

our $num_features = 0;
our $num_cvterms = 0;
our $num_dbxrefs = 0;
our $num_organisms = 0;
our $test_data;
our @EXPORT_OK = qw/
                    create_test_dbxref create_test_cvterm
                    create_test_organism create_test_feature
                    /;

sub create_test_dbxref {
    my ($values) = @_;
    my $dbxref = $schema->resultset('General::Db')
           ->create( { name => $values->{name} || "db_$num_dbxrefs" } )
           ->create_related('dbxrefs',
            {
                accession => $values->{accession} || "dbxref_$num_dbxrefs",
            });
    push @$test_data, $dbxref;
    return $dbxref;
}

sub create_test_cvterm {
    my ($values) = @_;
    unless ($values->{name}) {
        $values->{name} = "cvterm $num_cvterms";
        $num_cvterms++;
    }
    my $cvterm = $schema->resultset('Cv::Cv')
           ->create( { name => "cv_" . $values->{name} } )
           ->create_related('cvterms',
            {
                name => $values->{name},
                dbxref => $values->{dbxref} || create_test_dbxref(),
            });
    push @$test_data, $cvterm;
    return $cvterm;
}

sub create_test_organsim {
    my ($values) = @_;
    unless ($values->{genus}) {
        $values->{genus} = "organism_$num_organisms";
        $num_organisms++;
    }
    unless ($values->{species}) {
        $values->{species} = 'fooii';
    }
    my $organism = $schema->resultset('Organism::Organism')
                          ->create( $values );
    push @$test_data, $organism;
    return $organism;

}

sub create_test_feature {
    my ($values) = @_;

    # provide some defaults for things we don't care about
    $values->{residues} = 'ATCG' unless $values->{residues};
    $values->{seqlen} = length($values->{residues}) unless $values->{seqlen};
    unless ($values->{name}) {
        $values->{name} = "Feature #" . $num_features;
        $num_features++;
    }
    unless ($values->{uniquename}) {
        $values->{name} = "Unique Feature #" . $num_features;
        $num_features++;
    }

    $values->{organism} ||= create_test_organism();
    $values->{cvterm}   ||= create_test_cvterm();

    my $organism = $schema->resultset('Sequence::Feature')
           ->create( $values );
    push @$test_data, $organism;
    return $organism;
}

sub END {
    diag("deleting $#$test_data test data objects") if @$test_data;
    # delete objects in the reverse order we created them
    # TODO: catch signals?
    map {
        diag("deleting $_");
        my $deleted = $_->delete;
    } reverse @$test_data;
}

1;
