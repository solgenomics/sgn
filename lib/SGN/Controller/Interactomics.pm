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

sub create_jnlp :Path("/tools/interactomics/coffee") :Args(0) {
    my ($self, $c) = @_;
    
    my $codebase = $c->request->base; #creating codebase needed as absolute URL for client's machine.  Will be "solgenomics.net" on live site.
    $c->response->body($codebase);

    my $jnlp_location = $codebase."/CytoScape/cy1.jnlp";

}


1;
