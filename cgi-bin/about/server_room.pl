#!/usr/bin/perl
use strict;
use CXGN::Page;
my $page = CXGN::Page->new;
$page->send_content_type_header();

print <<EOHTML;
<html>
  <head>
    <meta http-equiv="Refresh" content="120" />
  </head>
  <frameset rows="150,50,*">
      <frame name="temp" src="/about/temp.pl?deg=C&amp;mode=current" />
      <frame name="logged_in" src="/about/loggedin.pl" />
      <frame name="spong" src="http://rubisco.sgn.cornell.edu/spong-cgi/www-spong.cgi/bygroup/" />
  </frameset>
</html>
EOHTML
