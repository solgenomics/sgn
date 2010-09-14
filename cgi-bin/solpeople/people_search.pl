use CatalystX::GlobalContext qw( $c );
######################################################################
#
#  Search the people database and display the results.
#
#  Adapted from locus_search.pl by Evan Herbst, 1 / 3 / 07
#
######################################################################

use strict;

use CXGN::Page;
use CXGN::Page::FormattingHelpers
  qw/blue_section_html info_section_html page_title_html columnar_table_html/;
use CXGN::Search::CannedForms;
use CXGN::Searches::People;

#################################################

# Start a new SGN page.
my $page = CXGN::Page->new( "SGN directory search results", "Evan" );
$page->header();

print page_title_html('Directory search results');

#create the search and query objects
my $search = CXGN::Searches::People->new();
my $query  = $search->new_query();
$search->page_size(20);    #results shown per page

#get the parameters
my %params = CGI->new->Vars
  or $c->throw( message => 'No query parameters provided', is_error => 0 );
$query->from_request( \%params );

my $search_again_html = info_section_html(
    title    => 'Search again',
    contents => CXGN::Search::CannedForms::people_search_form( $page, $query )
);


_add_to_param( $query, $_, '&t NOT LIKE ? AND &t IS NOT NULL', '%contact-info.pl%')
    for 'last_name', 'first_name';

my $result = $search->do_search($query);    #execute the search
my @results;
while ( my $r = $result->next_result() ) {
    #fields in result objs appear in the order in which they're registered with has_parameter() in the query class
    push @results,
      [
          qq|<a href="/solpeople/personal-info.pl?sp_person_id=$r->[7]&amp;action=view">$r->[1], $r->[0]</a>|,
          $r->[2],
          $r->[3],
          $r->[4],
      ];
}

#build the HTML to output
my $pagination_html = $search->pagination_buttons_html( $query, $result );

my $results_html = <<EOH;
	<div id="searchresults">
EOH

$results_html .= columnar_table_html(
    headings   => [ 'Name', 'E-mail', 'Organization', 'Country' ],
    data       => \@results,
    __alt_freq => 2
);

$results_html .= <<EOH;
	</div>
	$pagination_html
EOH

if (@results) {
    print info_section_html(
        title => 'Results',
        contents =>
            sprintf(
                '<span class="paginate_summary">%s matches </span>',
                $result->total_results()
               )
           .$results_html,
       );
}
else {
    print '<h4>No matches found</h4>';
}

print $search_again_html;

$page->footer();

#### helper subs ######

# set additional criteria to not return people that have not set their
# first name or last name
sub _add_to_param {
    my ($query,$param,$cond,@bind) = @_;
    my $curr = $query->param_val($param) || ['true'];
    my $curr_exp = shift @$curr;
    $curr_exp = "&t $curr_exp" unless $curr_exp =~ /(&t|^true$)/;
    $query->param_set($param => ["$curr_exp AND $cond",@$curr,@bind]);
}
