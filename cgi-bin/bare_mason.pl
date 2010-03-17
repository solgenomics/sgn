# this script is called like /bare_mason.pl/path/to/mason.mas, and
# simply executes the mason component with no parameters and returns
# the bare text.

# example usage: provide the site header and footer html as a web service

use strict;
use warnings;
use CGI ();

if( my $component_name = CGI->new->path_info ) {
    print $c->render_mason( $component_name );
}
