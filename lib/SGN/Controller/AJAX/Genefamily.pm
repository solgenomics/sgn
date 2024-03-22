
package SGN::Controller::AJAX::Genefamily;

use Moose;

BEGIN { extends 'Catalyst::Controller::REST'; }

sub browse_families_table :Path('/ajax/tools/genefamily/table') Args(0) {
    my $self = shift;
    my $c = shift;

    my $build = $c->req->param("build");

    my $genefamily_dir = $c->config->{genefamily_dir};
    my $genefamily_format = $c->config->{genefamily_format};

    my $gf = CXGN::Genefamily->new( { genefamily_dir => $genefamily_dir, genefamily_format => $genefamily_format });

    my $data_ref = $gf -> table();
    
    $c->stash->{rest} = { data => $data_ref };

}
    
1;
