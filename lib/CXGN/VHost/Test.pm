package CXGN::VHost::Test;
use strict;
use warnings;

use Catalyst::Test 'SGN';
use base qw/Exporter/;
our @EXPORT = qw/ request get /;

1;

__END__

=head1 NAME

CXGN::VHost::Test - deprecated, do not use in new code

=cut

# =head1 SYNOPSIS

#     # to run tests
#     SGN_TEST_SERVER='http://sgn.localhost.localdomain/' prove -r -l lib/ t/

#     # Tests
#     use CXGN::VHost::Test;
#     request('index.html');
#     get('index.html');


# =head1 DESCRIPTION

# Test CXGN web applications.  This is basically a copy of
# Catalyst::Test, tweaked to work with current CXGN web applications, if
# you use this module your test script should be completely
# Catalyst-ready.

# =head2 METHODS

# =head2 get

# Returns the content.

#     my $content = get('foo/bar?test=1');

# Note that this method doesn't follow redirects, so to test for a
# correctly redirecting page you'll need to use a combination of this
# method and the L<request> method below:

#     my $res = request('/'); # redirects to /y
#     warn $res->header('location');
#     use URI;
#     my $uri = URI->new($res->header('location'));
#     is ( $uri->path , '/y');
#     my $content = get($uri->path);

# =head2 request

# Returns a C<HTTP::Response> object.

#     my $res = request('foo/bar?test=1');

# =cut

