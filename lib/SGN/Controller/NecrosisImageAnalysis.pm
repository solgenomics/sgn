
package SGN::Controller::NecrosisImageAnalysis;

use Moose;

BEGIN { extends 'Catalyst::Controller' };

sub home : Path('/tools/necrosis_image_analysis') Args(0) { 
    my $self = shift;
    my $c = shift;
    $c->stash->{template} = 'tools/necrosis_image_analysis.mas';
}

1;
