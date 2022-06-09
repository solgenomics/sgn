
package SGN::Controller::Search::Cross;

use Moose;

use File::Basename;
use File::Slurp qw | read_file |;
use URI::FromHash 'uri';
use CXGN::Trial::Download;
use DateTime;


BEGIN { extends 'Catalyst::Controller' };

sub search_page : Path('/search/cross') Args(0) {
    my $self = shift;
    my $c = shift;

    my $user = $c->user();
    if (!$user) {
        $c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
        return;
    }

    $c->stash->{template} = '/search/cross.mas';

}


sub search_progenies_using_female : Path('/search/progenies_using_female') Args(0) {
    my $self = shift;
    my $c = shift;

    $c->stash->{template} = '/search/cross/progeny_search_using_female.mas';

}


sub search_progenies_using_male : Path('/search/progenies_using_male') Args(0) {
    my $self = shift;
    my $c = shift;

    $c->stash->{template} = '/search/cross/progeny_search_using_male.mas';

}


sub search_crosses_using_female : Path('/search/crosses_using_female') Args(0) {
    my $self = shift;
    my $c = shift;

    $c->stash->{template} = '/search/cross/cross_search_using_female.mas';

}


sub search_crosses_using_male : Path('/search/crosses_using_male') Args(0) {
    my $self = shift;
    my $c = shift;

    $c->stash->{template} = '/search/cross/cross_search_using_male.mas';

}


sub download_cross_entries : Path('/search/download_cross_entries') Args(0) {
    my $self = shift;
    my $c = shift;

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $user = $c->user();
    if (!$user) {
        $c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
        return;
    }

    my $cross_property_db = $c->config->{cross_property_db};
    my $file_format = "xls";

    my $time = DateTime->now();
    my $timestamp = $time->ymd();
    my $dir = $c->tempfiles_subdir('download');
    my $temp_file_name = "cross_entries". "XXXX";
    my $rel_file = $c->tempfile( TEMPLATE => "download/$temp_file_name");
    $rel_file = $rel_file . ".$file_format";
    my $tempfile = $c->config->{basepath}."/".$rel_file;
#    print STDERR "TEMPFILE : $tempfile\n";

    my $download = CXGN::Trial::Download->new({
        bcs_schema => $schema,
        filename => $tempfile,
        format => 'CrossEntriesXLS',
    });

    if ($cross_property_db) {
        $download->set_cross_property_db($cross_property_db);
    }

    my $error = $download->download();

    my $file_name = "cross_entries" . "_" . "$timestamp" . ".$file_format";
    $c->res->content_type('Application/'.$file_format);
    $c->res->header('Content-Disposition', qq[attachment; filename="$file_name"]);

    my $output = read_file($tempfile);

    $c->res->body($output);


}



1;
