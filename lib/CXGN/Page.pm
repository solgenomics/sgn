package CXGN::Page;

=head1 NAME

CXGN::Page

=head1 DESCRIPTION

This entire module is deprecated.  Do not use in new code.

Page object which handles headers, footers, simple message pages, and
simple error pages. Can also retrieve page arguments and handle
redirects.  This is now a subclass of CXGN::Scrap, which handles all
of the argument-retrieval.

=cut

use base qw/ CXGN::Scrap /;
use strict;
use warnings;
use HTML::Entities qw/encode_entities/;
use URI::Escape;
use Carp;
use CGI qw/ -compile :html4/;
use CXGN::Page::FormattingHelpers qw(blue_section_html newlines_to_brs);
use CXGN::Apache::Error;
use CXGN::DB::Connection;
use CXGN::Login;
use CXGN::Page::VHost::SGN;
use CXGN::Tools::File;


use Data::Dumper;
$Data::Dumper::Varname = 'VAR_DUMP';

use CatalystX::GlobalContext '$c';

## STDERR Capture for the Logger, by Developer Preference ####
our $STDERR_BUFFER  = '';
our $STDERR_CAPTURE = 0;

=head1 OBJECT METHODS

=head2 new

Creates a new page object. This will try to be smart and give you the correct type of header for your virtual host, based on the apache request.  All arguments are optional, but they are ordered.

	#Example
	my $page=CXGN::Page->new( $page_name, $author,
		{jslib => ['CXGN.MyModule','MochiKit.Logging', 'Prototype', 'Scriptaculous.DragDrop']});

The jslib in the final optional hashref is equivalent to using jsan_use() on the page.

=cut

sub new {
    my $class = shift;

    my $self = $class->SUPER::new();

    $self->{mk_log_messages} = [];
    my ( $name, $author, $other ) = @_;
    if ( $other and my $js = $other->{jslib} ) {
        my @libs = ref $js ? @$js : ($js);
        $self->jsan_use(@libs);
    }
    $self->{context} = $c;
    $self->{project_name} = 'SGN';

    $self->{page_object} = CXGN::Page::VHost::SGN->new($self->get_dbh());
    $self->{page_object}->{page} = $self;

    $name   ||= '';
    $author ||= '';
    $self->{name}         = $name;
    $self->{author}       = $author;
    $self->{embedded_css} = "";

    return $self;
}

=head2 add_style

   Add CSS to the page. Should be called before header() so the style can be output in the <HEAD>.
   (XHTML 1.0 requires that embedded stylesheets be in the <HEAD>.)

   #Example
	$page->add_style(text => "some css text", file => "stylesheet.css");
	

=cut

sub add_style {
    my ( $self, %params ) = @_;
    if ( exists $params{text} ) {
        $self->{embedded_css} .=
          "<style type=\"text/css\">\n$params{text}\n</style>\n";
    }
    if ( exists $params{file} ) {
        $self->{embedded_css} .=
"<link rel=\"stylesheet\" type=\"text/css\" href=\"$params{file}\" />\n";
    }
}

sub get_header {
    my $self           = shift;

    return $self->{context}->render_mason(
	'/site/header.mas',
	page_title => $self->{page_title},
	extra_headers => $self->jsan_render_includes
	                 . ( $self->{embedded_css}     || '' )
                         . ( $self->{extra_head_stuff} || '' ),
       );
}

sub get_footer {
    my $self = shift;
    return $self->{context}->render_mason('/site/footer.mas');
}

sub simple_footer { 
    my $self=shift;
 #
    carp "simple_footer() deprecated, please replace this with mason code";

    print <<END_HEREDOC;
</td></tr>
<tr><td><hr></td></tr>
<tr><td id= "pagecontent_footer"><font color="gray" size="1">Copyright &copy; <a href="http://sgn.cornell.edu/" class="footer" >Sol Genomics Network</a> and <a class="footer" href="http://bti.cornell.edu/">the Boyce Thompson Institute</a>.<br />Development of this software was supported by the <a class="footer" href="http://www.nsf.gov/">U.S. National Science Foundation</a>.</td></tr>
</table>
</div>
</body>
</html>
END_HEREDOC

}

=head2 header_html

returns standard header html string. $page_title is optional. Without it, the $page_name sent in with CXGN::Page->new() will be used. $content_title is optional. If you include it, you will get a standard "<h3>Page title</h3>" under our standard header.

	#Example
	print $page->header_html($page_title,$content_title);

=cut

sub header_html {
    my $self = shift;
    ( $self->{page_title}, $self->{content_title}, $self->{extra_head_stuff} ) =
      @_;
    unless ( $self->{page_title} ) {
        $self->{page_title} = $self->{name};
    }
    my $html = $self->get_header();
    if ( $self->{content_title} ) {
        $html .= CXGN::Page::FormattingHelpers::page_title_html(
            $self->{content_title} );
    }
    return $html;
}


