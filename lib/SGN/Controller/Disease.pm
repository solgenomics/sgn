package SGN::Controller::Disease;

use Moose;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

SGN::Controller::Disease - show disease pages for CG.org. add subroutines for other pages in disease menu


=cut


sub disease_index :Path('/disease/index') Args(0) {
    my $self = shift;
    my $c = shift;

    $c->stash->{template} = '/disease/index.mas';
}

sub disease_impact :Path('/disease/impact') Args(0) {
    my $self = shift;
    my $c = shift;

    $c->stash->{template} = '/disease/impact.mas';
}

sub disease_links :Path('/disease/links') Args(0) {
    my $self = shift;
    my $c = shift;

    $c->stash->{template} = '/disease/links.mas';
}

sub disease_researchhighlights_index :Path('/disease/researchhighlights/index') Args(0) {
    my $self = shift;
    my $c = shift;

    $c->stash->{template} = '/disease/researchhighlights/index.mas';
}

sub disease_researchhighlights_mann_2018 :Path('/disease/researchhighlights/mann_2018') Args(0) {
    my $self = shift;
    my $c = shift;

    $c->stash->{template} = '/disease/researchhighlights/mann_2018.mas';
}

sub disease_researchhighlights_kruse_2017 :Path('/disease/researchhighlights/kruse_2017') Args(0) {
    my $self = shift;
    my $c = shift;

    $c->stash->{template} = '/disease/researchhighlights/kruse_2017.mas';
}

1;
