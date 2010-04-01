package SGN::Feature::GBrowse2::DataSource;
use Moose;
use namespace::autoclean;
use Scalar::Util qw/ blessed /;
use Text::ParseWords;
use Path::Class ();
use URI::Escape;

use Bio::Range;

extends 'SGN::Feature::GBrowse::DataSource';

# has 'config' => ( documentation => <<'',
# Bio::Graphics::FeatureFile object for this data source's conf file, from which settings can be 

#     is => 'ro',
#     isa => 'Bio::Graphics::FeatureFile',
#     lazy_build => 1,
#   ); sub _build_config {
#       my ($self) = @_;
#       return Bio::Graphics::FeatureFile->new( -file => $self->conf_dir->file( $self->path ) );
#   }

has 'discriminator' => (
    is => 'ro',
    isa => 'CodeRef',
    lazy_build => 1,
   ); sub _build_discriminator {
       my ( $self ) = @_;
       return $self->gbrowse->config_master->code_setting( $self->name => 'restrict_xrefs' )
              || sub { 1 }
   }

sub _build__databases {
    my $self = shift;
    my $conf = $self->config;
    my @dbs =  grep /:database$/i, $self->config->configured_types;
    return {
        map {
            my $dbname = $_;
            my $adaptor = $conf->setting( $dbname => 'db_adaptor' )
                or confess "no db adaptor for [$_] in ".$self->path->basename;
            my @args = shellwords( $conf->setting( $dbname => 'db_args' ));
            Class::MOP::load_class( $adaptor );
            my $conn = eval { $adaptor->new( @args ) };
            if( $@ ) {
                warn $self->path->basename." [$dbname]: open failed\n$@";
                ()
            } else {
                $dbname =~ s/:database$//;
                $dbname => $conn
            }
        } @dbs
       };
}


# can accept either plaintext queries, or hashrefs describing features in the DB to search for
sub xrefs {
    my ($self, $q) = @_;

    return unless $self->discriminator->($q);

    if( my $ref =  ref $q ) {
        return unless $ref eq 'HASH';

        return $self->_feature_search_xrefs( $q );

    } else {
        return $self->_make_cross_ref(
            text       => qq|search for "$q" in GBrowse: |.$self->description,
            url        => $self->view_url({ name=> $q }),
            feature    => $self->gbrowse,
            datasource => $self,
           );
    }
}

sub _feature_search_xrefs {
    my ( $self, $q ) = @_;


    # search for features in all our DBs
    my @features =
        map $_->features( %$q ),
        $self->databases;


    # group the features by source sequence
    my %src_sequence_matches;
    push @{$src_sequence_matches{$_->seq_id}{features}}, $_ for @features;

    # group the features for each src sequence into non-overlapping regions
    for my $src ( values %src_sequence_matches ) {
        # make a set of non-overlapping regions
        my @regions = map { {range => $_} } Bio::Range->unions( @{$src->{features}} );

        # assign the features to each region
      FEATURE:
        foreach my $feature (@{$src->{features}}) {
            foreach my $region (@regions) {
                if( $feature->overlaps( $region->{range} )) {
                    push @{$region->{features}}, $feature;
                    next FEATURE;
                }
            }
        }
        $src->{regions} = \@regions;
        delete $src->{features}; #< not needed anymore
    }

    # make CrossReference object for each region
    return  map $self->_make_region_xref( $_ ),
            map @{$_->{regions}},
            values %src_sequence_matches;

}

sub _make_cross_ref {
    shift;
    return (__PACKAGE__.'::CrossReference')->new( @_ );
}

sub _make_region_xref {
    my ( $self, $region ) = @_;

    my ( $start, $end ) = ( $region->{range}->start, $region->{range}->end );
    ( $start, $end ) = ( $end, $start ) if $start > $end;

    return $self->_make_cross_ref(
        text       => join('', 'GBrowse - ', $self->description, ' matches: ', join ',', map $_->display_name || $_->primary_id, @{$region->{features}}),
        url        =>
            $self->view_url({ ref   => $region->{features}->[0]->seq_id,
                              start => $start,
                              end   => $end,
                          }),
        preview_img_url =>
            $self->img_url(  { ref      => $region->{features}->[0]->seq_id,
                               start    => $start,
                               end      => $end,
                             },
                           ),
        preview_seqfeatures => $region->{features},
        feature    => $self->gbrowse,
        datasource => $self,
       );
}


package SGN::Feature::GBrowse2::DataSource::CrossReference;
use Moose;
use MooseX::Types::URI qw/ Uri /;
extends 'SGN::SiteFeatures::CrossReference';

has 'datasource'         => ( is => 'ro', required => 1 );
has 'preview_img_url'    => ( is => 'ro', isa => Uri, coerce => 1 );
has 'preview_seqfeatures' => ( is => 'ro', isa => 'ArrayRef' );

__PACKAGE__->meta->make_immutable;
1;
