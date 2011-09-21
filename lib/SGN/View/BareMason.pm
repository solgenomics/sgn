package SGN::View::BareMason;
use Moose;
extends 'SGN::View::Mason';

# inherit all the munged interp_args settings from SGN::View::Mason,
# then turn the autohandler off
sub COMPONENT {
    my ($class, $c, $args) = @_;

    $args = $class->merge_config_hashes(
        $class->config,
        {
          %$args,
          interp_args => {
            %{ $c->view('Mason')->interp_args },
            autohandler_name => '',
          },
        },
      );

    return $class->new($c, $args);
}

=head1 NAME

SGN::View::BareMason - like the Mason view, except with no autohandlers

=head1 DESCRIPTION

Mason View Component for SGN

=head1 SEE ALSO

L<SGN>, L<HTML::Mason>

=head1 AUTHOR

Robert Buels,,,

=head1 LICENSE

This library is free software . You can redistribute it and/or modify it under
the same terms as perl itself.

=cut

1;
