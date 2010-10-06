package SGN::View::BareMason;
use Moose;
extends 'Catalyst::View::HTML::Mason';

__PACKAGE__->config(
    interp_args => {
        comp_root =>  SGN->path_to('mason'),
        autohandler_name => '',
    },
    globals => ['$c'],
    template_extension => '.mas',
);

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
