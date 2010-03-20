package Bio::Graphics::Browser2::Plugin::CMapDumper;

# $Id: CMapDumper.pm,v 1.2 2005-12-09 22:19:09 mwz444 Exp $
use strict;
use Bio::Graphics::Browser2::Plugin;
use CGI qw(:standard *sup);

use vars '$VERSION', '@ISA';
$VERSION = '0.80';

@ISA = qw/ Bio::Graphics::Browser2::Plugin /;

sub name { "CMap File" }

sub description {
    p("Dumps a CMap readable file.");
}

sub config_defaults {
    my $self = shift;
    return {
        version     => 2,
        mode        => 'selected',
        disposition => 'view',
        coords      => 'absolute',
    };
}

sub reconfigure {
    my $self           = shift;
    my $current_config = $self->configuration;
    delete $current_config->{embed};
    foreach my $p ( $self->config_param() ) {
        $current_config->{$p} = $self->config_param($p);
    }
}

sub configure_form {
    my $self           = shift;
    my $current_config = $self->configuration;
    my $html;
    $html .= p(
        'Coordinates',
        radio_group(
            -name => $self->config_name('coords'),
            -values => [ 'absolute', 'relative' ],
            -labels => {
                absolute => 'relative to chromosome/contig/clone',
                relative => 'relative to dumped segment (start at 1)'
            },
            -default  => $current_config->{coords},
            -override => 1
        )
    );
    autoEscape(0);
    $html .= p(
        radio_group(
            -name => $self->config_name('disposition'),
            -values => [ 'view', 'save', 'edit' ],
            -labels => {
                view => 'View',
                save => 'Save to File',
                edit => 'Edit' . sup('**'),
            }
        )
    );
    $html .= p(
        'Where should the feature type be taken from (suggested: Method)?',
        radio_group(
            -name => $self->config_name('feature_type_source'),
            -values => [ 'method', 'source' ],
            -labels => {
                method => 'Method',
                source => 'Source',
            }
        )
    );
    autoEscape(1);

    $html .= p(
        sup('*'),
        "To edit, install a helper application for MIME type",
        cite('application/x-cmap'),
    );
    $html;
}

sub mime_type {
    my $self   = shift;
    my $config = $self->configuration;
    my $ps     = $self->page_settings;
    my $base   = join '_', @{$ps}{qw(ref start stop)};
    return $config->{disposition} eq 'view' ? 'text/plain'
      : $config->{disposition} eq 'save'
      ? ( 'application/octet-stream', "$base" )
      : $config->{disposition} eq 'edit' ? "application/x-cmap"
      : 'text/plain';
}

sub dump {
    my $self = shift;
    my ( $segment, @more_feature_sets ) = @_;
    my $page_settings = $self->page_settings;
    my $conf          = $self->browser_config;
    my $config        = $self->configuration;
    my $version       = $config->{version} || 2;
    my $mode          = $config->{mode} || 'selected';
    my $db            = $self->database;
    my $whole_segment = $db->segment( Accession => $segment->ref )
      || $db->segment( $segment->ref );
    my $ft_source = $config->{feature_type_source};
    my $coords    = $config->{coords};
    my $embed     = $config->{embed};

    $segment->refseq($segment) if $coords eq 'relative';

    print join( "\t",
        'map_name',          'map_start',
        'map_stop',          'feature_name',
        'feature_start',     'feature_stop',
        'feature_direction', 'feature_type_accession' )
      . "\n";

    my @args;
    if ( $mode eq 'selected' ) {
        my @feature_types = $self->selected_features;
        @args = ( -types => \@feature_types );
    }

    my @feats = ();

    my $ref_name  = $segment->{'sourceseq'};
    my $ref_start = $segment->start;
    my $ref_stop  = $segment->stop;
    my $offset    = $segment->start - $segment->abs_start;
    my (
        $feature_name, $feature_start, $feature_stop,
        $strand_str,   $feature_type
    );
    my $iterator = $segment->get_seq_stream(@args);

    while ( my $f = $iterator->next_seq ) {
        $feature_name  = $f->{'group'}->name;
        $feature_start = $f->{'start'} + $offset;
        $feature_stop  = $f->{'stop'} + $offset;
        $strand_str    = $f->{'fstrand'};
        if ( $ft_source eq 'source' ) {
            $feature_type = $f->{'type'}->source();
        }
        else {
            $feature_type = $f->{'type'}->method();
        }

        $self->print_feature_row(
            map_name         => $ref_name,
            map_start        => $ref_start,
            map_stop         => $ref_stop,
            feature_name     => $feature_name,
            feature_stop     => $feature_stop,
            feature_start    => $feature_start,
            strand_value     => $strand_str,
            feature_type_aid => $feature_type,
        );

        for my $set (@more_feature_sets) {
            if ( $set->can('get_seq_stream') ) {
                my @feats    = ();
                my $iterator = $set->get_seq_stream;
                while ( my $f = $iterator->next_seq ) {
                    $feature_name  = $f->{'group'}->name;
                    $feature_start = $f->{'start'} + $offset;
                    $feature_stop  = $f->{'stop'} + $offset;
                    $strand_str    = $f->{'fstrand'};
                    $feature_type  = $f->{'type'}->method();

                    $self->print_feature_row(
                        map_name         => $ref_name,
                        map_start        => $ref_start,
                        map_stop         => $ref_stop,
                        feature_name     => $feature_name,
                        feature_stop     => $feature_stop,
                        feature_start    => $feature_start,
                        strand_value     => $strand_str,
                        feature_type_aid => $feature_type,
                    );
                }
            }
        }
    }

    if ($embed) {
        my $dna = $segment->dna;
        $dna =~ s/(\S{60})/$1\n/g;
        print ">$segment\n$dna\n" if $dna;
    }

}

sub print_feature_row {

    my $self             = shift;
    my %args             = @_;
    my $map_name         = $args{'map_name'};
    my $map_start        = $args{'map_start'};
    my $map_stop         = $args{'map_stop'};
    my $feature_name     = $args{'feature_name'};
    my $feature_stop     = $args{'feature_stop'};
    my $feature_start    = $args{'feature_start'};
    my $strand_value     = $args{'strand_value'};
    my $feature_type_aid = $args{'feature_type_aid'};

    my $feature_direction = ( $strand_value eq '-' ) ? -1 : 1;

    print join( "\t",
        $map_name, $map_start, $map_stop, $feature_name, $feature_start,
        $feature_stop, $feature_direction, $feature_type_aid )
      . "\n";

}

1;
