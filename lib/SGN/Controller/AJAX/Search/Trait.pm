
package SGN::Controller::AJAX::Search::Trait;

use Moose;
use Data::Dumper;
use CXGN::Trait;
use CXGN::Trait::Search;


BEGIN { extends 'Catalyst::Controller::REST'; }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
);

sub search : Path('/ajax/search/traits') Args(0) {
    my $self = shift;
    my $c    = shift;
    my $trait_cv_name = $c->req->param('trait_cv_name') || $c->config->{trait_cv_name};
    my $limit = $c->req->param('limit');
    my $offset = $c->req->param('offset');
    my $trait_search_list_id = $c->req->param('trait_search_list_id');

    my $subset_traits = [];
    if ($trait_search_list_id){
        my $list = CXGN::List->new({ dbh => $c->dbc->dbh, list_id => $trait_search_list_id });
        $subset_traits = $list->elements();
    }

    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $trait_search = CXGN::Trait::Search->new
	({
	    bcs_schema=>$schema,
	    trait_cv_name => $trait_cv_name,
        limit => $limit,
        offset => $offset,
        trait_name_list => $subset_traits
	 });
    my $data = $trait_search->search();
    my @result;
    foreach (@$data){
	my $db_name = $_->{db_name};
	my $accession = $_->{accession};
	my $trait_accession = $db_name .":". $accession ;
	push @result,
	[
     '',
	 "<a href=\"/cvterm/$_->{trait_id}/view\">$trait_accession</a>",
	 "<a href=\"/cvterm/$_->{trait_id}/view\">$_->{trait_name}</a>",
	 $_->{trait_definition},
	];
    }
    #print STDERR Dumper \@result;
    $c->stash->{rest} = { data => \@result };
}
