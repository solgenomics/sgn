=head1 NAME

SGN::Controller::JavaScript - controller for serving minified
javascript

=cut

package SGN::Controller::JavaScript;
use Moose;
use namespace::autoclean;
use Moose::Util::TypeConstraints;

use HTTP::Status;
use File::Spec;

use Fcntl qw( S_ISREG S_ISLNK );

use JSAN::ServerSide;
use List::MoreUtils qw/ uniq first_index /;

use File::Monitor;
use JSON;
use File::Slurp;
use Data::Dumper;

BEGIN { extends 'Catalyst::Controller' }

__PACKAGE__->config(
    namespace       => 'js',
    js_path => SGN->path_to('js/build'),
    js_legacy_path => SGN->path_to('js/legacy')
   );

{
    my $inc = subtype as 'ArrayRef';
    coerce $inc, from 'Defined', via { [$_] };

    has 'js_path' => (
        is     => 'ro',
        isa    => $inc,
        coerce => 1,
       );
    has 'js_legacy_path' => (
        is     => 'ro',
        isa    => $inc,
        coerce => 1,
       );
}

my $modern_js_files = decode_json(read_file(SGN->path_to('js/build/mapping.json')));
my $modern_js_monitor = File::Monitor->new();
$modern_js_monitor->watch('otherfile.txt', sub {
    my ($name, $event, $change) = @_;
    my $json_string = read_file(SGN->path_to('js/build/mapping.json'));
    $modern_js_files = decode_json $json_string;
});
$modern_js_monitor->scan();

=head1 PUBLIC ACTIONS

=head2 default

Serve a single (minified) javascript file from our js path.

=cut

sub default :Path('build') {
    my ( $self, $c, @args ) = @_;

    my $rel_file = File::Spec->catfile( @args );

    # support caching with If-Modified-Since requests
    my $full_file = File::Spec->catfile( $self->js_path->[0], $rel_file );
    my ( $modtime ) = (stat( $full_file ))[9];
    $c->throw_404 unless $modtime && -f _;

    my $ims = $c->req->headers->if_modified_since;
    if( $ims && $modtime && $ims >= $modtime ) {
        $c->res->status( RC_NOT_MODIFIED );
        $c->res->body(' ');
    } else {
        #include sourcemap header if a sourcemap exists
        my $sourcemap_name = $rel_file.".map";
        if( -f File::Spec->catfile( $self->js_path->[0], $sourcemap_name )){
            $c->res->headers->header('SourceMap' => $sourcemap_name);
        }
        $c->res->headers->last_modified( $modtime );
        $c->res->headers->content_type( "application/javascript" );
        $c->res->body(join("",read_file($full_file)));
        $c->res->headers->remove_header('content-length');
    }
}

=head2 legacy

Serve a single (minified) javascript file from our js path.

=cut

sub legacy :Path('legacy') {
    my ( $self, $c, @args ) = @_;

    my $rel_file = File::Spec->catfile( @args );

    # support caching with If-Modified-Since requests
    my $full_file = File::Spec->catfile( $self->js_legacy_path->[0], $rel_file );
    my ( $modtime ) = (stat( $full_file ))[9];
    $c->throw_404 unless $modtime && -f _;

    my $ims = $c->req->headers->if_modified_since;
    if( $ims && $modtime && $ims >= $modtime ) {
        $c->res->status( RC_NOT_MODIFIED );
        $c->res->body(' ');
    } else {
        $c->stash->{js} = [ $rel_file ];
        $c->forward('View::JavaScript::Legacy');
    }
}


=head1 PRIVATE ACTIONS

=head2 resolve_modern_javascript

=cut

sub resolve_modern_javascript :Private {
    my ( $self, $c ) = @_;
    
    $modern_js_monitor->scan();

    my $names = $c->stash->{js_modern}
        or return;
    
    my @names = uniq @$names;
    
    foreach my $name (@names) {
        my @modern_files = $modern_js_files->{$name}->{files};
        my @legacy_classes = $modern_js_files->{$name}->{files};
    }
}

=head2 resolve_javascript_classes

=cut

sub resolve_javascript_classes :Private {
    my ( $self, $c ) = @_;

    my $files = $c->stash->{js_classes}
        or return;

    my @files = uniq @$files; #< do not sort, load order might be important
    for (@files) {
        s/\.js$//;
        s!\.!/!g;
    }
    # if prototype is present, move it to the front to prevent it
    # conflicting with jquery
    my $prototype_idx = first_index { /Prototype$/i } @files;
    if( $prototype_idx > -1 ) {
        my ($p) = splice @files, $prototype_idx, 1;
        unshift @files, $p;
    }

    # add in JSAN.use dependencies
    @files = $self->_resolve_jsan_dependencies( \@files );

    $c->stash->{js_uris} = \@files;
}

########## helpers #########

sub _resolve_jsan_dependencies {
    my ( $self, $files ) = @_;
    local $_; #< stupid JSAN writes to $_

    # resolve JSAN dependencies of these files
    my $jsan = $self->new_jsan;
    for my $f (@$files) {
        $jsan->add( $f );
    }

    return $jsan->uris;
}

has _jsan_params => ( is => 'ro', isa => 'HashRef', lazy_build => 1 );
sub _build__jsan_params {
    my ( $self ) = @_;
    my $inc_path = $self->js_legacy_path;
    die "multi-dir js_legacy_path not yet supported" if @$inc_path > 1;
    my $js_dir = $inc_path->[0];
    -d $js_dir or die "configured js_legacy_path '$js_dir' does not exist!\n";
    return {
        js_dir     => "$js_dir",
        uri_prefix => '/js/legacy',
    };
}
sub new_jsan {
    JSAN::ServerSide->new( %{ shift->_jsan_params } );
}


1;
