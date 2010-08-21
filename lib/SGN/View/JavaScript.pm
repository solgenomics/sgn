package SGN::View::JavaScript;

use strict;
use warnings;

use parent 'Catalyst::View::JavaScript::Minifier::XS';

use File::Spec;

__PACKAGE__->config(

    INCLUDE_PATH => SGN->path_to(),
    path         => File::Spec->catdir(qw( js )),

   );

1;
