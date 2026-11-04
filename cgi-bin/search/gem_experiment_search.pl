######################################################################
#
#  Search the expression database and display the results.
#
#  Adapted to the search framework by Aureliano Bombarely, 18/01/10
#
######################################################################

use strict;
use CatalystX::GlobalContext '$c';
use SGN::I18N;
use HTML::Entities qw(encode_entities);
my SGN::I18N $i18n = eval { $c && $c->i18n };

use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/blue_section_html info_section_html page_title_html columnar_table_html/;
use CXGN::Search::CannedForms;
use CXGN::Searches::GemExperiment;

my $page=CXGN::Page->new(encode_entities(($i18n ? $i18n->p("global.gem_experiment_search.page_title", "Expression search results by experiment") : "Expression search results by experiment")), "Aure");
$page->header();

print page_title_html(encode_entities(($i18n ? $i18n->p('global.gem_experiment_search.page_title', 'Expression search results by experiment') : 'Expression search results by experiment')));

#create the search and query objects
my $search = CXGN::Searches::GemExperiment->new();
my $query = $search->new_query();
$search->page_size(20); #results shown per page

#get the parameters
my %params = $page->get_all_encoded_arguments();
my @keys = keys %params;
my @values = values %params;


$query->from_request(\%params);

if(%params)
{
	my $result = $search->do_search($query);  #execute the search
	my @results;

	while(my $r = $result->next_result())
	{
		#fields in result objs appear in the order in which they're registered with has_parameter() in the query class
		push @results, ["<a href=\"/gem/experimental_design.pl?id=" . $r->[2] . "\">" . $r->[3] . "</a>",
                                "<a href=\"/gem/experiment.pl?id="          . $r->[0] . "\">" . $r->[1] . "</a>" ];
	}

	#build the HTML to output
	my $pagination_html = $search->pagination_buttons_html($query, $result);

	my $results_html = <<EOH;
	<div id="searchresults">
EOH

	$results_html .= columnar_table_html(headings => [encode_entities(($i18n ? $i18n->p('global.gem_experiment_search.experimental_design', 'Experimental Design') : 'Experimental Design')), encode_entities(($i18n ? $i18n->p('global.gem_experiment_search.experiment', 'Experiment') : 'Experiment'))],
		         data => \@results, __alt_freq => 2);

	$results_html .= <<EOH;
	</div>
	$pagination_html
EOH

	if(@results)
	{
		print blue_section_html(encode_entities(($i18n ? $i18n->p('global.gem_experiment_search.results', 'Results') : 'Results')), , '<span class=\"paginate_summary\">' . encode_entities($i18n ? $i18n->p('global.gem_experiment_search.results_summary', '%{count} matches ', { count => $result->total_results() }) : sprintf('%s matches ', $result->total_results())) . '</span>', $results_html);
	}
	else
	{
		print '<span class=""><h4>'.encode_entities(($i18n ? $i18n->p('global.gem_experiment_search.no_matches', 'No matches found') : 'No matches found')).'</h4></span>';
	}
	print info_section_html(title => encode_entities(($i18n ? $i18n->p('global.gem_experiment_search.search_again', 'Search again') : 'Search again')), contents =>CXGN::Search::CannedForms::expr_experiment_search_form($page, $query));
}

$page->footer();
