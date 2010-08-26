use CatalystX::GlobalContext qw( $c );
# this script is called like /bare_mason.pl/path/to/mason.mas, and
# simply executes the mason component with no parameters and returns
# the bare text.

# example usage: provide the site header and footer html as a web service

use strict;
use warnings;
use CGI ();

my $cgi = CGI->new;
if( my $component_name = $cgi->path_info ) {
    print "\n\n";
    print $c->render_mason( $component_name, bare_render => 1 );
}
