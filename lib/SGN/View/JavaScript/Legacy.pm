package SGN::View::JavaScript::Legacy;
use strict;
use warnings;

use parent 'Catalyst::View::JavaScript::Minifier::XS';

__PACKAGE__->config(
    js_dir => SGN->path_to('js/source/legacy'),
);

1;
