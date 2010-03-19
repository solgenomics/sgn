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

use CXGN::VHost;
use CXGN::Unigene::Search;


#################################
# Start a new SGN page.
our $page = CXGN::Page->new( 'Unigene Advanced Search', 'Rob Buels');
$page->header('Unigene Search Results'); #print out header immediately so users get 'in progress' message
my $vhost = CXGN::VHost->new;

#create the search and query objects
my $search = CXGN::Unigene::Search->new;
$search->page_size(15); #set 15 unigenes per page
my $query = $search->new_query;

#get the parameters
my %params = $page->get_all_encoded_arguments;

eval { #initialize the query object from the page parameters
  $query->from_request(\%params);
}; if( $EVAL_ERROR ) {
  if($vhost->get_conf('production_server')) {
    print "<b>Invalid search parameters.</b>\n";
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


my @tableheadings = ('Unigene','Build','Length (bp)','# Members');
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

print page_title_html('Unigene Search Results');

print blue_section_html('Unigene Search Results',sprintf('<span class="paginate_summary">%s matches (%0.1f seconds)</span>',commify_number($result->total_results),$result->time),$results_html);

print blue_section_html('Search Again',CXGN::Search::CannedForms::unigene_search_form($page,$query));

$page->footer();

