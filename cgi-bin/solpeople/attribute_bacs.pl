use strict;
use warnings;

use CXGN::Page;
use CXGN::DB::Connection;
use CXGN::Login;
use CXGN::Search::CannedForms;

my $dbh = CXGN::DB::Connection->new();
CXGN::Login->new($dbh)->verify_session();
my $page=CXGN::Page->new('Attribute BACs','john');
$page->header('Attribute BACs','How to attribute a BAC to a sequencing project');
print <<END_HTML;
<ol>
<li>Log in using the link at the top right of any SGN page.</li>
<li>From the toolbar, choose <b>search</b>-&gt;<b>BACs</b>, or just use the form below.</li>
<li>Type the name of the BAC you would like to attribute to your sequencing project into the search box.</li>
<li>Click the <b>search</b> button.</li>
<li>If you see the desired BAC in the search results, click its link.</li>
<li>On the BAC information page, there should be a link which will allow you to assign the BAC to your project. Note that you must be logged in for this link to be visible. Please be sure that you are making a correct attribution, because incorrect attributions can only be removed manually by the SGN staff.</li>
</ol>
END_HTML
print CXGN::Search::CannedForms::clone_search_form($page);
$page->footer();
