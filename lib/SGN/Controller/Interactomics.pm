# goes into lib/SGN/Controller/CytoScape.pm


package SGN::Controller::Interactomics;

use Moose;
use URI::FromHash 'uri';

BEGIN { extends 'Catalyst::Controller'; }



sub interactomics :Path("/tools/interactomics") :Args(0) { 
    my ($self, $c) = @_;

    
    #my $filename = $c->req->param("filename");

    $c->stash->{template} = '/interactomics/index.mas';

    #$c->stash->{filename} = $filename;

}

1;
