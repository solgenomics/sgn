use strict;

package CXGN::Cookie;

use Apache2::RequestUtil;
use Apache2::Cookie;
use Data::Dumper;

our %COOKIES   = ();
our @EXPORT_OK = qw/
  get_cookie
  add_cookie
  bake_cookies
  set_cookie
  /;

=head1 CXGN::Cookie

 Functions for using CXGN cookies

=head1 Functions

=head2 get_cookie($name)

 Given a cookie name, gets the cookie value from Apache2::Cookie, which is the
 cookie received from the client. Returns undef if no cookie of this name exists

=cut

sub get_cookie {
    my ($cookie_name) = @_;
    my $jar = Apache2::Cookie::Jar->new( Apache2::RequestUtil->request() );
    if ( my $c = $jar->cookies($cookie_name) ) {
        return $c->value();
    }
    else {
        return;
    }
}

=head2 set_cookie($name,[$value])

 Sets a cookie for the SGN domain, which is properly resolved in this
 function.  Death occurs if a name is not provided.  

 The CXGN::Login module sets 'sgn_session_id' to a value of '' 
 as a method for logging out an sp_person.  Failure to provide a value
 will result in an empty string being used, effectively erasing the cookie

 The sgn domain is determined as follows:  If the last two domain components
 are 'cornell.edu', the cookie domain will be set to 'sgn.cornell.edu', allowing
 the sharing of the user session between subdomains

 Otherwise, it is assumed that the cookie is being set on a local apache, and
 so the domain is not messed with in any way.

 The path is set to '/', so the cookie operates site-wide from the html root
 directory.  

 After the cookie properties are set, bake() is called.  This is one of those
 critical mod_perl functions that somebody on that team gave a name for the
 sake of goofiness (kooky-ness?), without considering how damn confusing it
 is for developers.  They so funny.

 Apache2::Cookie::bake() adds 'Set-Cookie [your cookie]' to the page headers, 
 which means that this function must be called before the headers are sent 
 to the client.

=cut

sub set_cookie {
    my $cookie = make_cookie(@_);
    $cookie->bake( Apache2::RequestUtil->request() );
}

sub make_cookie {

    my ( $name, $value ) = @_;
    $name  ||= "";
    $value ||= ""
      ; #default is to erase cookie contents, which for our purposes logs the user out
    unless ( $name =~ /^[\w\-,\%\.]+$/ ) {
        die("Script trying to set cookie with invalid name: '$name'");
    }
    unless ( $value =~ /^[\w\-,=:\%\.]*$/ ) {
        die("Script trying to set cookie with invalid value: '$value'");
    }
    my $request = Apache2::RequestUtil->request();

    my $domain = $request->get_server_name;
#    $domain =~ s/^www\.//i; # ignore leading www in server name

    my $cookie = Apache2::Cookie->new( $request,
				       -name => $name,
				       -value => $value,
				       -domain => $domain,
				       -path => '/',
				     );

    return $cookie;
}

=head2 add_cookie() and bake_cookies()

 There is now a package hash called %CXGN::Cookie::COOKIES that
 holds cookie objects, keyed by the provided name

 This ensures that redundant cookies are not written to the header, 
 which could be confusing to the browser, which will probably take
 the final cookie by name, but who knows for sure?

 Ex:
 CXGN::Cookie::add_cookie('this', 'isacookie');
 CXGN::Cookie::add_cookie('that', 'isadifferentcookie');
 CXGN::Cookie::add_cookie('this', 'overrode the first cookie, instead of writing another header line');
 CXGN::Cookie::bake_cookies(); #writes 2 cookies to the response header

=cut

sub add_cookie {
    my ( $name, $value ) = @_;
    $COOKIES{$name} = make_cookie( $name, $value );
}

sub bake_cookies {
    $_->bake( Apache2::RequestUtil->request() ) foreach values %COOKIES;
}

####
1;    # do not remove
####
