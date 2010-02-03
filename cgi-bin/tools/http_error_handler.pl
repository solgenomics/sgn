use strict;
use CXGN::Page;
use CXGN::Apache::Request;
use CXGN::Apache::Error;
my $refer = $ENV{'HTTP_REFERER'};
$refer ||= 'the referring site';
my $request = $ENV{'REQUEST_URI'};
$request ||= '(page request not found)';
my $agent = $ENV{'HTTP_USER_AGENT'};
my ($page_name) = CXGN::Apache::Request::page_name($request);

# Does this page only handle 404s, despite its more general filename (http_error_handler.pl)?
# Some assumptions made herein might be invalid if that's not the case.
our $page                = CXGN::Page->new( "404 - File not found", "john" );
our $client_message      = "$page_name does not exist on this server.";
our $client_message_body = '';
our $client_instructions =
  "You may wish to contact the referring site and inform them of this error.\n";

#these pages got old and died
if (   $page_name eq "tm_list.pl"
    or $page_name eq "caps_list.pl"
    or $page_name eq 'listMarkerOccurances.pl'
    or $page_name eq 'list_ssr_markers.pl'
    or $page_name eq 'cos_marker_search_result.pl'
    or $page_name eq 'marker_search_result.pl' )
{
    $page->message_page( $client_message,
"This page has been replaced by a new marker information page. Please use our <a href=\"/search/direct_search.pl?search=markers\">new marker search</a> to retrieve marker information."
    );
}

#removed some old cosii scripts
if (   $page_name =~ /marker_sequence\.pl/i
    or $page_name =~ /view_alignment\.pl/i
    or $page_name =~ /view_tree\.pl/i )
{
    $page->message_page( $client_message,
"This page is being replaced with new COSII marker information pages. All previously available data, and more, is still available. Please use our <a href=\"/search/direct_search.pl?search=markers\">marker search</a> to retrieve COSII marker information. On most COSII marker pages, there is now an extensive list of all available marker sequence data."
    );
}

#some spam spiders try to submit spam to sites by forging referers and submitting requests to standard "contact us" pages. we don't use these pages, so these requests show up as 404s refered by sgn.
elsif ($request =~ m|formmail|i
    or $request =~ m|/form.pl|i
    or $request =~ m|/mail.pl|i
    or $request =~ m|ezforml|i
    or $request =~ m|/library/comments/comments.pl|i
    or $request =~ m|fmail.pl|i
    or $request =~ m|cgiemail|i
    or $request =~ m|mailform.pl|i
    or $request =~ m|\.cgi|i
    or $request =~ m|nether-mail|i
    or $request =~ m|/feedback|i
    or $request =~ m|/contact|i )
{
    &no_action_just_message;
}

# Some spiders request a bogus page with the exact same URL as the referer. This isn't really possible.
#my $qrequest = quotemeta($request);
elsif ( $refer =~ m|http://[^/+]\Q$request\E| ) {
    no_action_just_message();
}

#no one knows the cause of these, but some dutch web client or bot is submitting malformed requests
elsif ( $request =~ /bestanden/ ) {
    &no_action_just_message;
}

#probably someone trying to spam us and forging referer is doing this, because we moved this page ages ago and still get the old location as a referer
elsif ( $request =~ /solpeople\/add_post/ ) {
    &no_action_just_message;
}

#not sure why we're getting a gazillion gbrowse 404s yet...
elsif ( $agent =~ /HTTrack/ ) {
    &no_action_just_message;
}

#add elsifs here for your removed pages. you can just check $page_name if it's an unusual name. use $request and a pattern match if it's something like "index.html".

#if none of the above cases are true, we have a real 404. if we care about the referer, then send an email.
elsif (
    defined($refer)
    && (   ( $refer =~ /http:\/\/(www\.)?sgn.cornell\.edu/ )
        || ( $refer =~ /http:\/\/(www\.)?google\.com/ ) )
  )
{
    my $error_verb        = "not found - 404";
    my $developer_message = <<END_HEREDOC;
404 - File not found:
$request 
referred by $refer

END_HEREDOC
    $page->error_page(
        $client_message, $client_message_body,
        $error_verb,     $developer_message
    );
}
else {
    &no_action_just_message;
}

sub no_action_just_message {
    $page->message_page( $client_message, $client_instructions );
}
