package SGN::Controller::Genomes;
use Moose;
use namespace::autoclean;

BEGIN{ extends 'Catalyst::Controller' }

sub view_genome_data : Chained('/organism/find_organism') PathPart('genome') {
    my ( $self, $c ) = @_;

    my $organism = $c->stash->{organism};

    (my $template_name = '/genomes/'.$organism->species.'.mas') =~ s/ /_/g;

    $c->stash->{template} =
        $c->view('Mason')->component_exists( $template_name )
            ? $template_name : '/genomes/default.mas';
}



1;
