package SGN::Controller::VarietySheet;

=head1 NAME

SGN::Controller::VarietySheet - pages for commercial variety release profiles

=head1 DESCRIPTION

/tools/variety_sheet          step-by-step editor (curators only)
/variety_sheet/<id>           the profile itself (published profiles are public)
/variety_sheets               list of profiles

See L<CXGN::VarietySheet> and L<SGN::Controller::AJAX::VarietySheet>.

=cut

use Moose;
use JSON::XS;
use CXGN::VarietySheet;

BEGIN { extends 'Catalyst::Controller'; }

sub editor :Path('/tools/variety_sheet') :Args(0) {
    my ($self, $c) = @_;
    if (!$c->user) {
        $c->res->redirect($c->uri_for('/user/login', { goto_url => $c->req->uri->path_query }));
        return;
    }
    if (!$c->user->check_roles('curator')) {
        $c->stash->{message} = 'Only curators can create or edit variety profiles. <a href="/variety_sheets">See the published profiles</a>.';
        $c->stash->{template} = '/generic_message.mas';
        return;
    }
    my ($stock_id) = grep { /^\d+$/ } ($c->req->param('stock_id') // '');
    my ($sheet_id) = grep { /^\d+$/ } ($c->req->param('sheet_id') // '');
    $c->stash->{stock_id} = $stock_id;
    $c->stash->{sheet_id} = $sheet_id;
    $c->stash->{template} = '/tools/variety_sheet/index.mas';
}

sub list_page :Path('/variety_sheets') :Args(0) {
    my ($self, $c) = @_;
    $c->stash->{template} = '/tools/variety_sheet/list.mas';
}

sub view :Path('/variety_sheet') :Args(1) {
    my ($self, $c, $sheet_id) = @_;
    my $row = $sheet_id =~ /^\d+$/ ? CXGN::VarietySheet->get_sheet($c->dbic_schema('Bio::Chado::Schema', 'sgn_chado'), $sheet_id) : undef;
    my $pid = $c->user ? $c->user->get_object()->get_sp_person_id() : -1;
    my $curator = $c->user && $c->user->check_roles('curator');
    my $own = $row && ($row->{sp_person_id} // -2) == $pid;
    my $public = ($c->config->{variety_profile_public} // '') =~ /^\s*(1|yes|true|on)\s*$/i ? 1 : 0;
    if (!$row || (!($row->{status} eq 'published' && $public) && !$own && !$curator)) {
        $c->stash->{message} = $c->user ? 'This variety profile does not exist, or only curators can open it.'
            : 'Variety profiles are for curators: <a href="/user/login?goto_url=/variety_sheet/' . ($sheet_id =~ /^\d+$/ ? $sheet_id : '') . '">log in</a> to open it.';
        $c->stash->{template} = '/generic_message.mas';
        return;
    }
    $row->{can_edit} = $curator ? 1 : 0;
    $row->{public_profiles} = $public;
    CXGN::VarietySheet->refresh_check_names($c->dbic_schema('Bio::Chado::Schema', 'sgn_chado'), $row);
    CXGN::VarietySheet->strip_hidden($row) unless $row->{can_edit};
    # embedded in a <script> block: escape characters that could close it
    my $json = JSON::XS->new->ascii->canonical->encode($row);
    $json =~ s/</\\u003c/g;
    $json =~ s/>/\\u003e/g;
    $json =~ s/&/\\u0026/g;
    $c->stash->{sheet_json} = $json;
    $c->stash->{title} = $row->{commercial_name} || 'Variety profile';
    $c->stash->{template} = '/tools/variety_sheet/view.mas';
}

1;