=head2 header

Prints $self->header_html(@_), along with a text/html content-type header.

=cut

sub header
{
    my $self=shift;
    $self->send_content_type_header();
    print $self->header_html(@_);
}

=head2 function simple_header()

  Args: An optional header string
  Desc: Print an SGN simple header without the toolbars 
  Ret:  Nothing
  Side Effects: prints a header to STDOUT

=cut

sub simple_header {
    my $self          = shift;
    my $header_string = shift;
    my $head          = $self->{page_object}->html_head( $header_string,
                                                         $self->jsan_render_includes
                                                         . ( $self->{embedded_css} || '' )
                                                         . ( $self->{extra_head_stuff} || '' ),
                                                       );
    $self->send_content_type_header();
    print "\n"; #< just in case we printed some plain headers
    print <<END_HTML;
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html>
$head

<body>
<div id="outercontainer">
  <a name="top"></a>

  <table summary="" width="800" cellpadding="0" cellspacing="0" border="0">
  <tr>
  <td width="35"><a href="/"><img src="/documents/img/sgn_logo_icon.png" border="0" width="30" height="30" /></a></td>
  <td style="color: gray; font-size:12px; font-weight: bold; vertical-align: middle">$header_string</td></tr>
  </table>
  <table summary="" width="800" cellpadding="0" cellspacing="0" border="0">
  <tr><td>
  <hr />
END_HTML

    carp "simple_header() deprecated, please replace this with mason code";
}

=head2 footer

Prints a standard footer.

	#Example
	$page->footer();

=cut

sub footer {
    my $self = shift;
    print $self->get_footer();
}

=head2 client_redirect

Sends client to another location.

	#Example
	$page->client_redirect("http://sgn.cornell.edu");

=cut

sub client_redirect {
    my ( $self, $url ) = @_;
    print CGI->new->redirect( -uri => $url, -status => 302 );
    exit;
}


=head2 message_page

deprecated. do not use in new code.

=cut

sub message_page {
    my ( $self, $message_header, $message_body ) = @_;

    unless( defined $message_body ) {
        $message_body = $message_header;
        $message_header = undef;
    }

    $c->throw( title    => $message_header,
               message  => $message_body,
               is_error => 0,
              );

}

=head2 error_page

deprecated, do not use in new code.

=cut

sub error_page {
    my $self = shift;
    my ( $message_header, $message_body, $error_verb, $developer_message ) = @_;

    unless( length $message_body ) {
        $message_body = $message_header;
        $message_header = undef;
    }

    $c->throw( message => $message_body,
               developer_message => $developer_message,
               title => $message_header,
              );
}

=head1 OTHER METHODS

All other methods are either deprecated or for internal use only.

=head2 comments_html

UNDOCUMENTED, PLEASE FIX

=cut

sub comments_html {

    my ( $self, $thingtype, $thingid, $passed_referer ) = @_;

    # thingtype would be something like "marker" or "bac"
    # thingid would be the marker_id or the clone_id

    my $placeholder = blue_section_html(
        "User Comments",
        qq{<!-- check for comments only shows up when AJAX is not enabled
     (old browsers, buggy ajax) -->
Please wait, checking for comments.  (If comments do not show up, access them <a href="/forum/return_comments.pl?type=$thingtype&amp;id=$thingid">here</a>)}
    );

    my $referer = $self->URLEncode($passed_referer);

    my $html = <<EOHTML;
<span class="noshow" id="referer">$referer</span>
<span class="noshow" id="commentstype">$thingtype</span>
<span class="noshow" id="commentsid">$thingid</span>
<div id="commentsarea">
$placeholder
</div>

EOHTML

}

#######################################
## DEPRECATED DO NOT USE ##############
#######################################

# # Utility function for generating random filenames for tempfiles. When
# # used this way we depend on low probability of collision rather than
# # guarantees of unique filenames; ALSO, we usually don't actually want
# # a unique filename most of the time, but a deterministic one (eg,
# # marker1234.png)

# #
# # Note: Do not use this. Use File::Temp instead.
# #
# # a way of coming up with temporary file names
use IO::File;
our $dev_urandom = new IO::File "</dev/urandom"
  or print STDERR "Can't open /dev/urandom for an entropy source.";

sub tempname {
    my $rand_string = "";
    $dev_urandom->read( $rand_string, 16 );
    my @bytes = unpack( "C16", $rand_string );
    $rand_string = "";
    foreach (@bytes) {
        $_ %= 62;
        if ( $_ < 26 ) {
            $rand_string .= chr( 65 + $_ );
        }
        elsif ( $_ < 52 ) {
            $rand_string .= chr( 97 + ( $_ - 26 ) );
        }
        else {
            $rand_string .= chr( 48 + ( $_ - 52 ) );
        }
    }
    return $rand_string;
}

