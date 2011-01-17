=head1 NAME

SGN::Controller::Download - serve file downloads

=cut

package SGN::Controller::Download;
use Moose;
use namespace::autoclean;

use File::Basename;

BEGIN { extends 'Catalyst::Controller' }

=head1 PUBLIC ACTIONS

=head2 download_static

Public path: /download/path/to/file/under/site/root.ext

Try to find a file relative to the site root and serve it with the
proper headers to trigger download dialog in the user's browser.

=cut

sub download_static :Path('/download') {
    my ( $self, $c, @path ) = @_;

    my $file = $c->path_to( $c->config->{root},  @path );
    $c->stash->{download_filename} = $file;

    $c->forward('download');
}


=head1 PRIVATE ACTIONS

=head2 reported_download

Private.

Same as download above, but sends an email to the address in the
'bugs_email' conf var.

=cut

sub reported_download :Private {
    my ( $self, $c ) = @_;

    my $info_string = Data::Dump::dump( $c->stash->{download_info} || 'no additional information' );

    # send an email with the information
    $c->stash->{email} = {
        to      => $c->config->{bugs_email},
        from    => 'sgn-reported-downloads@solgenomics.net',
        subject => "File download: ".($c->stash->{download_filename} || '(no filename set)'),
        body    => join( '', map "$_\n",
                         "File       : ".($c->stash->{download_filename} || '(no filename set)'),
                         "User info  : $info_string",
                         $c->view('Email::ErrorEmail')->summary_text($c),
                        ),
    };
    $c->forward('View::Email');

    # serve the downloaded file
    $c->forward('download');
}

=head2 download

Private.

Serves the file named in C<$c-E<gt>stash-E<gt>{download_filename}> to
the user's browser as a download.  C<download_filename> should be an
absolute path.

Sets the Content-disposition response headers appropriate to trigger a
file-download behavior in the client browser. Does NOT set the
content-type, you should do that before forwarding to this
(e.g. C<$c-E<gt>res-E<gt>content_type('text/plain')>).

=cut

sub download :Private {
    my ( $self, $c ) = @_;

    my $file = $c->stash->{download_filename};

    $c->throw_404 unless defined( $file ) && -e $file;

    $c->forward('set_download_headers');
    $c->serve_static_file( $file );
}


=head2 set_download_headers

Private.

Sets the Content-disposition response headers appropriate to trigger a
file-download behavior in the client browser.  If
C<$c-E<gt>stash-E<gt>{download_filename}> is set, will set the download's
filename to the basename of that path.

Does NOT set the
content-type, you should do that before forwarding to this
(e.g. C<$c-E<gt>res-E<gt>content_type('text/plain')>).

=cut

sub set_download_headers :Private {
    my ( $self, $c ) = @_;

    $c->res->headers->push_header( 'Content-Disposition' => 'attachment' );
    if( my $bn = basename( $c->stash->{download_filename} ) ) {
        $c->res->headers->push_header( 'Content-Disposition' => "filename=$bn" );
    }
}


1;
