package TestApp;

use Moose;
extends 'Catalyst';

__PACKAGE__->config( default_view => 'Mason' );
__PACKAGE__->setup;

1;
