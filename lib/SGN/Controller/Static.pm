

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


sub mason_forward :Path('/pages') Args(1) {
    my $self = shift;
    my $c = shift;
    my $page = shift;

    print STDERR "Forwarding to $page...\n";
    $c->stash->{schema} = $c->dbic_schema("Bio::Chado::Schema");
    $c->stash->{template} = '/pages/'.$page.".mas";
}

sub mason_forward_with_subfolder :Path('/pages/') Args(2) {
    my $self = shift;
    my $c = shift;
    my $subfolder = shift;
    my $page = shift;

    print STDERR "Forwarding to $subfolder,  $page...\n";
    $c->stash->{schema} = $c->dbic_schema("Bio::Chado::Schema");
    $c->stash->{template} = '/pages/'.$subfolder."/".$page.".mas";
}

sub list_all_uploads :Path('/breeders/list_all_uploads') Args(0) {
    my $self = shift;
    my $c = shift;
    $c->stash->{template} = '/breeders_toolbox/complete_upload_list.mas';
}

sub ethz_cass_sync :Path('/ethz_cass/sync/') :Args(0) {
    my $self = shift;
    my $c = shift;
    #This mason component is in cassbase git repo.
    $c->stash->{template} = '/stock/ethz_cass_sync.mas';
}

sub tomato13_project_page :Path('/projects/tomato13/') Args(0) {
    my $self = shift;
    my $c = shift;
    $c->stash->{template} = '/projects/tomato13.mas';
}

sub tomato100_project_page :Path('/projects/tomato100/') Args(0) {
    my $self = shift;
    my $c = shift;
    $c->stash->{template} = '/projects/tomato100.mas';
}

sub tomatodisease_project_page :Path('/projects/tomatodisease/') Args(0) {
    my $self = shift;
    my $c = shift;
    $c->stash->{template} = '/projects/tomatodisease.mas';
}

sub solcode_project_page :Path('/projects/solcode/') Args(0) {
    my $self = shift;
    my $c = shift;
    $c->stash->{template} = '/projects/solcode.mas';
}

sub varitome_project_page :Path('/projects/varitome/') Args(0) {
    my $self = shift;
    my $c = shift;
    $c->stash->{template} = '/projects/varitome/index.mas';
}

sub test_authentication :Path('/test_authentication/') :Args(0) {
    my $self = shift;
    my $c = shift;
    $c->stash->{template} = '/test/test_authenticate.mas';
}

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
    $c->stash->{user_id} = $c->user();
}

sub usage_policy : Path('/usage_policy') {
    my ($self, $c) = @_;
    $c->stash->{template} = '/usage_policy.mas';
}

sub ted : Path('/ted') Args(0) {
    my ($self, $c) = @_;
    my $uri = $c->request->uri->as_string();

    my ($protocol, $empty, $server, $ted, @rest) = split "/", $uri;

    $c->stash->{page_title} = "Tomato Expression Database";
    $c->stash->{param_string} = join "/", @rest;
    $c->stash->{server} = 'ted.sgn.cornell.edu';
    $c->stash->{port} = "80"; # get this from conf...
    $c->stash->{template} = '/site/iframe.mas';
}

1;
