=head1 NAME

SGN::Feature::FeaturePages - site feature for genomic feature pages
(SGN::Controller::Feature, SGN::View::Feature, mason/features)

=head1 SYNOPSIS

Subclass of L<SGN::Feature>, just does all the things expected of a
site feature.

=cut

package SGN::Feature::FeaturePages;
use Moose;

use URI;

extends 'SGN::Feature';

has '+description' => (
    default    => 'Genomic details',
   );

sub xrefs {
    my ( $self, $query ) = @_;

    return if ref $query;
    $query = lc $query;

    my $feats = $self->context->dbic_schema('Bio::Chado::Schema','sgn_chado')
                     ->resultset('Sequence::Feature')
                     ->search({},{ prefetch => 'type' });

    my @exact =
        map { $self->_make_xref( $_ ) }
            ( $feats->search({
                -or => [ { 'lower(me.uniquename)' => $query },
                         { 'lower(me.name)'       => $query },
                       ],
               }),
               $feats->search(
                   { 'lower(synonym.name)' => $query },
                   { join => { feature_synonyms => 'synonym' } },
               ),
             );

    return @exact;
}

sub _make_xref {
    my ( $self, $feature ) = @_;

    return SGN::SiteFeatures::CrossReference->new({
        feature      => $self,

        text => $feature->name.' '.$feature->type->name.' feature details',

        url => URI->new('/feature/'.$feature->feature_id.'/details'),

    });
}

__PACKAGE__->meta->make_immutable;
1;
