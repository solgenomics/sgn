use strict;
use warnings;

use CXGN::Publication;
use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/
  blue_section_html
  info_section_html
  page_title_html
  columnar_table_html
  /;
use CXGN::Search::CannedForms;
use CXGN::DB::Connection;
use CXGN::Login;
use CXGN::People::Person;
use CXGN::Chado::Publication;

#################################################

# Start a new SGN page.

my $page = CXGN::Page->new( "SGN publcation search results", "Naama" );

$page->jsan_use("jquery");
$page->jsan_use("CXGN.Phenome.Publication");

$page->header();

print page_title_html('SGN Publication search');
my $dbh = CXGN::DB::Connection->new;

#create the search and query objects
my $search = CXGN::Publication->new;
my $query  = $search->new_query;

$search->page_size(10);    #set 10 phenetypes per page

my ( $login_person_id, $login_user_type ) =
  CXGN::Login->new($dbh)->has_session();

#get the parameters
my %params = $page->get_all_encoded_arguments;

#my $allele_keyword = $page->get_encoded_arguments("allele_keyword");
$query->from_request( \%params );

if (%params) {
    $query->order_by( date_stored => 'desc', pyear => 'desc', title => '' );
    my $result = $search->do_search($query);    #execute the search
    my @results;

    ###check if the the user has permission to alter pub_curator status

    my $has_permission = 0;
    if (   $login_user_type eq 'curator'
        || $login_user_type eq 'submitter'
        || $login_user_type eq 'sequencer' )
    {
        $has_permission = 1;
    }
    #####

    while ( my $r = $result->next_result ) {
        my $pub_id      = $r->[0];
        my $publication = CXGN::Chado::Publication->new( $dbh, $pub_id );
        my $pub_ref     = $publication->print_mini_ref();

        #my $title= $r->[1];
        #my $series = $r->[2];
        #my $pyear= $r->[3];
        my $assigned_to_id = $r->[4];
        my $assigned_to =
          CXGN::People::Person->new( $dbh, $assigned_to_id )->get_first_name();
        my $curation_date = $r->[5];
        my $curated_by_id = $r->[6];
        my $stat          = $r->[7];
        my $stored_on     = $r->[8];
        $stored_on =~ s/(\d{4}-\d{2}-\d{2})(.*)/$1/;

        my @stat_options = ( "curated", "pending", "irrelevant", "no gene" );
        my $stat_options = qq|<option value=""></option>|;
        foreach my $s (@stat_options) {
            my $selected = qq|selected="selected"| if $s eq $stat || '';
            $stat_options .= qq|<option value="$s" $selected >$s</option>|;
        }
        my $stats = $stat;
        $stats =
qq|<select id="pub_stat" onchange="Publication.updatePubCuratorStat(this.value, $pub_id)">
                    $stat_options
                    </select> 
                   | if $has_permission;

        my @curators = CXGN::People::Person::get_curators($dbh);
        my %names =
          map { $_ => CXGN::People::Person->new( $dbh, $_ )->get_first_name() }
          @curators;
        my $curator_options = qq|<option value=""></option>|;
        for my $curator_id ( keys %names ) {
            my $curator  = $names{$curator_id};
            my $selected = qq|selected="selected"| if $curator_id == $assigned_to_id || '';
            $curator_options .=
              qq|<option value="$curator_id" $selected>$curator</option>|;
        }
        my $curators = $assigned_to;
        $curators =
qq|<select id="pub_curator_select" onchange="Publication.updatePubCuratorAssigned(this.value, $pub_id)">
                     $curator_options
                     </select>
                    | if $has_permission;

        my $pub = CXGN::Chado::Publication->new( $dbh, $pub_id );
        push @results,
          [
            map { $_ } (
                qq|<a href="/publication/$pub_id/view">$pub_ref</a>|,
                $stats, $curators, $stored_on
            )
          ];
    }

    #build the HTML to output
    my $pagination_html = $search->pagination_buttons_html( $query, $result );

    my $results_html = <<EOH;
    <div id="searchresults">
EOH

    $results_html .= columnar_table_html(
        headings   => [ 'Title', 'Status', 'Assigned to', 'Stored' ],
        data       => \@results,
        __alt_freq => 2,
        __align    => 'llll'

          # __alt_width => 2,
    );

    $results_html .= <<EOH;
</div>
$pagination_html
EOH

    if (@results) {
        print blue_section_html(
            'Publication search results',
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
          CXGN::Search::CannedForms::publication_search_form( $page, $query )
    );

}
else {
    print CXGN::Search::CannedForms::publication_search_form($page);
}

$page->footer();

#############

