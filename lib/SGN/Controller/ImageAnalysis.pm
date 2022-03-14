
package SGN::Controller::ImageAnalysis;

use Moose;
use URI::FromHash 'uri';
use File::Slurp;
my @lines = read_file("filename", chomp => 1); # will chomp() each line

BEGIN { extends 'Catalyst::Controller' };

sub home : Path('/tools/image_analysis') Args(0) {
    my $self = shift;
    my $c = shift;
    if (!$c->user()) {
        $c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
        return;
    }

    my @image_analysis_logdata;
    if ($c->config->{image_analysis_log}) {
      my $logfile = $c->config->{image_analysis_log};
      @image_analysis_logdata = read_file($logfile, chomp => 1);
    }

    $c->stash->{image_analysis_logdata} = \@image_analysis_logdata;
    $c->stash->{template} = 'tools/image_analysis.mas';
}

1;
