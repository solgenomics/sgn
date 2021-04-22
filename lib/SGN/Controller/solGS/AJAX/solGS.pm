
=head1 NAME

SGN::Controller::solGS::AJAX::solGS - a REST controller class to provide the
backend for objects linked with solgs

=head1 AUTHOR

Isaak Yosief Tecle <iyt2@cornell.edu>

=cut

package SGN::Controller::solGS::AJAX::solGS;

use Moose;


BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );



sub solgs_trait_search_autocomplete :  Path('/solgs/ajax/trait/search') : ActionClass('REST') { }

sub solgs_trait_search_autocomplete_GET :Args(0) {
    my ( $self, $c ) = @_;

    my $term = $c->req->param('term');

    $term =~ s/(^\s+|\s+)$//g;
    $term =~ s/\s+/ /g;

    my $traits = $c->model("solGS::solGS")->search_trait($term);

    $c->{stash}->{rest} = $traits;

}


sub solgs_population_search_autocomplete :  Path('/solgs/ajax/population/search') : ActionClass('REST') { }

sub solgs_population_search_autocomplete_GET :Args(0) {
    my ( $self, $c ) = @_;

    my $term = $c->req->param('term');
    $term =~ s/(^\s+|\s+)$//g;
    $term =~ s/\s+/ /g;
    my @response_list;

    my $rs = $c->model("solGS::solGS")->project_details_by_name($term);

    while (my $row = $rs->next) {

		$c->stash->{pop_id} = $row->id;
		$c->stash->{training_pop_id} = $row->id;
		my $location = $c->model('solGS::solGS')->project_location($row->id);

		my $is_training_pop;
		if ($location !~ /computation/i)
		{
			$is_training_pop = $c->controller('solGS::solGS')->check_population_is_training_population($c);
		}

		if ($is_training_pop)
		{
		    push @response_list, $row->name;
		}
    }

    $c->{stash}->{rest} = \@response_list;
}


sub begin : Private {
    my ($self, $c) = @_;

    $c->controller('solGS::Files')->get_solgs_dirs($c);

}

###
1;
###
