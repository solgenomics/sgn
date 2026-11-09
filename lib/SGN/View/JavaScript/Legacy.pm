package SGN::View::JavaScript::Legacy;
use strict;
use warnings;

use parent 'Catalyst::View::JavaScript::Minifier::XS';

use Encode ();

__PACKAGE__->config(
    js_dir => SGN->path_to('js/source/legacy'),
);

# The parent view reads and minifies the files as UTF-8 bytes, and Catalyst
# encodes the response body to UTF-8 again. Decode it, so that non-ASCII
# characters are encoded only once.
sub process {
    my ($self, $c) = @_;
    $self->SUPER::process($c);
    $c->res->body( Encode::decode('UTF-8', $c->res->body) );
    return 1;
}

1;
