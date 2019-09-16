package SGN::Controller::Rootstocks;

use Moose;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

SGN::Controller::Rootstocks - show rootstocks  for CG.org. add subroutines for other pages in rootstocks menu

=cut


sub rootstocks_index :Path('/rootstocks/index') Args(0) {
    my $self = shift;
    my $c = shift;

    $c->stash->{template} = '/rootstocks/index.mas';
}

sub rootstocks_usdablackvalencia :Path('/rootstocks/usdablackvalencia') Args(0) {
    my $self = shift;
    my $c = shift;

    $c->stash->{template} = '/rootstocks/usdablackvalencia.mas';
}

1;
