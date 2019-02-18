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

use JSON;
use File::Slurp;
use Data::Dumper;

BEGIN { extends 'Catalyst::Controller' }

__PACKAGE__->config(
    namespace       => 'js',
    js_path => SGN->path_to('js/build'),
    dependency_json_path => SGN->path_to('js/build/mapping.json'),
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
   has 'dependency_json_path' => (
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

=head2 get_js_module_dependencies

=cut

my $js_module_dependencies = {};
my $js_module_dependencies_modtime = 0;
sub get_js_module_dependencies :Private {
    my ( $self, $names ) = @_;

    my ( $modtime ) = (stat( $self->dependency_json_path->[0] ))[9];
    if( ! $js_module_dependencies_modtime || $js_module_dependencies_modtime < $modtime) {
        $js_module_dependencies = decode_json(read_file($self->dependency_json_path->[0]));
        $js_module_dependencies_modtime = $modtime;
    } 
    
    my $result = {
        files => [],
        legacy => []
    };
    
    # print Dumper $names;
    # print Dumper $js_module_dependencies;
    
    for my $n (@$names) {
        if (exists $js_module_dependencies->{$n}){
            push @{$result->{files}}, @{$js_module_dependencies->{$n}->{files}};
            push @{$result->{legacy}}, @{$js_module_dependencies->{$n}->{legacy}};
        }
    }
    
    # print Dumper $result;
    
    return $result;
}

=head2 resolve_javascript_classes

=cut

sub resolve_javascript_classes :Private {
    my ( $self, $c ) = @_;

    my $jsan_classes = $c->stash->{jsan_classes};
    my $js_modules = $c->stash->{js_modules};
    
    my $module_deps = $self->get_js_module_dependencies($js_modules);
    push @{ $jsan_classes }, @{$module_deps->{legacy}};

    my @jsan_deps = uniq @$jsan_classes; #< do not sort, load order might be important
    for (@jsan_deps) {
        s/\.js$//;
        s!\.!/!g;
    }
    # if prototype is present, move it to the front to prevent it
    # conflicting with jquery
    my $prototype_idx = first_index { /Prototype$/i } @jsan_deps;
    if( $prototype_idx > -1 ) {
        my ($p) = splice @jsan_deps, $prototype_idx, 1;
        unshift @jsan_deps, $p;
    }

    # add in JSAN.use dependencies
    my @deps = $self->_resolve_jsan_dependencies( \@jsan_deps );
    
    for my $dep (@{$module_deps->{files}}) {
        push @deps, File::Spec->catfile( "/js/build/", $dep )
    }

    $c->stash->{js_uris} = \@deps;
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
