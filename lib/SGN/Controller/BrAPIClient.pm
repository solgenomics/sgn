
package SGN::Controller::BrAPIClient;

use Moose;

BEGIN { extends 'Catalyst::Controller' };

sub home : Path('/brapihome/') Args(0) { 
    my $self = shift;
    my $c = shift;
    $c->stash->{template} = 'brapiclient/home.mas';
}

sub germplasm : Path('/brapihome/germplasm') Args(0) {
    my $self = shift;
    my $c = shift;
    $c->stash->{template} = 'brapiclient/germplasm_search.mas';
}

sub phenotyping_handhelds : Path('/brapihome/phenotyping_handhelds') Args(0) {
    my $self = shift;
    my $c = shift;
    $c->stash->{template} = 'brapiclient/phenotyping_handhelds.mas';
}

sub phenotype : Path('/brapihome/phenotype') Args(0) {
    my $self = shift;
    my $c = shift;
    $c->stash->{template} = 'brapiclient/phenotypes_search.mas';
}

sub genotype : Path('/brapihome/genotype') Args(0) {
    my $self = shift;
    my $c = shift;
    $c->stash->{template} = 'brapiclient/markerprofile_allelematrix.mas';
}

sub index : Path('/brapiclient/comparegenotypes') Args(0) { 
    my $self = shift;
    my $c = shift;
    $c->stash->{template} = 'brapiclient/comparegenotypes.mas';
}

1;
