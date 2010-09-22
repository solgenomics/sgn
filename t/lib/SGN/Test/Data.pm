package SGN::Test::Data;

use Bio::Chado::Schema::Sequence::Feature;
use SGN::Context;

our $schema = SGN::Context->new->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

our $num_features = 0;
our $num_cvterms = 0;
our $num_dbxrefs = 0;
our $test_data;

sub create_test_dbxref {
    my ($values) = @_;
    my $dbxref = $schema->resultset('General::Db')
           ->create( { name => $values->{name} || 'test_db' } )
           ->create_related('dbxrefs',
            {
                accession => $values->{accession} || 'some_junk',
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
    $schema->resultset('Cv::Cv')
           ->create( { $values->{name} } )
           ->create_related('cvterms',
            {
                name => 'tester',
                dbxref => $values->{dbxref} || create_test_dbxref(),
            });
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

    push @$test_data, $schema->resultset('Sequence::Feature')
           ->create( $values );
}

sub END {
    # delete objects in the reverse order we created them
    # TODO: catch signals?
    map {
        $_->delete
    } reverse @$test_data;
}

1;
