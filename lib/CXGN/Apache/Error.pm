=head1 NAME

CXGN::Apache::Error

=head1 DESCRIPTION

CXGN::Apache::Error is a dark and spooky place where
scripts go before they kick the bit-bucket. Fortunately, they need not
remain here long before they are allowed to enter the great perly
logic gates in the sky.

When configured as the global die handler, CXGN::Apache::Error handles
errors in ALL mod_perl scripts on servers configured to use
CXGN::Apache::Registry to handle perl scripts (as opposed to plain
Apache::Registry).

A script may want to explicity use this module in case of an
ANTICIPATED error condition. For examples of this, see
CXGN::Page::error_page and /tools/does_not_exist.pl.

=head1 EXPORTS

nothing

=cut

=head1 BACKGROUND: ABOUT DIE HANDLERS

Every script on every Apache server which is configured to use
CXGN::Apache::Registry (as opposed to the default ModPerl::Registry)
implicitly uses this module--see CXGN::Apache::Registry.

A reasonable programmer would think at first blush that setting

    $main::SIG{__DIE__}= \&function_to_call_when_dying;

meant that all scripts that died were sent to
function_to_call_when_dying() for handling, and if
function_to_call_when_dying() didn't exit, the interpreter would just
keep on going as though nothing had happened. But actually,
$SIG{__DIE__} is just a function that you'd like to execute BEFORE
normal death actually happens, so you can do something like retrieve a
more meaningful error report (which is what we use it for). But unless
function_to_call_when_dying() does something really weird, the script
WILL finish dying (or throwing an exception, if inside an eval) as
soon as it is executed, whether you tell it to or not.

Yes, I just said, "Whether you Tell it to or not". This should bring
up the question, "Why would you TELL your script to die WITHIN
function_to_call_when_dying()? Wouldn't that just send the interpreter
back to function_to_call_when_dying() and cause an endless loop?"

The answer is actually no. That is handled for you behind the
scenes. In fact, the normal and best thing for
function_to_call_when_dying() to do is just say something like

    die(@_,'...But also give this error report.');

Saying "die" within the function called by $SIG{__DIE__} means "REALLY
die", not "come right back here and do this again."

-----

From http://www.perlmonks.org/?node=403

The routine indicated by $SIG{__DIE__} is called when a fatal
exception is about to be thrown. The error message is passed as the
first argument. When a __DIE__ hook routine returns, the exception
processing continues as it would have in the absence of the hook (that
is, it will actually finish dying, unless in an eval -- note inserted
by John Binns), unless the hook routine itself exits via a goto, a
loop exit, or a die(). The __DIE__ handler is explicitly disabled
during the call, so that you can die from a __DIE__ handler. Similarly
for __WARN__.

Note that the $SIG{__DIE__} hook is called even inside eval()ed
blocks/strings. See die and perlman:perlvar for how to circumvent
this. (It can't be circumvented in mod_perl, since mod_perl scripts
are ALWAYS inside an eval -- note inserted by John Binns).

Note that __DIE__/__WARN__ handlers are very special in one respect:
they may be called to report (probable) errors found by the parser. In
such a case the parser may be in inconsistent state, so any attempt to
evaluate Perl code from such a handler will probably result in a
segfault.

=cut


=head1 FUNCTIONS

=cut

package CXGN::Apache::Error;
use strict;

use Carp;
use Carp::Heavy;

use APR::Status ();
use Apache2::RequestUtil;


use ModPerl::Util;

use CXGN::Apache::Request;
use CXGN::Contact;
use CXGN::Page;
use CXGN::VHost;


=head2 cxgn_die_handler

  Usage:
  Desc : website $SIG{__DIE__} handler that 
  Args : list of strings to die with.  usually just 1.
  Ret  :
  Side Effects:
  Example:

=cut


