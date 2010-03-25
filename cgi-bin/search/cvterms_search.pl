######################################################################
#
#  Search the phenome database and displays the results.
#
######################################################################



use strict;

use CXGN::Cvterms;
use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/blue_section_html
                                     info_section_html
				     page_title_html
				     columnar_table_html
                                  /;
use CXGN::Search::CannedForms;
use CXGN::DB::Connection;
#################################################


my $page=CXGN::Page->new("SGN QTLs/Traits search results","Isaak");
$page->header();

print page_title_html('QTL/Trait search results');
my $dbh= CXGN::DB::Connection->new();

#create the search and query objects
my $search = CXGN::Cvterms->new;
my $query = $search->new_query;
$search->page_size(15); #set 10 cvterms per page



#get the parameters
my %params = $page->get_all_encoded_arguments;
my $cvterm_name = $page->get_encoded_arguments("cvterm_name");
#my $cvterm_synonym = $page->get_encoded_arguments("cvterm_synonym");
$query->from_request(\%params);



if (%params) {
    $query->order_by( cvterm_name=> '');
    
    my $result = $search->do_search($query);  #execute the search

   
    my @results;
    
    
    while(my $r = $result->next_result) {
	
        my $cv=CXGN::Phenome::Qtl::Tools->new();
	my $has_qtl = $cv->is_from_qtl($r->[0]);
	my $qtl_mark; 
	my $tickmark = "&#10003;";
	my $x = 'x';
	if ($has_qtl) { 
	    $qtl_mark = qq |<font size=4 color="#0033FF">$tickmark</font> |;
	} else {$qtl_mark = qq|<font size=4 color="red">$x</font> |;}
	
	push @results, [map {$_} ('<a href="/chado/cvterm.pl?cvterm_id='.$r->[0].'">'.$r->[1]. '</a>', 
                                  $r->[2],                               
				  $r->[3],
				  $qtl_mark
				  )
			];
    
 }   
#build the HTML to output
    my $pagination_html = $search->pagination_buttons_html( $query, $result );
    my $results_html = <<EOH;
    <div id="searchresults">
EOH

	$results_html .= columnar_table_html(headings => ['Trait name',
							  'Synonym',
							  'Definition',
							  'QTL'
							  ],
				     data => \@results,
				      __alt_freq =>2,
				      __alt_width => 1,
				     );


    $results_html .= <<EOH;
    </div>
	$pagination_html
EOH


	if (@results) {
	    print blue_section_html('QTL/Trait search results', ,sprintf('<span class="paginate_summary">%s matches </span>', $result->total_results,$result->time),$results_html);
	}else {
	    print '<h4>No matches found</h4>';
	}

    print info_section_html(title    => 'Search again', 
			  contents =>CXGN::Search::CannedForms::cvterm_search_form($page, $query)
			  );
  
}



$page->footer();

#############

