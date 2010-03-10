package CXGN::VHost::Test;
use strict;
use warnings;
use English;
use Carp;

use URI;

use Catalyst::Utils;

use CXGN::DB::Connection;

=head1 NAME

CXGN::VHost::Test - Test CXGN web applications.

=head1 SYNOPSIS

    # to run tests
    SGN_TEST_SERVER='http://sgn.localhost.localdomain/' prove -r -l lib/ t/

    # Tests
    use CXGN::VHost::Test;
    request('index.html');
    get('index.html');


=head1 DESCRIPTION

Test CXGN web applications.  This is basically a copy of
Catalyst::Test, tweaked to work with current CXGN web applications, if
you use this module your test script should be completely
Catalyst-ready.

=head2 METHODS

=head2 get

Returns the content.

    my $content = get('foo/bar?test=1');

Note that this method doesn't follow redirects, so to test for a
correctly redirecting page you'll need to use a combination of this
method and the L<request> method below:

    my $res = request('/'); # redirects to /y
    warn $res->header('location');
    use URI;
    my $uri = URI->new($res->header('location'));
    is ( $uri->path , '/y');
    my $content = get($uri->path);

=head2 request

Returns a C<HTTP::Response> object.

    my $res = request('foo/bar?test=1');

=cut


use base qw/Exporter/;
our @EXPORT = qw/ request get /;

#< copied from Catalyst::Test


sub get {
  request(@_)->content;
}

my $agent;
sub request {

    unless( $ENV{SGN_TEST_SERVER} ) {
        croak "the SGN_TEST_SERVER environment variable must be set to use ".__PACKAGE__;
    }

    die "SGN_TEST_SERVER env var must begin with http://\n"
        unless $ENV{SGN_TEST_SERVER} =~ m!^http://!;

    ## Added an enviromental variable SGN_SERVER_TIMEOUT. In some machines load some pages
    ## needs more than 60 s, so if it is better if it can be changed

    my $timeout = $ENV{SGN_SERVER_TIMEOUT} || 60;

    require LWP::UserAgent;

    my $request = Catalyst::Utils::request( shift(@_) );
    my $server  = URI->new( $ENV{SGN_TEST_SERVER} );

    if ( $server->path =~ m|^(.+)?/$| ) {
        my $path = $1;
        $server->path("$path") if $path;    # need to be quoted
    }

    # the request path needs to be sanitised if $server is using a
    # non-root path due to potential overlap between request path and
    # response path.
    if ($server->path) {
        # If request path is '/', we have to add a trailing slash to the
        # final request URI
        my $add_trailing = $request->uri->path eq '/';

        my @sp = split '/', $server->path;
        my @rp = split '/', $request->uri->path;
        shift @sp;shift @rp; # leading /
        if (@rp) {
            foreach my $sp (@sp) {
                $sp eq $rp[0] ? shift @rp : last
            }
        }
        $request->uri->path(join '/', @rp);

	

        if ( $add_trailing ) {
            $request->uri->path( $request->uri->path . '/' );
        }
    }

    $request->uri->scheme( $server->scheme );
    $request->uri->host( $server->host );
    $request->uri->port( $server->port );
    $request->uri->path( $server->path . $request->uri->path );

    unless ($agent) {

        $agent = LWP::UserAgent->new(
            keep_alive   => 1,
            max_redirect => 0,
            timeout      => $timeout,
        );

        $agent->env_proxy;
    }

    return $agent->request($request);
}


=head1 SUBCLASSES

none yet

=head1 METHODS

=head1 MAINTAINER

Robert Buels

=head1 AUTHOR(S)

Robert Buels, E<lt>rmb32@cornell.eduE<gt>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

###
1;#do not remove
###
