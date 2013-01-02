

=head1 NAME

SGN::Controller::Static - a controller for dispatching to static pages

=head1 DESCRIPTION

SGN has some static pages that don't merit their own controller. The purpose of this one is to have one common controller for all the static pages that don't fit anywhere else.

Please feel free to add your own pages. The actions should essentially just link to a mason component for display.

=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>

=cut


package SGN::Controller::Static;

use Moose;

BEGIN { extends 'Catalyst::Controller'; }


sub solanaceae_project_afri :Path('/solanaceae-project/afri-sol/') { 
    my ($self, $c) = @_;
    $c->stash->{template} = '/links/afri_sol.mas';
}


sub sgn_events :Path('/sgn-events/') {
    my ($self, $c) = @_;
    $c->stash->{template} = '/homepage/sgn_events.mas';
}


sub phenotype_select : Path('/phenome/select') { 
    my ($self, $c) = @_;
    
    $c->stash->{template} = '/phenome/select.mas';


}

sub list_test : Path('/list/test') { 
    my ($self, $c) = @_;
    $c->stash->{template}= '/list/index.mas';
}

1;
