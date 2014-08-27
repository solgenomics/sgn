
package SGN::Controller::AJAX::Search::People;

use Moose;

BEGIN { extends 'Catalyst::Controller::REST' }

use JSON::Any;
use CXGN::Searches::People;

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );

sub search :Path('/ajax/search/people') Args(0) { 
    my $self = shift;
    my $c = shift;

    my $params = $c->req->params();

    my $search = CXGN::Searches::People->new();
    my $query = $search->new_query();

    $query->from_request($params);
    
    my $result = $search->do_search($query);
    
    my @results;
    while (my $r = $result->next_result()) { 
	push @results,  [
          qq|<a href="/solpeople/personal-info.pl?sp_person_id=$r->[7]&amp;action=view">$r->[1], $r->[0]</a>|,
          $r->[2],
          $r->[3],
          $r->[4],
      ];

    }
    my $total_results = 0; ##### implement
    my $page_size = 20; #### impelement
    my $j = JSON::Any->new();
    my $query_json = $j->encode($params);
    $c->stash->{rest} = { query => $params,
			  headers => [ 'Name', 'Email', 'Organization', 'Country' ],
			  page_size => $page_size,
                          total_results => $total_results,
			  results => \@results,
    };
}


    1;
