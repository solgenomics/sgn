
package SGN::Controller::BrAPIClient;

use Moose;

BEGIN { extends 'Catalyst::Controller' };

sub register_field_book :Path('/brapi/authorize') QueryParam('return_url') QueryParam('display_name') { #breedbase.org/brapi/authorize?success_url=fieldbook://&display_name=Field%20Book
    my $self = shift;
    my $c = shift;

    my $return_url = $c->request->param( 'return_url' );
    my $display_name = $c->request->param( 'display_name' );

    if (length($return_url) > 0 && length($display_name) > 0) {
        $c->stash->{return_url} = $c->request->param('return_url');
        $c->stash->{display_name} = $c->request->param('display_name');
        $c->stash->{template} = '/brapi/authorize.mas';
    } else {
        $c->throw_404();
    }

}

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
