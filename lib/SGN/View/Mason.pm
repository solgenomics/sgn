=head1 NAME

SGN::View::Mason - Mason View Component for SGN

=head1 DESCRIPTION

Mason View Component for SGN. This extends Catalyst::View::HTML::Mason.

=cut

package SGN::View::Mason;
use Moose;
use Moose::Util::TypeConstraints;
use namespace::autoclean;

extends 'Catalyst::View::HTML::Mason';
with 'Catalyst::Component::ApplicationAttribute';

__PACKAGE__->config(
    globals => ['$c'],
    template_extension => '.mas',
    interp_args => {
        data_dir => SGN->tempfiles_base->subdir('mason'),
        comp_root => [
            [ main => SGN->path_to('mason') ],
        ],
        preamble => "use utf8; ",
    },
);

=head1 CONFIGURATION SETTINGS (which are also accessors)

=head2 add_comp_root

Configurable arrayref of additional Mason component roots.  These will
be searched before the default ones.  Must be absolute paths.

=cut

# munges the interp_args comp_root to include the add_comp_root
# configuration, plus the comp roots for SiteFeatures
sub COMPONENT {
    my ( $class, $c, $args ) = @_;

    $args = $class->merge_config_hashes( $class->config, $args );

    # coerce add_comp_root to arrayref
    if( $args->{add_comp_root} && ! ref $args->{add_comp_root} ) {
        $args->{add_comp_root} = [ $args->{add_comp_root} ];
    }

    # add comp roots for features and add_comp_root
    unshift @{ $args->{interp_args}->{comp_root} }, (
            # add_comp_root
            ( map [ additional => $_ ], @{ $args->{add_comp_root} || [] } ),
            # SiteFeatures
            ( map [ $_->feature_name, $_->path_to('mason')], $c->features ),
    );

    return $class->new($c, $args);
}

=head1 FUNCTIONS

=head2 $self->component_exists($component)

Check if a Mason component exists. Returns 1 if the component exists, otherwise 0.


=cut

sub component_exists {
    my ( $self, $component ) = @_;

    return $self->interp->comp_exists( $component ) ? 1 : 0;
}

=head1 SEE ALSO

L<SGN>, L<HTML::Mason>, L<Catalyst::View::HTML::Mason>

=head1 AUTHORS

Robert Buels, Jonathan "Duke" Leto

=head1 LICENSE

This library is free software . You can redistribute it and/or modify it under
the same terms as perl itself.

=cut

__PACKAGE__->meta->make_immutable;
1;
