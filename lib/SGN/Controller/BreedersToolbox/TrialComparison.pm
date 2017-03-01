
package SGN::Controller::BreedersToolbox::Trial::TrialComparison;

use Moose;

BEGIN { extends 'Catalyst::Controller'; }


sub trial_comparison_input :Path('/tools/trial/comparison/list') Args(0) { 
    my $self = shift;
    my $c = shift;
    
    $c->stash->{template} = '/tools/trial_comparison/index.mas';

}

sub trial_comparison_no_lists :Path('/tools/trial/comparison/params') Args(0) { 
    my $self = shift;
    my $c = shift;

    my @trial_names = $c->req->param("trial_name");
    my $cvterm_id = $c->req->param("cvterm_id");
    $c->stash->{trial_names} = \@trial_names;
    $c->stash->{cvterm_id} = $cvterm_id;
    $c->stash->{template} = '/tools/trial_comparison/no_list.mas';
}

1;
