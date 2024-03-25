
package SGN::Controller::AJAX::Search::People;

use Moose;

BEGIN { extends 'Catalyst::Controller::REST' }

use Data::Dumper;
use JSON::Any;
use CXGN::Searches::People;

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
   );

# sub search :Path('/ajax/search/people') Args(0) { 
#     my $self = shift;
#     my $c = shift;

#     my $params = $c->req->params();

#     my $search = CXGN::Searches::People->new();
#     my $query = $search->new_query();

#     $query->from_request($params);
    
#     my $result = $search->do_search($query);
    
#     my @results;
#     while (my $r = $result->next_result()) { 
# 	push @results,  [
#           qq|<a href="/solpeople/personal-info.pl?sp_person_id=$r->[7]&amp;action=view">$r->[1], $r->[0]</a>|,
#           $r->[2],
#           $r->[3],
#           $r->[4],
#       ];

#     }
#     my $total_results = scalar(@results);
#     my $page_size = 20; #### impelement
#     my $j = JSON::Any->new();
#     my $query_json = $j->encode($params);
#     $c->stash->{rest} = { query => $params,
# 			  headers => [ 'Name', 'Email', 'Organization', 'Country' ],
# 			  page_size => $page_size,
#                           total_results => $total_results,
# 			  results => \@results,
#     };
# }

sub people_search :Path('/ajax/search/people') Args(0) { 
    my $self = shift;
    my $c = shift;
    
    my $params = $c->req->params() || {};

    #print STDERR "PARAMS: ".Dumper($params);

    my %query;

    foreach my $k ( qw |  first_name last_name organization country | ) { 
	if (exists($params->{$k}) && $params->{$k}) { 
	    print STDERR "transferring $k $params->{$k}\n";
	    $query{$k} = { 'ilike' => '%'.$params->{$k}.'%' };
	}
    }

    my $draw = $params->{draw};
    $draw =~ s/\D//g; # cast to int

    my $rows = $params->{length} || 10;
    my $start = $params->{start};

    my $page = int($start / $rows)+1;

    print STDERR "Runnin query...".Dumper(\%query)."\n";

    # get the count first
    #
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $rs = $c->dbic_schema("CXGN::People::Schema", undef, $sp_person_id)->resultset("SpPerson")->search( { %query, disabled => undef, censor => 0 } );
    
    my $records_total = $rs->count();

    print STDERR "RECORDS TOTAL: $records_total\n";
    # then get the data
    #
    my $rs2 = $c->dbic_schema("CXGN::People::Schema", undef, $sp_person_id)->resultset("SpPerson")->search( { %query, disabled=>undef, censor => 0 }, { page => $page, rows => $rows, order_by => 'last_name' } );
	

    my @result;
    while (my $p = $rs2->next()) { 
	push @result, [ '<a href="/solpeople/personal-info.pl?sp_person_id='.$p->sp_person_id().'">'.$p->last_name()."</a>", $p->first_name(), $p->organization(), $p->country() ];
    }

    #print STDERR "RESULTS: ".Dumper(\@result);

    $c->stash->{rest} = { data => [ @result ], draw => $draw, recordsTotal => $records_total,  recordsFiltered => $records_total };
    

}

    1;
