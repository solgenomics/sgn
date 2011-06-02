use Modern::Perl;
use CatalystX::GlobalContext qw( $c );
use CGI qw();

my $term = $c->request->param('search') || 'loci';

print CGI->new->redirect(
    -status => 301,
    -uri => "/search/$term");

exit;

use CXGN::DB::Connection;
use CXGN::Genomic::Search::Clone;
use CXGN::Page::FormattingHelpers qw/page_title_html modesel/;
use CXGN::Page;
use CXGN::People;
use CXGN::Search::CannedForms;
use HTML::FormFu;
use YAML::Any qw/LoadFile/;


#get the search type
my ($search) = $page -> get_arguments("search");
$search ||= 'unigene'; #default
if ($search eq 'cvterm_name') { $search = 'qtl';}

my $tabsel =
    ($search =~ /loci/i)           ? 0
    : ($search =~ /phenotypes/i)   ? 1
    : ($search =~ /qtl/i)  ? 1
    : ($search =~ /trait/i)  ? 1
    : ($search =~ /unigene/i)      ? 2
    : ($search =~ /famil((y)|(ies))/i)       ? 3
    : ($search =~ /markers/i)      ? 4
    : ($search =~ /bacs/i)         ? 5
    : ($search =~ /est/i)          ? 6
    : ($search =~ /library/i)      ? 6
    : ($search =~ /images/i)       ? 7 # New image search
    : ($search =~ /directory/i)    ? 8
    : ($search =~ /template/i)     ? 9 ## There are 3 terms linking to search for expression
    : ($search =~ /experiment/i)   ? 9
    : ($search =~ /platform/i)     ? 9
    : $page->error_page("Invalid search type '$search'.");

$page->header('Search SGN','Search SGN');

print modesel(\@tabs,$tabsel); #print out the tabs

print qq|<div class="indentedcontent">\n|;
$tabfuncs[$tabsel](); #call the right function for filler
print qq|</div>\n|;

$page->footer();

