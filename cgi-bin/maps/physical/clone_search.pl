use strict;
use warnings;

use English;
use CXGN::Page;
use CXGN::Search::CannedForms;
use CXGN::Genomic;
use CXGN::Genomic::Search::Clone;

use CXGN::Page::FormattingHelpers qw/blue_section_html page_title_html commify_number columnar_table_html/;
use CXGN::Tools::Text;
use CXGN::DB::Connection;

######## CONFIGURATION ##########
my $clonedatapage = '/maps/physical/clone_info.pl';
my $readinfopage = '/maps/physical/clone_read_info.pl';
my $default_rows_per_page = 15;

#################################

#################################
# Start a new SGN page.
our $page = CXGN::Page->new( 'Clone Search Results', 'Rob Buels');
$page->header('BAC Search Results'); #print out header immediately so users get 'in progress' message

my $search = CXGN::Genomic::Search::Clone->new;
my ($page_size) = $page->get_encoded_arguments('page_size');
$page_size ||= 16;
$search->page_size($page_size);
my $query = $search->new_query;
my %params = $page->get_all_encoded_arguments;
$query->from_request(\%params);
$query->order_by('clone_id' => 'ASC');
my $result = $search->do_search($query);

#build the HTML to output
print page_title_html('BAC Search Results');

print $result->to_html;

print blue_section_html('Search Again',CXGN::Search::CannedForms::clone_search_form($page,$query));

$page->footer();

