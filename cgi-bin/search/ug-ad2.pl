######################################################################
#
#  This conducts and displays the results of a BAC search.
#
######################################################################

use strict;
use warnings;

use English;
use CXGN::Page;
use CXGN::Search::CannedForms;
use CXGN::Page::FormattingHelpers qw/ blue_section_html
				      page_title_html
				      commify_number
				      columnar_table_html
				    /;
use CXGN::Tools::Text;
use CXGN::DB::Connection;
use CXGN::Unigene::Search;
use CatalystX::GlobalContext '$c';
use SGN::I18N;
use HTML::Entities qw(encode_entities);
my SGN::I18N $i18n = eval { $c && $c->i18n };


#################################
# Start a new SGN page.
our $page = CXGN::Page->new( encode_entities(($i18n ? $i18n->p('global.ug-ad2.advanced_search', 'Unigene Advanced Search') : 'Unigene Advanced Search')), 'Rob Buels');
$page->header(encode_entities(($i18n ? $i18n->p('global.ug-ad2.page_title', 'Unigene Search Results') : 'Unigene Search Results'))); #print out header immediately so users get 'in progress' message

#create the search and query objects
my $search = CXGN::Unigene::Search->new;
$search->page_size(15); #set 15 unigenes per page
my $query = $search->new_query;

#get the parameters
my %params = $page->get_all_encoded_arguments;

eval { #initialize the query object from the page parameters
  $query->from_request(\%params);
}; if( $EVAL_ERROR ) {
  if($c->config->{'production_server'}) {
    print '<b>'.encode_entities(($i18n ? $i18n->p('global.ug-ad2.invalid_parameters', 'Invalid search parameters.') : 'Invalid search parameters.')).'</b>'."\n";
  } else {
    die $EVAL_ERROR; #die it on
  }
  $page->footer;
  exit;
}

#execute the search
# use Data::Dumper;
# print "<pre>".Dumper($query)."</pre>";
# exit;

my $result = $search->do_search($query);

my $sql = $query->to_query_string();

#build the HTML to output
my $pagination_html = $search->pagination_buttons_html( $query, $result );


my @tableheadings = (encode_entities(($i18n ? $i18n->p('global.ug-ad2.unigene_heading', 'Unigene') : 'Unigene')), encode_entities(($i18n ? $i18n->p('global.ug-ad2.build_heading', 'Build') : 'Build')), encode_entities(($i18n ? $i18n->p('global.ug-ad2.length_heading', 'Length (bp)') : 'Length (bp)')), encode_entities(($i18n ? $i18n->p('global.ug-ad2.members_heading', '# Members') : '# Members')));
my @tabledata;
my $querystring = $query->to_query_string;
while(my $ug = $result->next_result) {
  push @tabledata,[ map {$_ || '-'} ('<a href="'.$ug->info_page_href.';'.$querystring.'">'.$ug->external_identifier.'</a>',
				     $ug->build_object->organism_group_name.' #'.$ug->build_object->build_nr,
				     commify_number(length($ug->seq)),
				     $ug->nr_members,
				    )
		  ];
}

my $results_html = <<EOH
<div id="searchresults">
EOH
  . columnar_table_html(headings => \@tableheadings, data => \@tabledata)
  . <<EOH;
</div>
$pagination_html
EOH

print page_title_html(encode_entities(($i18n ? $i18n->p('global.ug-ad2.page_title', 'Unigene Search Results') : 'Unigene Search Results')));

my $result_summary = encode_entities($i18n ? $i18n->p('global.ug-ad2.results_summary', '%{count} matches (%{seconds} seconds)', { count => commify_number($result->total_results), seconds => sprintf('%0.1f', $result->time) }) : sprintf('%s matches (%0.1f seconds)', commify_number($result->total_results), $result->time));
print blue_section_html(encode_entities(($i18n ? $i18n->p('global.ug-ad2.page_title', 'Unigene Search Results') : 'Unigene Search Results')), '<span class="paginate_summary">' . $result_summary . '</span>', $results_html);

print blue_section_html(encode_entities(($i18n ? $i18n->p('global.ug-ad2.search_again', 'Search Again') : 'Search Again')),CXGN::Search::CannedForms::unigene_search_form($page,$query));

$page->footer();