sub URLEncode {
    my $self   = shift;
    my $theURL = $_[0];
    $theURL =~ s/([\W])/"%" . uc(sprintf("%2.2x",ord($1)))/eg;
    return $theURL;
}

=head2 log

 Usage: $page->log("MochiKit Log Message", "debug");
          or
		$page->log($object_ref, 2);
 Desc: Will append a log message to the MochiKit logger.
 Args: message, type (optional). 
       Type can be: debug, error, fatal, or warning
	      or 
	   obj/hash/array-ref, levels_of_recursion (optional integer)
	     Does a Data::Dumper on your ref, to the logger.

=cut

sub log {
    my $self    = shift;
    my $message = shift;
    my $type    = shift;
    if ( !defined($message) ) {
        my $mes = "Log message undefined.";
        if ( $type =~ /^\d+$/ )
        {   #Very likely that a bad reference was passed, if recursion level set
            $mes = "Undefined. Passed reference was probably never created.\n";
        }
        $self->log( $mes, "error" );
    }

    if ( ref($message) ) {
        $type = 0 unless ( $type =~ /^\d+$/ );
        $Data::Dumper::Maxdepth = $type;
        my $dump = Dumper($message);
        $Data::Dumper::Maxdepth = 0;
        my $extra = "";
        if ( $type > 0 ) {
            $extra .= " - Depth: $type";
        }
        $message = ref($message) . "$extra\n" . $dump;
        $type    = "";
    }

    $type ||= "";
    $type = "" if ( lc($type) eq "info" );
    my @valid = qw| error debug fatal warning |;
    my %valid = ();
    $valid{$_} = 1 foreach @valid;
    unless ( !$type || $valid{ lc($type) } ) {
        $self->log(
"Invalid type '$type' provided to \$page->log() in perl script, using 'ERROR' instead (next message)",
            "Fatal"
        );
        $type = "ERROR";
    }

    push( @{ $self->{mk_log_messages} }, $message, $type );

    #print STDERR "LOG " . uc($type) . ": $message\n";
}

sub log_error {
    my ( $self, $mesg ) = @_;
    $self->log( $mesg, "error" );
}

sub log_fatal {
    my ( $self, $mesg ) = @_;
    $self->log( $mesg, "fatal" );
}

sub log_debug {
    my ( $self, $mesg ) = @_;
    $self->log( $mesg, "debug" );
}

sub mk_render_log_insert {
    my $self    = shift;
    my $content = "";
    my @m       = @{ $self->{mk_log_messages} };
    while (@m) {
        my $message = shift(@m);
        $message =~ s/\\/\\\\/g;
        $message =~ s/"/\\"/g;
        $message =~ s/\n/\\n/g;
        my $type = shift(@m);
        $type = ucfirst( lc($type) );
        $content .= "MochiKit.Logging.log$type(\"$message\");\n";
    }
    return
"<!--MochiKit Log Insertion-->\n<script type=\"text/javascript\">\n$content\n</script>\n";
}

sub mk_write_log {
    my $self    = shift;
    my $content = $self->mk_render_log_insert();
    $self->{mk_log_messages} = [];    #clear the log
    return $content;
}

sub login {
    die "CXGN::Page login: This function is deprecated.";
     my $self = shift;
     my $cxgn_login = CXGN::Login->new( { NO_REDIRECT => 1 } );
     return if $cxgn_login->has_session();
     my ( $uname, $pass ) =
       $self->get_arguments( 'CXGN_LOGIN_USERNAME', 'CXGN_LOGIN_PASSWORD' );
    my $info = $cxgn_login->login_user( $uname, $pass );
    return $info;
}

sub logout {
    die "CXGN::Page::logout: This function is deprecated.";
    my $cxgn_login = CXGN::Login->new( { NO_REDIRECT => 1 } );
    $cxgn_login->logout_user();
}

sub login_form {
    return <<HTML
	<form name="CXGN_LOGIN" method="POST" style="margin:0px;padding0px">
	<table>
	<td>
	Username:</td><td><input type="text" id="CXGN_LOGIN_USERNAME" name="CXGN_LOGIN_USERNAME" /></td></tr>
	<tr><td>
	Password:</td><td><input type="password" id="CXGN_LOGIN_PASSWORD" name="CXGN_LOGIN_PASSWORD" /></td></tr>
	<tr><td>
	<input type="submit" value="Login" />
	</td>
	<td>
	</td>
	</tr>
	</table>
	</form>
HTML
}

=head2 accessors get_dbh(), set_dbh()

 Usage:
 Desc:
 Property
 Side Effects:
 Example:

=cut

sub get_dbh {
    $c->dbc->dbh
}

sub set_dbh {
    confess "don't set me.";
}


=head1 AUTHOR

john binns - John Binns <zombieite@gmail.com>
Robert Buels - rmb32@cornell.edu
Chris Carpita - csc32@cornell.edu (logging, developer toolbar)

=cut

####
1;    # do not remove
####
