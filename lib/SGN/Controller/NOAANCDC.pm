
package SGN::Controller::NOAANCDC;

use Moose;
use URI::FromHash 'uri';
use Data::Dumper;

BEGIN { extends 'Catalyst::Controller' };

sub noaa_ncdc_analysis :Path('/noaa_ncdc_analysis') Args(0) {
    my $self = shift;
    my $c = shift;

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $user_id;
    if ($c->user()) {
        $user_id = $c->user->get_object()->get_sp_person_id();
    }
    if (!$user_id) {
        $c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
    }

    $c->stash->{template} = '/breeders_toolbox/noaa_ncdc_analysis.mas';
}

1;
