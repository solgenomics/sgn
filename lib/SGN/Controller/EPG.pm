package SGN::Controller::EPG;

use Moose;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

SGN::Controller::EPG - show electrical penetration graph or EPG  pages for CG.org. add subroutines for other pages in electrical penetration graph menu

=cut


sub microtomography_index :Path('/epg/index') Args(0) {
    my $self = shift;
    my $c = shift;

    $c->stash->{template} = '/epg/index.mas';
}

sub microtomography_javier_bruker_2017 :Path('/epg/george_acp_2018') Args(0) {
    my $self = shift;
    my $c = shift;

    $c->stash->{template} = '/epg/george_acp_2018.mas';
}

1;
