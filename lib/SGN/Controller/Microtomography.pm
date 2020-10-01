package SGN::Controller::Microtomography;

use Moose;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

SGN::Controller::Microtomography - show Microtomography pages for CG.org. add subroutines for other pages in Microtomography menu

=cut


sub microtomography_index :Path('/microtomography/index') Args(0) {
    my $self = shift;
    my $c = shift;

    $c->stash->{template} = '/microtomography/index.mas';
}

sub microtomography_javier_bruker_2017 :Path('/microtomography/javier_bruker_2017') Args(0) {
    my $self = shift;
    my $c = shift;

    $c->stash->{template} = '/microtomography/javier_bruker_2017.mas';
}

sub microtomography_cicero_stylet_2018 :Path('/microtomography/cicero_stylet_2018') Args(0) {
    my $self = shift;
    my $c = shift;

    $c->stash->{template} = '/microtomography/cicero_stylet_2018.mas';
}

sub microtomography_cicero_alimentarycanal_2018 :Path('/microtomography/cicero_alimentarycanal_2018') Args(0) {
    my $self = shift;
    my $c = shift;

    $c->stash->{template} = '/microtomography/cicero_alimentarycanal_2018.mas';
}

1;
