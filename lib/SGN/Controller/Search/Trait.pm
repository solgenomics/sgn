
package SGN::Controller::Search::Trait;

use Moose;

BEGIN { extends 'Catalyst::Controller'; }

sub trait_search_page : Path('/search/traits/') Args(0) {
    my $self = shift;
    my $c = shift;

    if (my $message = $c->stash->{access}->denied( $c->stash->{user_id}, "read", "phenotyping" )) {
	$c->stash->{template} = '/access/access_denied.mas';
	$c->stash->{data_type} = 'phenotype';
	$c->stash->{message} = $message;
	return;
    }

    
    $c->stash->{template} = '/search/traits.mas';
}

1;
