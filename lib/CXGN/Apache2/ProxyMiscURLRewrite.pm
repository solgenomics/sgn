package CXGN::Apache2::ProxyMiscURLRewrite;

use strict;
use warnings FATAL => 'all';
use Apache2::Filter ();
use APR::Table ();
use Apache2::Const -compile => qw(OK OR_ALL TAKE2);
use constant BUFF_LEN => 1024;
use Apache2::CmdParms ();
use Apache2::Module ();

# There is perldoc at the end of this file.

my ($to, $from); # FIXME to not use globals

my @directives = (
		  {
		   name         => 'ProxyMiscURLMap',
		   func         => __PACKAGE__ . '::ProxyMiscURLMap',
		   req_override => Apache2::Const::OR_ALL,
		   args_how     => Apache2::Const::TAKE2,
		   errmsg       => 'ProxyMiscURLMap http://otherserver /dir',
		  },
		 );
Apache2::Module::add(__PACKAGE__, \@directives);

sub ProxyMiscURLMap {
  my ($self, $parms, @args) = @_;

  ($from, $to) = @args;

}


sub handler {
  my $f = shift;

                                    
  # unset Content-Length but only on the first bucket per response.
  unless ($f->ctx) {
    $f->r->headers_out->unset('Content-Length');
    $f->ctx(1);
  }

  
  while ($f->read(my $buffer, BUFF_LEN)) {
    
    $to =~ s|^/||;
    
    $buffer =~ s!url\((['"]?)($from|/)!url(${1}${2}$to/!g;
    $buffer =~ s!var\s+docroot\s*=\s*'($from|/)'!var docroot='${1}$to/'!g;
    
    
    $f->print($buffer);
    
  }
  return Apache2::Const::OK;
  
}


###
1;#
###


=head1 NAME

  CXGN::Apache2::ProxyMiscURLRewrite

=head1 SYNOPSIS

This synopsis shows a complete example using mod_proxy,
mod_proxy_html, and CXGN::Apache2::ProxyMiscURLRewrite.

This is not Perl; put this in your apache configuration.

  ProxyRequests Off
  ProxyPass /beth http://siren.sgn.cornell.edu:9002
  ProxyPassReverse /beth http://siren.sgn.cornell.edu:9002

  SetOutputFilter proxy-html
  AddOutputFilter proxy-html .htm .html .pl 
  ProxyHTMLURLMap http://siren.sgn.cornell.edu:9002 /beth

  PerlLoadModule CXGN::Apache2::ProxyMiscURLRewrite

  <Location /beth>
          ProxyHTMLURLMap /(.*) /beth/$1 LR
          PerlOutputFilterHandler CXGN::Apache2::ProxyMiscURLRewrite
          ProxyMiscURLMap http://siren.sgn.cornell.edu:9002 /beth
  </Location>



=head1 DESCRIPTION

This is an output filter for Apache2. It will NOT work with apache 1.3. 
You do not have to write a perl program to use this module, but you 
do need to futz with your apache configuration. See the L<synopsis> for
a somewhat complete example.

To use this module as shown, you will need:

* Apache version 2
* Mod_perl version 2, at least 2.0.2. The version of mod_perl in Debian Sarge is NOT acceptable, since it is version 1.99. 
* mod_proxy (comes with apache2)
* mod_proxy_html (see apache.webthing.org)

This is designed to work in a REVERSE proxy. 

=head2 Directives

=over 12

=item C<ProxyMiscURLMap>

Takes two arguments, the remote site and the local directory. 

  ProxyMiscURLMap http://siren.sgn.cornell.edu:9002 /beth

When you go to http://localhost/beth in your browser, you will 
see the contents of http://siren.sgn.cornell.edu:9002 . 

=item C<as_string>

Returns a stringified representation of
the object. This is mainly for debugging
purposes.

=back

=head1 LICENSE

This is released under the Artistic 
License. See L<perlartistic>.

=head1 AUTHOR

Juerd - L<http://juerd.nl/>

=head1 SEE ALSO

L<perlpod>, L<perlpodspec>

=cut









