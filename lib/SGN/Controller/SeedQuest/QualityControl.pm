package SGN::Controller::SeedQuest::QualityControl;

use Moose;
use namespace::autoclean;
use URI::FromHash 'uri';

BEGIN { extends 'Catalyst::Controller'; }

sub quality_control_index : Path('/tools/seedquest/qualitycontrol') Args(0) {
    my ($self, $c) = @_;

    if (!$c->user()) {
        $c->res->redirect(uri(
            path  => '/user/login',
            query => { goto_url => $c->req->uri->path_query },
        ));
        return;
    }

    $c->stash->{template} = '/seedquest/tools/qualityControl/dataset_quality_control.mas';
}

__PACKAGE__->meta->make_immutable;

1;
