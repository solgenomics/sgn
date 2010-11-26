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

has 'xref_discriminator' => (
    is => 'ro',
    isa => 'CodeRef',
    lazy_build => 1,
   ); sub _build_xref_discriminator {
       my ( $self ) = @_;
       return $self->gbrowse->config_master->code_setting( $self->name => 'restrict_xrefs' )
              || sub { 1 }
   }

has 'debug' => (
    is => 'rw',
    isa => 'Bool',
    default => 0,
   );

sub _build__databases {
    my $self = shift;
    local $_; #< Bio::Graphics::* sloppily clobbers $_
    my $conf = $self->config;
    my @dbs =  grep /:database$/i, $self->config->configured_types;
    return {
        map {
            my $dbname = $_;
            my $adaptor = $conf->setting( $dbname => 'db_adaptor' )
                or confess "no db adaptor for [$_] in ".$self->path->basename;
            my @args = shellwords( $conf->setting( $dbname => 'db_args' ));
            Class::MOP::load_class( $adaptor );
            my $conn = eval {
                local $SIG{__WARN__} = sub { warn @_ if $self->debug };
                $adaptor->new( @args );
            };
            if( $@ ) {
                warn $self->path->basename." [$dbname] not available\n";
                warn $@ if $self->debug;
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

    return unless $self->xref_discriminator->($q);

    if( my $ref =  ref $q ) {
        return unless $ref eq 'HASH';

        # search for features in all our DBs
        return $self->_make_feature_xrefs([
            map $_->features( %$q ), $self->databases
         ]);
    } else {
        # search for a region on a reference sequence specified like seq_name:23423..66666
        if( my ($ref_name,$start,$end) = $q =~ /^ \s* ([^:]+) \s* : (\d+) \s* .. \s* (\d+) $/x) {
            return
                # make xrefs for the given range of each of the ref features
                map $self->_make_region_xref({
                      features => [$_],
                      range    => Bio::Range->new( -start => $start, -end => $end )
                     }),
                # search for ref features
                map $_->get_feature_by_name( $ref_name ),
                # for each database
                $self->databases;

        } else {
            # search for features by text in all our DBs
            return $self->_make_feature_xrefs([
                map $_->get_feature_by_name( $q ), $self->databases
            ]);
        }
    }

    return;
}

sub _make_feature_xrefs {
    my ( $self, $features ) = @_;

    # group the features by source sequence
    my %src_sequence_matches;
    push @{$src_sequence_matches{$_->seq_id}{features}}, $_ for @$features;

    # group the features for each src sequence into non-overlapping regions
    for my $src ( values %src_sequence_matches ) {

        # if the features are Bio::DB::GFF::Features, union() is buggy, so convert them
        # to Bio::Range to perform the union calculation
        my $ranges = $src->{features}->[0]->isa('Bio::DB::GFF::Feature')
            ? [ map Bio::Range->new( -start => $_->start, -end => $_->end ), @{$src->{features}} ]
            : $src->{features};
        my @regions =  map { {range => $_} } Bio::Range->unions( @$ranges );

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

    my @highlight =
        @{$region->{features}} == 1 # highlight our feature or region if we can
            ? ( h_feat => $region->{features}->[0]->display_name )
            : ( h_region =>  $region->{features}->[0]->seq_id.':'.$region->{range}->start.'..'.$region->{range}->end );


    return $self->_make_cross_ref(
        text => join( '',
            'view ',
            (  join ', ', map $_->display_name || $_->primary_id, @{$region->{features}}),
            ' in GBrowse - ',
            $self->description,
           ),
        url =>
            $self->view_url({ ref   => $region->{features}->[0]->seq_id,
                              start => $start,
                              end   => $end,
                              @highlight,
                          }),
        preview_image_url =>
            $self->image_url({
                name   => $region->{features}->[0]->seq_id.":$start..$end",
                format => 'GD',
            }),

        seqfeatures  => $region->{features},
        feature      => $self->gbrowse,
        data_source  => $self,
       );
}

sub image_url {
    my ( $self, $q ) = @_;
    $q ||= {};
    $q->{width}    ||= 600;
    $q->{keystyle} ||= 'between',
    $q->{grid}     ||= 1;
    return $self->_url( 'gbrowse_img', $q );
}


package SGN::Feature::GBrowse2::DataSource::CrossReference;
use Moose;
use MooseX::Types::URI qw/ Uri /;
extends 'SGN::SiteFeatures::CrossReference';

with 'SGN::SiteFeatures::CrossReference::WithPreviewImage',
     'SGN::SiteFeatures::CrossReference::WithSeqFeatures';

has 'data_source' => ( is => 'ro', required => 1 );

__PACKAGE__->meta->make_immutable;
1;
