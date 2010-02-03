use SOAP::Transport::HTTP;

use CXGN::MOBY::LocalServices;

my $s = SOAP::Transport::HTTP::CGI->new;
$s->dispatch_with({
		   map { 'http://biomoby.org/#'.$_  => 'CXGN::MOBY::LocalServices' } @CXGN::MOBY::LocalServices::servicenames
		  }
		 );
$s->handle();

# dispatcher::handle(); #script just calls the SOAP handler

# # this is a singleton sort of thing, hopefully shared.
# # Unless you are doing something really special, you shouldn't
# # have to touch this file at all.  Do all of your stuff in
# # CXGN::MOBY::LocalServices.pm
