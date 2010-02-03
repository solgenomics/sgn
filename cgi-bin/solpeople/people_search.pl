######################################################################
#
#  Search the people database and display the results.
#
#  Adapted from locus_search.pl by Evan Herbst, 1 / 3 / 07
#
######################################################################

use strict;

use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/blue_section_html info_section_html page_title_html columnar_table_html/;
use CXGN::Search::CannedForms;
use CXGN::Searches::People;

#################################################

# Start a new SGN page.
my $page=CXGN::Page->new("SGN directory search results", "Evan");
$page->header();

print page_title_html('Directory search results');

#create the search and query objects
my $search = CXGN::Searches::People->new();
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
		push @results, [map {$_} 
							(
								"<a href=\"/solpeople/personal-info.pl?sp_person_id=" . $r->[7] . "&amp;action=view\">" . $r->[1] . ", " . $r->[0] . "</a>", 
								$r->[2], $r->[3], $r->[4]
							)];
	}
  
	#build the HTML to output
	my $pagination_html = $search->pagination_buttons_html($query, $result);

	my $results_html = <<EOH;
	<div id="searchresults">
EOH

	$results_html .= columnar_table_html(headings => ['Name', 'E-mail', 'Organization', 'Country'], 
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
	print info_section_html(title => 'Search again', contents =>CXGN::Search::CannedForms::people_search_form($page, $query));
}

$page->footer();
