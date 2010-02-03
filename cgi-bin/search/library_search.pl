######################################################################
#
#  Search the library database and display the results.
#
#  Adapted to the search framework by Evan Herbst, 1 / 14 / 07
#
######################################################################

use strict;

use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/blue_section_html info_section_html page_title_html columnar_table_html/;
use CXGN::Search::CannedForms;
use CXGN::Searches::Library;

my $page=CXGN::Page->new("EST library search results", "Evan");
$page->header();

print page_title_html('Library search results');

#create the search and query objects
my $search = CXGN::Searches::Library->new();
my $query = $search->new_query();
$search->page_size(20); #results shown per page

#get the parameters
my %params = $page->get_all_encoded_arguments();
$query->from_request(\%params);

if(%params)
{
	my $result = $search->do_search($query);  #execute the search
	my @results;
	while(my $r = $result->next_result())
	{
		#fields in result objs appear in the order in which they're registered with has_parameter() in the query class
		push @results, ["<a href=\"/content/library_info.pl?library=" . $r->[2] . "\">" . $r->[2] . "</a>", "<i>" . $r->[8] . "</i>", $r->[7], $r->[3]];
	}
  
	#build the HTML to output
	my $pagination_html = $search->pagination_buttons_html($query, $result);

	my $results_html = <<EOH;
	<div id="searchresults">
EOH

	$results_html .= columnar_table_html(headings => ['Name', 'Organism', 'Tissue', 'Development Stage'], 
														data => \@results, __alt_freq => 2);

	$results_html .= <<EOH;
	</div>
	$pagination_html
EOH

	if(@results)
	{
		print blue_section_html('Results', , sprintf('<span class="paginate_summary">%s matches </span>', $result->total_results(), $result->time), $results_html);
	}
	else
	{
		print '<span class=""><h4>No matches found</h4></span>';
	}
	print info_section_html(title => 'Search again', contents =>CXGN::Search::CannedForms::library_search_form($page, $query));
}

$page->footer();
