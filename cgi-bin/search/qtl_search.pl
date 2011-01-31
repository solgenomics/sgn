######################################################################
#
#  Search the phenome database and displays the results.
#
######################################################################

use strict;

use CXGN::Qtls;
use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/blue_section_html
  info_section_html
  page_title_html
  columnar_table_html
  /;
use CXGN::Search::CannedForms;
use CXGN::DB::Connection;
use CXGN::Phenome::Qtl::Tools;
use CXGN::Chado::Cvterm;


my $page = CXGN::Page->new( "SGN QTLs search results", "Isaak" );
$page->header();

print page_title_html('QTL search results');
my $dbh = CXGN::DB::Connection->new();


#get the parameters
my %params      = $page->get_all_encoded_arguments();
my ($key) = keys (%params);
my $term = $params{$key};

#create the search and query objects
my $search = CXGN::Qtls->new;
my $query  = $search->new_query;
$query->from_request( \%params );
$search->page_size(60);

my (@results, @cvterm_results)=();
my $qtl_mark = qq |<font size=4 color="#0033FF"> &#10003;</font> |; 

if (%params)
{
    my $cv       = CXGN::Phenome::Qtl::Tools->new();       
    $query->order_by( cvterm_name => '' );
    my $result = $search->do_search($query);    #execute the search
    
    while ( my $r = $result->next_result )
    {          
        my $has_qtl = $cv->is_from_qtl( $r->[0] );        
        if ($has_qtl)
        { 
            push @cvterm_results, $r->[1];
            push @results,
            [
             map { $_ } 
             (
              '<a href="/chado/cvterm.pl?cvterm_id='
              . $r->[0] 
              . '">'
              . $r->[1] 
              . '</a>'
              ,$r->[2]
              ,$r->[3]
              ,$qtl_mark                       
             )
            ];            
        }
    }    
    
    my ($trait_id, $trait_name, $trait_definition) = $cv->search_usertrait($term);    		
    if ($trait_id) 
    {
        for (my $i=0; $i < @$trait_id; $i++) 
        {
            unless ( grep { $_ eq $trait_name->[$i] } @cvterm_results) 
            {
                push @results,
                [
                 map { $_ } 
                 (
                  '<a href="/phenome/trait.pl?trait_id='
                  . $trait_id->[$i] 
                  . '">'
                  . $trait_name->[$i] 
                  . '</a>'
                  ,' '
                  ,$trait_definition->[$i]
                  ,$qtl_mark
                 )
                ]; 
            }              
        }
    } 

#build the HTML to output
    my $pagination_html = $search->pagination_buttons_html( $query, $result );
    my $results_html = <<EOH;
    <div id="searchresults">
EOH

$results_html .= columnar_table_html(
    headings    => [ 'Trait name', 'Synonym', 'Definition', 'QTL' ],
    data        => \@results,
    __alt_freq  => 2,
    __alt_width => 1,
);

    $results_html .= <<EOH;
    </div>
	$pagination_html
EOH


#sprintf(
#	    '<span class="paginate_summary">%s matches </span>',
#            $result->total_results, $result->time
#        ),


if (@results)
{
    print blue_section_html(
	'QTL  search results',       	
	$results_html
        );
}
else
{
    print '<h4>No matches found</h4>';
}

print info_section_html(
    title => 'Search again',
    contents =>
    CXGN::Search::CannedForms::qtl_search_form( $page, $query ),
    collapsible => 1,
    collapsed   => 1,
    );

}

$page->footer();

#############

