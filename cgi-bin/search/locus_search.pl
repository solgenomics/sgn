######################################################################
#
#  Search the phenome database and displays the results.
#
######################################################################



use strict;

use CXGN::Phenome;
use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/blue_section_html
                                     info_section_html
				     page_title_html
				     columnar_table_html
				     /;
use CXGN::Search::CannedForms;
#################################################

# Start a new SGN page.

my $page=CXGN::Page->new("SGN gene search results","Naama");
$page->header();

print page_title_html('Gene search results');


#create the search and query objects
my $search = CXGN::Phenome->new;
my $query = $search->new_query;

$search->page_size(10); #set 10 loci per page



#get the parameters
my %params = $page->get_all_encoded_arguments;
my $any_name = $page->get_encoded_arguments("any_name");


$query->from_request(\%params);



if(%params) {
    $query->order_by( locus_symbol=> 'UPPER(&t)');
    my $result = $search->do_search($query);  #execute the search
    
    my @results;
    
    
    while(my $r = $result->next_result) {
	#    push @results,$r;
	my ($allele_name, $allele_symbol, $phenotype) = ($r->[3], $r->[4], $r->[6]);
	my $allele_obsolete = $r->[8];
	
	my $phenotype= substr($r->[6],0,20);
	if (defined$r->[6]) {
	    $phenotype .= '....';
	}else {
	    $phenotype = '--';
	}
	#if (!$allele_obsolete) { #don't display obsolete alleles! #alleles shouldn't be obsolete now..
	    
	    push @results, [map {$_} ($r->[14],
				      '<a href="/phenome/locus_display.pl?locus_id='.$r->[0].'">'.$r->[1].'</a>', 
				      $r->[2],
				      $allele_name,
				      $allele_symbol, 
				      $phenotype,
				      )
			    ];
	#}
    }


   
#build the HTML to output
  my $pagination_html = $search->pagination_buttons_html( $query, $result );
   

   my $results_html = <<EOH;
<div id="searchresults">
EOH

$results_html .= columnar_table_html(headings => ['Organism',
						  'Locus name',
						  'Locus symbol',
						  'Allele name',
						  'Allele symbol',
						  'Allele phenotype'],
				     data => \@results,
				     # __alt_freq => 2,
				     # __alt_width => 2,
				     );


$results_html .= <<EOH;
</div>
$pagination_html
EOH


if (@results) {
    
    print blue_section_html('Gene search results', ,sprintf('<span class="paginate_summary">%s matches </span>', $result->total_results,$result->time),$results_html);
}else {
    print '<h4><span class="">No matches found</span></h4>';
}

  print info_section_html(title    => 'Search again', 
			  contents =>CXGN::Search::CannedForms::gene_search_form($page,$query)
			  );
}



$page->footer();

#############

