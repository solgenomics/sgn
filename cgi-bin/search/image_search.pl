######################################################################
# #### DEPRECATED CGIBIN CODE ########################################
#
#  Search the image database and display the results.
#
######################################################################

use strict;
use CatalystX::GlobalContext '$c';
use SGN::I18N;
use HTML::Entities qw(encode_entities);
my SGN::I18N $i18n = eval { $c && $c->i18n };

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
my $page=CXGN::Page->new(encode_entities(($i18n ? $i18n->p("global.final_caption.sgn_image_search_results", "SGN image search results") : "SGN image search results")),"Jessica");
$page->header();

print page_title_html(encode_entities(($i18n ? $i18n->p('global.image_search.page_title', 'Image search results') : 'Image search results')));

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

	$results_html .= columnar_table_html(headings => [encode_entities(($i18n ? $i18n->p('global.image_search.image_description', 'Image Description') : 'Image Description')),
							  encode_entities(($i18n ? $i18n->p('global.image_search.image_filename', 'Image Filename') : 'Image Filename')),
							  encode_entities(($i18n ? $i18n->p('global.image_search.submitter', 'Submitter (ID) Name') : 'Submitter (ID) Name'))],
					     data => \@results,
					     );

    $results_html .= <<EOH;
    </div>
	$pagination_html
EOH


	if (@results) {
	    print blue_section_html(encode_entities(($i18n ? $i18n->p('global.image_search.page_title', 'Image search results') : 'Image search results')), ,'<span class=\"paginate_summary\">' . encode_entities($i18n ? $i18n->p('global.image_search.results_summary', '%{count} matches ', { count => $result->total_results }) : sprintf('%s matches ', $result->total_results)) . '</span>',$results_html);
	}else {
	    print '<h4>'.encode_entities(($i18n ? $i18n->p('global.image_search.no_matches', 'No matches found') : 'No matches found')).'</h4>';
	}

    print info_section_html(title    => encode_entities(($i18n ? $i18n->p('global.image_search.search_again', 'Search again') : 'Search again')),
			    contents =>CXGN::Search::CannedForms::image_search_form($page,$query)
			    );

}



$page->footer();

#############

