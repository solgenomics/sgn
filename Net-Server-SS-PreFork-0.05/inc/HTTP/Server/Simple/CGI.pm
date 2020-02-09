#line 1

package HTTP::Server::Simple::CGI;

use base qw(HTTP::Server::Simple HTTP::Server::Simple::CGI::Environment);
use strict;
use warnings;

use CGI ();

use vars qw($VERSION $default_doc);
$VERSION = $HTTP::Server::Simple::VERSION;

#line 29

sub accept_hook {
    my $self = shift;
    $self->setup_environment(@_);
}

#line 41

sub post_setup_hook {
    my $self = shift;
    $self->setup_server_url;
    CGI::initialize_globals();
}

#line 56

sub setup {
    my $self = shift;
    $self->setup_environment_from_metadata(@_);
}

#line 72

$default_doc = ( join "", <DATA> );

sub handle_request {
    my ( $self, $cgi ) = @_;

    print "HTTP/1.0 200 OK\r\n";    # probably OK by now
    print "Content-Type: text/html\r\nContent-Length: ", length($default_doc),
        "\r\n\r\n", $default_doc;
}

#line 88

sub handler {
    my $self = shift;
    my $cgi  = new CGI();
    eval { $self->handle_request($cgi) };
    if ($@) {
        my $error = $@;
        warn $error;
    }
}

1;

__DATA__
<html>
  <head>
    <title>Hello!</title>
  </head>
  <body>
    <h1>Congratulations!</h1>

    <p>You now have a functional HTTP::Server::Simple::CGI running.
      </p>

    <p><i>(If you're seeing this page, it means you haven't subclassed
      HTTP::Server::Simple::CGI, which you'll need to do to make it
      useful.)</i>
      </p>
  </body>
</html>
