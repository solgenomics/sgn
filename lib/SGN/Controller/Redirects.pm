package SGN::Controller::Redirects;
use Moose;

BEGIN { extends 'Catalyst::Controller' }

=head1 CONFIGURATION

=head2 paths

Hashref of specific paths to do redirects to.  Merged with the
hardcoded paths in this controller.

=cut

# put specific redirect paths here
my %paths = (

    # redirects from refactoring the search controller
    qw(
        /search/qtl                            /search/phenotypes/qtl
        /trait/search                          /search/phenotypes/traits
        /search/trait                          /search/phenotypes/traits
        /search/phenotype                      /search/phenotypes/stock
        /search/phenotype_qtl_trait            /search/phenotypes/stock

        /search/unigene                        /search/transcripts/unigene
        /search/unigenes                       /search/transcripts/unigene
        /search/platform                       /search/expression/platform
        /search/template_experiment_platform   /search/expression/template
        /search/experiment                     /search/expression/experiment
        /search/est                            /search/transcripts/est
        /search/ests                           /search/transcripts/est
        /search/EST                            /search/transcripts/est
        /search/ESTs                           /search/transcripts/est
        /search/est_library                    /search/transcripts/est_library
        /search/library                        /search/transcripts/est_library
        /search/bacs                           /search/genomic/clones
        /search/BACs                           /search/genomic/clones
        /search/marker                         /search/markers
      ),

    # qtl redirects
    qw(
        /qtl/population           /search/phenotypes/qtl
        /qtl/search               /search/phenotypes/qtl
        /search/qtl/help          /qtl/search/help
        /qtl/guide.pl             /qtl/submission/guide
        /phenome/qtl_form.pl      /qtl/form
        /qtl/submit               /qtl/form
        /qtl/index.pl             /search/phenotypes/qtl
        /qtl                      /search/phenotypes/qtl
        /qtl/                     /search/phenotypes/qtl
    ),

    # genomes redirects
    qw(
        /genomes/index.pl                            /genomes
        /genomes/Solanum_pimpinellifolium            /organism/Solanum_pimpinellifolium/genome
        /genomes/Solanum_pimpinellifolium/           /organism/Solanum_pimpinellifolium/genome
        /genomes/Solanum_pimpinellifolium/index.pl   /organism/Solanum_pimpinellifolium/genome
        /genomes/Solanum_pimpinellifolium.pl         /organism/Solanum_pimpinellifolium/genome

        /genomes/Solanum_lycopersicum                 /organism/Solanum_lycopersicum/genome
        /genomes/Solanum_lycopersicum/                /organism/Solanum_lycopersicum/genome
        /genomes/Solanum_lycopersicum/index.pl        /organism/Solanum_lycopersicum/genome
        /genomes/Solanum_lycopersicum.pl              /organism/Solanum_lycopersicum/genome
        /genomes/Solanum_lycopersicum/genome_data.pl  /organism/Solanum_lycopersicum/genome
        /tomato/genome_data.pl                        /organism/Solanum_lycopersicum/genome
    ),
);

# also can get redirect paths from the configuration
has 'paths' => (
    is => 'rw',
    default => sub { {} },
);

# these are merged at construction time, with the configured paths
# overriding hardcoded paths
sub BUILD {
    my $self = shift;
    $self->paths({
        %paths,
        %{$self->paths},
    });
}

sub find_redirect : Private {
    my ($self, $c) = @_;
    my $path = $c->req->path;
    my $query = $c->req->uri->query || '';
    $query = "?$query" if $query;

    $c->log->debug("searching for redirects, path='$path' query='$query'") if $c->debug;

    # if the path has multiple // in it, collapse them and redirect to
    # the result
    if(  $path =~ s!/{2,}!/!g ) {
        $c->log->debug("redirecting multi-/ request to /$path$query") if $c->debug;
        $c->res->redirect( "/$path$query", 301 );
        return 1;
    }

    # try an internal redirect for index.pl files if the url has not
    # already been found and does not have an extension
    if( $path !~ m|\.\w{2,4}$| ) {
        if( my $index_action = $self->_find_cgi_action( $c, "$path/index.pl" ) ) {
            $c->log->debug("redirecting to action $index_action") if $c->debug;
            my $uri = $c->uri_for_action($index_action, $c->req->query_parameters)
                        ->rel( $c->uri_for('/') );
            $c->res->redirect( "/$uri", 302 );
            return 1;
        }
    }

    # redirect away from cgi-bin URLs
    if( $path =~ s!cgi-bin/!! ) {
        $c->log->debug("redirecting cgi-bin url to /$path$query") if $c->debug;
        $c->res->redirect( "/$path$query", 301 );
        return 1;
    }

    # redirect any explicitly-added paths
    if( my $re = $self->paths->{"/$path"} ) {
        $c->res->redirect( $re, 301 );
        return 1;
    }

    return 0;
}

############# helper methods ##########

sub _find_cgi_action {
    my ($self,$c,$path) = @_;

    $path =~ s!/+!/!g;
     my $cgi = $c->controller('CGI')
         or return;

    my $index_action = $cgi->cgi_action_for( $path )
        or return;

    $c->log->debug("found CGI index action '$index_action'") if $c->debug;

    return $index_action;
}


1;