#this will allow us to retrieve a meaningful carp error report. why isn't this in CXGN::Apache::Registry? 
#because outside the main mod_perl eval, the Carp::longmess_heavy error report appears to be useless.
sub cxgn_die_handler {

  # if we are inside a non ModPerl::Registry eval, or if we are trapping 404 or 403 errors,
  # then just forward the die on without messing with it
  # THIS IS IMPORTANT
  die @_ if $_[0] =~ /^\d+$/ && (     APR::Status::is_EACCES($_[0])
				  ||  APR::Status::is_ENOENT($_[0])
				)
            || _longmess() =~ /eval [\{\']/m;


  set_error_html_response_with_backtrace(@_);

  #now die for real, with the backtrace appended to the message
  die(@_);
};


=head2 cxgn_warn_handler

  Usage:
  Desc :
  Args :
  Ret  :
  Side Effects:
  Example:

=cut

sub cxgn_warn_handler {
    my ( $warning ) = @_;

    #say which script is doing the warning
    my ($script_name)=CXGN::Apache::Request::full_page_name();
    warn("[$script_name] ",@_);
};


=head2 compile_error_notify

  Usage:
  Desc :
  Args :
  Ret  :
  Side Effects:
  Example:

=cut

sub compile_error_notify {
    my (@msg) = @_;
    my $msg = join ' ',@msg;
    require CXGN::VHost;
    if( CXGN::VHost->new->get_conf('production_server') ) {
	my ( $subject, $body, $time_of_error ) =
	    CXGN::Apache::Error::notify( 'COMPILE ERROR: ', $@ );
    } else {
	my $comp_error = <<EOHTML;
<html>
<body>
<h2>Compilation Error</h2>
<pre>
$@
</pre>
</body>
</html>
EOHTML
	Apache2::RequestUtil->request->custom_response(500,$comp_error);
    }
}

=head2 set_error_html_response

  Usage:
  Desc :
  Args :
  Ret  :
  Side Effects:
  Example:

=cut

sub set_error_html_response {
    my (@msg) = @_;

    my $msg = join ' ',@msg;

    #warn "setting error html response ($msg)";

    # code below adapted from CGI::Carp::fatalsToBrowser
#     require Apache2::RequestRec;
#     require Apache2::RequestIO;
#     require Apache2::RequestUtil;
#     require APR::Pool;
#     require ModPerl::Util;
#     require Apache2::Response;
    my $r = Apache2::RequestUtil->request
	or die "could not get request??";

    #warn "got request, continuing";

    # If bytes have already been sent, then
    # we print the message out directly.
    # Otherwise we make a custom error
    # handler to produce the doc for us.
    if ($r->bytes_sent) {
	#warn "just printed error message\n";
	$r->print($msg);
	ModPerl::Util::exit(0);
    } else {

	#warn "printing full error page";
	my $client_message_header = '';
	my $client_message_body   = '';
	my $error_verb            = "died";

	#warn "requiring page";
	require CXGN::Page;
	#warn "making page";
	my $page                  = CXGN::Page->new();

	#warn "generating error html";
	my $html_error_page =
	    $page->error_page_html(
		$client_message_header, $client_message_body,
		$error_verb,            $msg
	    );
	#warn "generated error page";

	# MSIE won't display a custom 500 response unless it is >512 bytes!
	if ($ENV{HTTP_USER_AGENT} =~ /MSIE/) {
	    $html_error_page = "<!-- " . (' ' x 513) . " -->\n$html_error_page";
	}

	$r->custom_response(500,$html_error_page);

	#warn "printed full error page\n";
	#warn $html_error_page;
	#ModPerl::Util::exit(0);
    }
}

=head2 set_error_html_response_with_backtrace

  Usage:
  Desc :
  Args :
  Ret  :
  Side Effects:
  Example:

=cut

sub set_error_html_response_with_backtrace {
    my (@msg) = @_;
    my $msg = join ' ',@msg;

    #warn "setting backtrace response";

    my $backtrace = _format_backtrace();
    $backtrace = substr($backtrace,0,1000);

    return set_error_html_response("$msg\n$backtrace");
}

=head2 notify

  Usage: CXGN::Apache::Error::notify( 'died', 'omglol it died so hard' );

  Desc : If CXGN is configured as a production_server, Sends an email
         to the development team with an error message, backtrace, and
         request data, but does not terminate program. This can be
         called by any script that needs it.  uses
         CXGN::Contact::send_email to send th
  Args : error verb (e.g. 'died'), message to send to website developers
  Ret  : list of ( email subject, email body, timestamp string)
  Side Effects: sends email to development team
  Example:
        my $error_verb='made a little mistake';
        my $developer_message='My program made a little mistake. See backtrace and request data below.';
	CXGN::Apache::Error::notify($error_verb,$developer_message);

=cut

sub notify {

    my ( $error_verb, $developer_message ) = @_;

    $error_verb ||=
      'died or errorpaged (cause of death not indicated by caller)';

    $developer_message ||=
'CXGN::Apache::Error::notify called. The error may or may not have been anticipated (no information provided by caller).';

    my $time_of_error = CXGN::Apache::Request::time();

    my ( $page_name, $parameters ) = CXGN::Apache::Request::page_name();

    my ( $client_name, $subject_client_name ) =
      CXGN::Apache::Request::client_name();

    $subject_client_name &&= "$subject_client_name found ";

    my $vhost_name = CXGN::VHost->new()->get_conf('project_name') || 'UNKNOWN';

    $vhost_name = $vhost_name eq 'SGN' ? ''
                :                        "on $vhost_name ";

    my $subject =
      "$subject_client_name$vhost_name$page_name $error_verb $time_of_error";

    my $body = $developer_message;

    CXGN::Contact::send_email( $subject, $body, 'bugs_email' );

    return ( $subject, $body, $time_of_error );
}



######### HELPER FUNCTIONS ############



# The mod_perl package Apache::Registry loads CGI programs by calling
# eval.  These evals don't count when looking at the stack backtrace.
sub _longmess {
    my $message = Carp::longmess();
    #warn "processing with longmess:\n$message\n";
    $message =~ s,eval[^\n]+(ModPerl|Apache)/(?:Registry|Dispatch)\w*\.pm.*,,s
        if exists $ENV{MOD_PERL};
    #warn "and after longmess:\n$message\n";
    return $message;
}

#get a backtrace and reformat it to make it nicer
sub _format_backtrace {

  my $longmess = _longmess();
  $longmess =~ s/[\s\n]+$//;

  # cut off the lines of the backtrace concerning the die handler and
  # put some numbers in the backtrace, which make it a little nicer to
  # read
  my @lm_lines = split /\n/,$longmess;
  shift @lm_lines while $lm_lines[0] !~ /cxgn_die_handler/;

  my $frame = 0;
  foreach my $l (@lm_lines) {
      my $pkg = __PACKAGE__;
      $l =~ s/^.+(ModPerl|Apache)::Registry::[^:]+:://; #< remove irrelevant Registry stuff from the rest of the frames
      $l = '<'.$frame++.'> '.$l;
  }
  $longmess = join "\n",@lm_lines;


  return "Perl stack backtrace\n--------------------\n".$longmess;
}

###
1;#do not remove
###



