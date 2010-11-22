package SGN::View::Mason::CrossReference;
use strict;
use warnings;

use Carp;

use base 'Exporter';
our @EXPORT_OK = qw( resolve_xref_component );

sub resolve_xref_component {
    my ( $m, $feature, $comp_pattern ) = @_;

    for my $fname ( $feature->feature_name, 'default' ) {
        my $comp = $comp_pattern;
        $comp =~ s/(?<!%)%f/$fname/g;

        return $comp if $m->comp_exists( $comp );
    }

    croak "Cannot find Mason component for pattern '$comp_pattern' sitefeature ".$feature->feature_name;
}


1;
