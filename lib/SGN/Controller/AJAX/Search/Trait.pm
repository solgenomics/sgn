
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

    

    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $trait_search = CXGN::Trait::Search->new
	({
	    bcs_schema=>$schema,
	 });
    my $data = $trait_search->search();
    my @result;
    foreach (@$data){
	push @result,
	[
	 $_->{trait_id},
	 "<a href=\"/cvterm/$_->{trait_id}\">$_->{trait_name}</a>",
	 $_->{trait_definition},
	];
    }
    #print STDERR Dumper \@result;
    $c->stash->{rest} = { data => \@result };
}


