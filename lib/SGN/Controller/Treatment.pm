package SGN::Controller::Treatment;

use Moose;

BEGIN { extends 'Catalyst::Controller'; }

sub treatment_design_page : Path('/treatments/design/') Args(0) {
    my $self = shift;
    my $c = shift;

    if ($c->user() && $c->user->check_roles('curator')) {
        $c->stash->{template} = '/tools/treatment_designer.mas';
    } else {
        $c->stash->{template} = '/site/error/permission_denied.mas';
    }
}

1;