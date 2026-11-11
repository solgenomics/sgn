package SGN::Controller::VarietySheet;

=head1 NAME

SGN::Controller::VarietySheet - pages for commercial variety release profiles

=head1 DESCRIPTION

/tools/variety_sheet          step-by-step editor (login required)
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
    if (!$row || ($row->{status} ne 'published' && !$own && !$curator)) {
        $c->stash->{message} = 'This variety profile does not exist or has not been published.';
        $c->stash->{template} = '/generic_message.mas';
        return;
    }
    $row->{can_edit} = ($own || $curator) ? 1 : 0;
    CXGN::VarietySheet->strip_hidden($row) unless $row->{can_edit};
    # embedded in a <script> block: escape characters that could close it
    my $json = JSON::XS->new->ascii->canonical->encode($row);
    $json =~ s/</\\u003c/g;
    $json =~ s/>/\\u003e/g;
    $json =~ s/&/\\u0026/g;
    $c->stash->{sheet_json} = $json;
    $c->stash->{title} = $row->{commercial_name} || $row->{accession_name};
    $c->stash->{template} = '/tools/variety_sheet/view.mas';
}

1;
