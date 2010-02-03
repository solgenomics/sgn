######################################################################
#
#  Search the phenome database and displays the results.
#
######################################################################



use strict;

use CXGN::Phenome;
use CXGN::Unigene::Search;
use CXGN::Page;
#use CXGN::Page::VHost::SGN;
use CXGN::Page::FormattingHelpers qw/blue_section_html
				     page_title_html
				     columnar_table_html
				     /;

#################################################
# Start a new SGN page.
my $page=CXGN::Page->new("SGN Gene Search ","Naama");
$page->header();

print page_title_html('Gene and Phenotype Search');


#create the search and query objects
my $search = CXGN::PhenoSearch->new;
my $query = $search->new_query;
$search->page_size(10); #set 10 loci per page


#get the parameters
my %params = $page->get_all_encoded_arguments;
$query->from_request(\%params);



if(%params) {
  my $result = $search->do_search($query);  #execute the search
  my @results;
  
#while(my $ug = $result->next_result) {
#  push @tabledata,[ map {$_ || '-'} ('<a href="'.$ug->info_page_href.'&'.$querystring.'">'.$ug->external_identifier.'</a>',
#				     $ug->build_object->organism_group_name.' #'.$ug->build_object->build_nr,
#				     commify_number(length($ug->sequence)),
#				     $ug->nr_members,
#				    )
#		  ];
#}

my $tgrc_url='http://tgrc.ucdavis.edu/Data/Acc/GenDetail.CFM?GENES.Gene=';
my $ncbi_url= '';  # fill in for loci names extracted from ncbi

while(my $r = $result->next_result) {
#   push @results,$r;
   #link to TGRC only for loci from TGRC 
   my $locus_link;
    if ($r->[1]) {
        $locus_link='<a href="'.$tgrc_url.$r->[1].'"TARGET="_blanc"'.'">';  #open link to TGRC gene page in the same new window
    }else {
        $locus_link ='';
    }

     push @results, [map {$_} ($r->[0], $locus_link.$r->[1].'</a>',
				$r->[2], $r->[3],
				)
			];
  }


   #build the HTML to output
   my $pagination_html = $search->pagination_buttons_html( $query, $result );
   

   my $results_html = <<EOH;
<div id="searchresults">
EOH

$results_html .= columnar_table_html(headings => [qw/LocusName LocusSymbol AlleleSymbol phenotype/], data => \@results);
$results_html .= <<EOH;
</div>
$pagination_html
EOH

#   print blue_section_html('Unigene Search Results',sprintf('<span class="paginate_summary">%s matches (%0.1f seconds)</span>',   $result->total_results,$result->time),$results_html);

 #  print blue_section_html('Search Results',
  #			  columnar_table_html( headings => [qw/LocusName LocusSymbol AlleleSymbol phenotype/],
  #					       data     => \@results,  
  #					     ),
  #			 );
  print blue_section_html('Gene Search Results', ,sprintf('<span class="paginate_summary">%s matches (%0.1f seconds)</span>',       $result->total_results,$result->time),$results_html);

}


my $form = $query->to_html;

print blue_section_html('Gene and Phenotype Search',<<EOHTML);
<form>
$form<br />
<input type="submit" />
<input type="reset" />
</form>
EOHTML

$page->footer();

#############

