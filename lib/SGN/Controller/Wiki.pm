
package SGN::Controller::Wiki;

use Moose;

BEGIN { extends 'Catalyst::Controller'; }




sub view_page :Path('/wiki/') Args(1) {
    my $self = shift;
    my $c = shift;

    my $page_name = shift;

    $c->stash->{page_name} = $page_name;
    $c->stash->{template} = '/wiki/view.mas';

}


sub view_home :Path('/wiki/') Args(0) {
    my $self = shift;
    my $c = shift;

    print STDERR "WIKI HOME\n";

    $c->stash->{template} = '/wiki/view.mas';
}


1;
