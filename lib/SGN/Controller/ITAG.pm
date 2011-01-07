=head1 NAME

SGN::Controller::ITAG - actions related to ITAG things

=cut

package SGN::Controller::ITAG;
use Moose;
use namespace::autoclean;

use CXGN::ITAG::Release;

BEGIN { extends 'Catalyst::Controller' }

=head1 PUBLIC ACTIONS

=cut

sub list_releases :Path('/itag/list_releases') :Args(0) {
    my ( $self, $c ) = @_;

    $c->stash->{itag_releases} = [ CXGN::ITAG::Release->find ];

    $c->stash->{template} = '/itag/list_releases.mas';
    $c->forward('View::Mason');
}

sub list_release_files :Chained('get_release') :PathPart('list_files') :Args(0) {
    my ( $self, $c ) = @_;

    $c->stash->{template} = '/itag/list_release_files.mas';
}


sub download_release_file :Chained('get_release') :PathPart('download') :Args(1) {
    my ( $self, $c, $file_tag ) = @_;

    # get and validate the name, email, and organization from the post data
    my $name = $c->req->params->{name};
    $name && length($name) > 8
        or $c->throw( public_message => 'Must provide a valid name to download ITAG bulk files.', is_client_error => 1 );
    my $email = $c->req->params->{email};
    $email && $email =~ /^[^@]+@[^@]+$/
        or $c->throw( public_message => 'Must provide a real email address to download ITAG bulk files.', is_client_error => 1 );

    my $organization = $c->req->params->{organization};

    # stash them for the reported_download action
    $c->stash->{download_info} = {
        name => $name,
        email => $email,
        organization => $organization,
    };

    $c->stash->{download_filename} = $c->stash->{itag_release}->get_file_info( $file_tag )->{file};

    $c->forward( '/download/reported_download' );
}



# /itag/release/2/download/file_shortname
sub get_release :Chained('/') :PathPart('itag/release') :CaptureArgs(1) {
    my ( $self, $c, $releasenum ) = @_;

    # get and stash the itag release object, throwing if not found
    ($c->stash->{itag_release}) = CXGN::ITAG::Release->find( releasenum => $releasenum )
        or $c->throw_404("Release not found");
}




1;
