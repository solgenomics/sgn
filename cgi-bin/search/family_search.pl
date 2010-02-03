#!/usr/bin/perl

use strict;

use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/ 
	blue_section_html  info_section_html
	columnar_table_html page_title_html
	/;
use CXGN::Search::CannedForms;
use CXGN::Searches::Family;

my $page = CXGN::Page->new("SGN Family Search Results", "Chris");
$page->header();

print page_title_html("Family Search Results");

my $search = CXGN::Searches::Family->new();
my $query = $search->new_query();
$search->page_size(20);

my %params = $page->get_all_encoded_arguments();
$query->from_request(\%params);



if(%params){
	my $result = $search->do_search($query);
	my @results;
	while(my $r = $result->next_result()) {
		push(@results, [map {$_}
							(
								"<a href=\"/search/family.pl?family_id=" . $r->[0] . "\">" . $r->[2] . "</a>", $r->[3], $r->[4], $r->[6], $r->[0], $r->[1] )] );
	}

	my $pagination_html = $search->pagination_buttons_html($query, $result);

	my $results_html = '<div id="searchresults">';

	$results_html .= columnar_table_html(headings => ['Family Number', 'Number of Members', 'I-Value', 'Build #', 'Family ID', 'Annotation'], 
														data => \@results, __alt_freq => 2);

	$results_html .= "</div>\n$pagination_html\n";

	if(@results) {
		print blue_section_html('Results', , sprintf('<span class="paginate_summary">%s matches </span>', $result->total_results(), $result->time), $results_html);
	}
	else {
		print '<span class=""><h4>No matches found</h4></span>';
	}
	print info_section_html(title => 'Search again', contents =>CXGN::Search::CannedForms::family_search_form($page, $query));
}

$page->footer();


