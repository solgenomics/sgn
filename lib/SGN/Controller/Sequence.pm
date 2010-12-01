package SGN::Controller::Sequence;

=head1 NAME

SGN::Controller::Sequence - Catalyst controller for dealing with sequences

=cut

use Moose;
use namespace::autoclean;

use URI::FromHash 'uri';

BEGIN { extends 'Catalyst::Controller' }
with 'Catalyst::Component::ApplicationAttribute';
our $c;

sub api_v1_sequence :Path('/api/v1/sequence') Args(1) {
    my ( $self, $c, $feature_name ) = @_;
    $self->_render_sequence($c, 'name', $feature_name);
}

sub _render_sequence {
    my ($self, $c, $key, $value) = @_;

    if ( $value =~ m/\.fasta$/ ) {
        $value =~ s/\.fasta$//;
        my $matching_features = $c->dbic_schema('Bio::Chado::Schema','sgn_chado')
                                    ->resultset('Sequence::Feature')
                                    ->search({ $key => $value });
        my $feature = $matching_features->next
            or $c->throw_404("feature with $key = '$value' not found");
        $c->stash->{feature} = $feature;
        $self->render_fasta($c);
    }
}

sub render_fasta {
    my ($self, $c) = @_;

    my ($start,$end) =  split /\.\./, $c->request->query_keywords || '';
    my $feature = $c->stash->{feature};
    my $matching_features = $c->dbic_schema('Bio::Chado::Schema','sgn_chado')
                                ->resultset('Sequence::Feature')
                                ->search({ name => $feature->name });

    my $name = $feature->name;
    if( $start && $end && $end > $start ){
        $name .= ":$start..$end";
    }
    my $seq = Bio::PrimarySeq->new(
                    -id  => $name,
                    -seq => $feature->residues,
                    );
    # ignores invalid ranges right now, should do something better
    if ($seq->length > 0 && $start && $end && $end > $start ) {
        $seq = $seq->trunc($start,$end);
    }
    my $fasta;
    my $fastaio = IO::String->new($fasta);
    Bio::SeqIO->new( -format => 'fasta',
                     -fh     => $fastaio,
    )->write_seq( $seq );

    $c->res->content_type('text/plain');
    $c->res->status( 200 );
    $c->res->body( $fasta );
}

__PACKAGE__->meta->make_immutable;

1;

