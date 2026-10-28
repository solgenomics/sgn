#!/usr/bin/perl

use strict;
use SGN::I18N ();
use CatalystX::GlobalContext '$c';
use HTML::Entities ();
my SGN::I18N $ui_family_search_i18n = $c && $c->can('i18n') ? $c->i18n : undef;

use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/ 
	blue_section_html  info_section_html
	columnar_table_html page_title_html
	/;
use CXGN::Search::CannedForms;
use CXGN::Searches::Family;

my $page = CXGN::Page->new(HTML::Entities::encode_entities((SGN::I18N::translate($ui_family_search_i18n, "cross.gene_family.page_title", "SGN Family Search Results"))), "Chris");
$page->header();

print page_title_html(HTML::Entities::encode_entities((SGN::I18N::translate($ui_family_search_i18n, "cross.gene_family.heading", "Family Search Results"))));

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

	$results_html .= columnar_table_html(headings => [HTML::Entities::encode_entities((SGN::I18N::translate($ui_family_search_i18n, "cross.gene_family.number", "Family Number"))), HTML::Entities::encode_entities((SGN::I18N::translate($ui_family_search_i18n, "cross.gene_family.members", "Number of Members"))), 'I-Value', HTML::Entities::encode_entities((SGN::I18N::translate($ui_family_search_i18n, "cross.gene_family.build", "Build #"))), HTML::Entities::encode_entities((SGN::I18N::translate($ui_family_search_i18n, "cross.gene_family.id", "Family ID"))), HTML::Entities::encode_entities((SGN::I18N::translate($ui_family_search_i18n, "global.family.annotation", "Annotation")))],
														data => \@results, __alt_freq => 2);

	$results_html .= "</div>\n$pagination_html\n";

	if(@results) {
		print info_section_html(title => HTML::Entities::encode_entities((SGN::I18N::translate($ui_family_search_i18n, "global.gem_experiment_search.results", "Results"))), anchor_title => 'Results', subtitle => sprintf('<span class="paginate_summary">%s</span>', HTML::Entities::encode_entities((SGN::I18N::translate($ui_family_search_i18n, "global.gem_experiment_search.results_summary", "%{count} matches ", {count => "" . ($result->total_results())}))), $result->time), contents => $results_html);
	}
	else {
		print '<span class=""><h4>' . HTML::Entities::encode_entities((SGN::I18N::translate($ui_family_search_i18n, "global.gem_experiment_search.no_matches", "No matches found"))) . '</h4></span>';
	}
	print info_section_html(title => HTML::Entities::encode_entities((SGN::I18N::translate($ui_family_search_i18n, "global.gem_experiment_search.search_again", "Search again"))), anchor_title => 'Search again', contents =>CXGN::Search::CannedForms::family_search_form($page, $query, $ui_family_search_i18n));
}

$page->footer();


