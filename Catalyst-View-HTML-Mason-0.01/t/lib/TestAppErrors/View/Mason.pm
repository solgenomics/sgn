package TestAppErrors::View::Mason;

use Moose;
use namespace::autoclean;

extends 'Catalyst::View::HTML::Mason';

__PACKAGE__->config(
    globals => [
        '$affe',
        ['$ctx' => sub { $_[1] }],
    ],
    interp_args => {
        comp_root => TestAppErrors->path_to('root')->stringify,
    },
);

__PACKAGE__->meta->make_immutable;

1;
