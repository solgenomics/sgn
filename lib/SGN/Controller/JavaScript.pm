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

BEGIN { extends 'Catalyst::Controller' }

__PACKAGE__->config(
    namespace       => 'js',
    js_include_path => SGN->path_to('js'),
   );

{
    my $inc = subtype as 'ArrayRef';
    coerce $inc, from 'Defined', via { [$_] };

    has 'js_include_path' => (
        is     => 'ro',
        isa    => $inc,
        coerce => 1,
       );
}

=head1 PUBLIC ACTIONS

=head2 default

Serve a single (minified) javascript file from our js path.

=cut

sub default :Path {
    my ( $self, $c, @args ) = @_;

    my $rel_file = File::Spec->catfile( @args );

    # support caching with If-Modified-Since requests
    my $full_file = File::Spec->catfile( $self->js_include_path->[0], $rel_file );
    my ( $modtime ) = (stat( $full_file ))[9];
    $c->throw_404 unless $modtime && -f _;

    my $ims = $c->req->headers->if_modified_since;
    if( $ims && $modtime && $ims >= $modtime ) {
        $c->res->status( RC_NOT_MODIFIED );
        $c->res->body(' ');
    } else {
        $c->stash->{js} = [ $rel_file ];
        $c->forward('View::JavaScript');
    }
}


=head1 PRIVATE ACTIONS

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
    my $inc_path = $self->js_include_path;
    die "multi-dir js_include_path not yet supported" if @$inc_path > 1;
    my $js_dir = $inc_path->[0];
    -d $js_dir or die "configured js_include_path '$js_dir' does not exist!\n";
    return {
        js_dir     => "$js_dir",
        uri_prefix => '/js',
    };
}
sub new_jsan {
    JSAN::ServerSide->new( %{ shift->_jsan_params } );
}


1;
