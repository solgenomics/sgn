package SGN::Controller::SiteFeatures;
use Moose;
use namespace::autoclean;

use SGN::View::Mason::CrossReference 'resolve_xref_component';

BEGIN {extends 'Catalyst::Controller::REST'; }

__PACKAGE__->config(
    default   => 'text/html',
    stash_key => 'rest',
    map       => {
        'text/html' => [ 'View', 'BareMason' ],
    },
   );

=head1 NAME

SGN::Controller::SiteFeatures - Catalyst Controller

=head1 DESCRIPTION

Catalyst controller for web services involving site features and
xrefs.

=head1 PUBLIC ACTIONS

=head2 feature_xrefs

Public path: /api/v1/feature_xrefs

Web service interface to C<$c-E<gt>feature_xrefs>.

=cut

sub feature_xrefs :Path('/api/v1/feature_xrefs') :Args(0) {
    my ( $self, $c ) = @_;

    no warnings 'uninitialized';

    my $type = $c->req->param('render_type') || 'link';

    my $args = {};
    if( my @exclude = split /,/, $c->req->param('exclude') ) {
        $args->{exclude} = \@exclude;
    }

    my $xrefs = [ $c->feature_xrefs( $c->req->param('q'), $args ) ];
    $c->stash(
        template => "/sitefeatures/mixed/xref_set/$type.mas",

        xrefs => $xrefs,
        rest  => $xrefs,
       );
}

=head1 AUTHOR

Robert Buels

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

