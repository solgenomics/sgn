######################################################################
#
#  Search the phenome database and displays the results.
#
######################################################################



use strict;
use CatalystX::GlobalContext '$c';
use SGN::I18N;
use HTML::Entities qw(encode_entities);
my SGN::I18N $i18n = eval { $c && $c->i18n };

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

my $page=CXGN::Page->new(encode_entities(($i18n ? $i18n->p("global.final_caption.sgn_gene_search_results", "SGN gene search results") : "SGN gene search results")),"Naama");
$page->header();

print page_title_html(encode_entities(($i18n ? $i18n->p('global.locus_search.page_title', 'Gene search results') : 'Gene search results')));


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

$results_html .= columnar_table_html(headings => [encode_entities(($i18n ? $i18n->p('global.locus_search.organism', 'Organism') : 'Organism')),
						  encode_entities(($i18n ? $i18n->p('global.locus_search.locus_name', 'Locus name') : 'Locus name')),
						  'Locus symbol',
						  encode_entities(($i18n ? $i18n->p('global.locus_search.allele_name', 'Allele name') : 'Allele name')),
						  'Allele symbol',
						  encode_entities(($i18n ? $i18n->p('global.locus_search.allele_phenotype', 'Allele phenotype') : 'Allele phenotype'))],
				     data => \@results,
				     # __alt_freq => 2,
				     # __alt_width => 2,
				     );


$results_html .= <<EOH;
</div>
$pagination_html
EOH


if (@results) {

    print blue_section_html(encode_entities(($i18n ? $i18n->p('global.locus_search.results', 'Gene search results') : 'Gene search results')), ,'<span class=\"paginate_summary\">' . encode_entities($i18n ? $i18n->p('global.locus_search.results_summary', '%{count} matches ', { count => $result->total_results }) : sprintf('%s matches ', $result->total_results)) . '</span>',$results_html);
}else {
    print '<h4><span class="">'.encode_entities(($i18n ? $i18n->p('global.locus_search.no_matches', 'No matches found') : 'No matches found')).'</span></h4>';
}

  print info_section_html(title    => encode_entities(($i18n ? $i18n->p('global.locus_search.search_again', 'Search again') : 'Search again')),
			  contents =>CXGN::Search::CannedForms::gene_search_form($page,$query)
			  );
}



$page->footer();

#############

