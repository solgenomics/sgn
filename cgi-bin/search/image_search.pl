######################################################################
# #### DEPRECATED CGIBIN CODE ########################################
#
#  Search the image database and display the results.
#
######################################################################

use strict;

use CXGN::Searches::Images;
use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/blue_section_html
    info_section_html
    page_title_html
    columnar_table_html
    /;
use CXGN::Search::CannedForms;
#################################################

# Start a new SGN page.
my $page=CXGN::Page->new("SGN image search results","Jessica");
$page->header();

print page_title_html('Image search results');

#create the search and query objects
my $search = CXGN::Searches::Images->new;
my $query = $search->new_query;
$search->page_size(30); #set 30 images per page

#get the parameters
my %params = $page->get_all_encoded_arguments;

$query->from_request(\%params);

if(%params) {
    my $result = $search->do_search($query);
    my @results;
    
    while(my $r = $result->next_result) {
	my $image_id = $r->[0];

	my $image_description = $r->[2];
	if( length($image_description) < 1 ) {
	    $image_description = "---";
	}

	my $image_filename = $r->[3];
	my $submitter_id = $r->[4];

	my $submitter_first = $r->[5];
	if( length($submitter_first) < 1 ) {
	    $submitter_first = "---";
	}

	my $submitter_last = $r->[6];
	if( length($submitter_last) < 1 ) {
	    $submitter_last = "---";
	}

	# Put all submitter data in one variable
	my $submitter_string = "";

        unless ( $submitter_first eq "---" ) {
	    $submitter_string .= $submitter_first;
	    $submitter_string .= " ";
	}

	unless ( $submitter_last eq "---" ) {
	    $submitter_string .= $submitter_last;
	}

        # Image id, image filename, and submitter id can't be null, but everything else can be.

	push @results, [$image_description, '<a href="/image/index.pl?image_id='.$r->[0].'">'.$image_filename.'</a>', '<a href="/solpeople/personal-info.pl?sp_person_id='.$r->[4].'">'.$submitter_string.'</a>'];
    }
    
#build the HTML to output
    my $pagination_html = $search->pagination_buttons_html( $query, $result );
    
    
    my $results_html = <<EOH;
    <div id="searchresults">
EOH

	$results_html .= columnar_table_html(headings => ['Image Description',
							  'Image Filename',
							  'Submitter (ID) Name'],
					     data => \@results,
					     );

    $results_html .= <<EOH;
    </div>
	$pagination_html
EOH


	if (@results) {
	    print blue_section_html('Image search results', ,sprintf('<span class="paginate_summary">%s matches </span>', $result->total_results,$result->time),$results_html);
	}else {
	    print '<h4>No matches found</h4>';
	}

    print info_section_html(title    => 'Search again', 
			    contents =>CXGN::Search::CannedForms::image_search_form($page,$query)
			    );
    
}



$page->footer();

#############

