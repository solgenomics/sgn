######################################################################
#
#  Search the phenome database and displays the results.
#
######################################################################

use strict;

use CXGN::Phenotypes;
use CXGN::Phenome::Individual;
use CXGN::Page;
use CXGN::Page::FormattingHelpers qw( blue_section_html
				      info_section_html
				      page_title_html
				      columnar_table_html
				    );
use CXGN::Search::CannedForms;
use CXGN::DB::Connection;

use SGN::Image;

#################################################

# Start a new SGN page.

my $page = CXGN::Page->new( "SGN phenotype search results", "Naama" );
$page->header();

print page_title_html('Phenotype search results');
my $dbh = CXGN::DB::Connection->new("phenome");

#create the search and query objects
my $search = CXGN::Phenotypes->new;
my $query  = $search->new_query;
$search->page_size(10);    #set 10 phenetypes per page

#get the parameters
my %params         = $page->get_all_encoded_arguments;
my $allele_keyword = $page->get_encoded_arguments("allele_keyword");

$query->from_request( \%params );

if (%params) {
    $query->order_by( individual_name => '' );

    my $result = $search->do_search($query);    #execute the search
    my @results;

    while ( my $r = $result->next_result ) {
        my $phenotype = $r->[2];

        #my $allele_phenotype= $r->[3];
        #if (!$phenotype) {$phenotype = $allele_phenotype; }
        # my $obsolete = $r->[7]; #check if the locus is obsoleted
        # if (!$obsolete) {
        #  my $phenotype= substr($r->[6],0,20);
        #  if (defined$r->[6]) {
        #      $phenotype .= '....';
        #  }else {
        #      $phenotype = '--';
        #  }

        my $ind         = CXGN::Phenome::Individual->new( $dbh, $r->[0] );
        my @images      = map SGN::Image->new($dbh, $_), $ind->get_image_ids();
        my $img_src_tag = '<span class="ghosted">none</span>';
        $img_src_tag = $images[0]->get_img_src_tag("tiny") if $images[0];
        push @results,
          [
            map { $_ } (
                '<a href="/phenome/individual.pl?individual_id='
                  . $r->[0] . '">'
                  . $r->[1] . '</a>',
                $phenotype || '<span class="ghosted">none</span>',
                $img_src_tag,
            )
          ];

        # }
    }

    #build the HTML to output
    my $pagination_html = $search->pagination_buttons_html( $query, $result );

    my $results_html = <<EOH;
    <div id="searchresults">
EOH

    $results_html .= columnar_table_html(
        headings => [ 'Accession name', 'Description', 'Image' ],
        data     => \@results,

        # __alt_freq => 2,
        # __alt_width => 2,
    );

    $results_html .= <<EOH;
</div>
$pagination_html
EOH

    if (@results) {
        print blue_section_html(
            'Phenotype search results',
            ,
            sprintf(
                '<span class="paginate_summary">%s matches </span>',
                $result->total_results, $result->time
            ),
            $results_html
        );
    }
    else {
        print '<h4>No matches found</h4>';
    }

    print info_section_html(
        title => 'Search again',
        contents =>
          CXGN::Search::CannedForms::phenotype_search_form( $page, $query )
    );

}

$page->footer();

#############

