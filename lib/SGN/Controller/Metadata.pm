package SGN::Controller::Metadata;
use Moose;
use namespace::autoclean;

=head1 NAME

SGN::Controller::Metadata - stuff involving C<CXGN::Metadata>

=head1 ACTIONS

=cut

use File::Spec::Functions 'catfile';

BEGIN { extends 'Catalyst::Controller' }

=head2 download_md_file

Public path: /metadata/file/<file_id>/download

Download a static file pointed to by a
L<CXGN::Metadata::Schema::MdFiles> row.

=cut

sub download_md_file : Chained('get_md_file') PathPart('download') Args(0) {
    my ( $self, $c ) = @_;

    $c->stash->{download_filename} = $c->stash->{md_file}->path;
    $c->forward('/download/download');
}

# chain root (/metadata/file/<file_id>) for doing things with MdFiles
sub get_md_file : Chained('/') PathPart('metadata/file') CaptureArgs(1) {
    my ( $self, $c, $id ) = @_;
    $id += 0;

    $c->stash->{md_file} = $c->dbic_schema('CXGN::Biosource::Schema')
                             ->resultset('MdFiles')
                             ->find({ file_id => $id })
        or $c->throw_404;

}


1;
