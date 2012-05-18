
use strict;
use CXGN::DB::Connection;
use CXGN::Page;
use CXGN::Page::FormattingHelpers qw / page_title_html info_section_html columnar_table_html /;
use CXGN::Insitu::Toolbar;
use CXGN::Insitu::Experiment;
use CXGN::Insitu::ExperimentSearch;
use CXGN::People;
use CXGN::People::Person;

my $page = CXGN::Page->new();
my $dbh = CXGN::DB::Connection->new();
$page->header();

print page_title_html( qq{ <a href="/insitu/">Insitu</a> Database } );

display_toolbar("search");

my $exp_search = CXGN::Insitu::ExperimentSearch->new();
my $exp_query = $exp_search->new_query();

# $exp_query->debug(1);

$exp_search->page_size(10);

my %params = $page->get_all_encoded_arguments();

$exp_query->from_request(\%params);

my $result = "";
my @results =();

my $total_results=0;
my $page_html = "";
if (%params) { 
    $result = $exp_search->do_search($exp_query);
    $total_results=$result->total_results();
    if ($total_results <= 0 ) { 
	print "<b>No results</b>\n";
    }
    else { 
	
	while (my $r = $result->next_result()) { 
	    #push @results, [ $r->[0], $r->[1], $r->[2], $r->[3], $r->[4], $r->[5], $r->[6], $r->[7], $r->[8], $r->[9] ];
	    my $experiment_id = $r->[0];
	    my $experiment = CXGN::Insitu::Experiment->new($dbh, $experiment_id);
	    my $experiment_name = $experiment->get_name();
	    my $tissue = $experiment->get_tissue();
	    my $stage = $experiment->get_stage();
	    my $experiment_image_count = $experiment->get_images();
	    my $submitter = CXGN::People::Person->new($dbh, $experiment->get_user_id());
	    my $submitter_name = $submitter->get_first_name()." ".$submitter->get_last_name();
	    push @results, [ qq { <a href="/insitu/detail/experiment.pl?experiment_id=$experiment_id&amp;action=view">$experiment_name</a> }, $stage, $tissue, $experiment_image_count, $submitter_name ];

	}
	$page_html = $exp_search->pagination_buttons_html($exp_query, $result);
    }
}
my $html = "";



$html .= columnar_table_html( headings => [ 'Experiment', 'Stage', 'Tissue', '# images', 'Submitter' ],
			      data     => \@results
			      );
print info_section_html( title=>"Insitu Search Results", subtitle=>"$total_results"." Results"  , empty_message=>"No results" , contents=>$html.$page_html);

print info_section_html( title=>"Search again", contents=>"<form action=\"#\">".$exp_query->to_html()."</form><br />" );

$page->footer();
