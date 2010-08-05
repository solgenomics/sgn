=head1 NAME

SGN::Role::Site::Exceptions - Moose role for Catalyst-based site
exception handling

=cut

package SGN::Role::Site::Exceptions;
use Moose::Role;
use namespace::autoclean;

use List::MoreUtils qw/ any part /;
use Scalar::Util qw/ blessed /;
use Try::Tiny;

use SGN::Exception;

requires 'finalize_error', 'error', 'stash', 'view', 'res' ;

$SIG{ __DIE__ } = sub {
    return if blessed $_[ 0 ];
    SGN::Exception->throw( developer_message => join '', @_ );
};

=head2 throw

  Usage: $c->throw( public_message => 'There was a special error',
                    developer_message => 'the frob was not in place',
                    notify => 0,
                  );
  Desc : creates and throws an L<SGN::Exception> with the given attributes.
  Args : key => val to set in the new L<SGN::Exception>,
         or if just a single argument is given, just calls die @_
  Ret  : nothing.
  Side Effects: throws an exception
  Example :

      $c->throw('foo'); #equivalent to die 'foo';

      $c->throw( title => 'Special Thing',
                 public_message => 'This is a very strange thing, you see ...',
                 developer_message => 'the froozle was 1, but fog was 0',
                 notify => 0,   #< does not send an error email
                 is_server_error => 0, #< is not really an error, more of a message
                 is_client_error => 1, #< is not really an error, more of a message
               );

=cut

sub throw {
    my $self = shift;
    if( @_ > 1 ) {
        my %args = @_;
        $args{public_message}  ||= $args{message};
        $args{is_server_error} ||= $args{is_error};
        die SGN::Exception->new( %args );
    } else {
        die @_;
    }
}

around 'finalize_error' => sub {
    my ( $orig, $self ) = @_;

    # render the message page for all the errors
    $self->stash->{template}  = '/site/error/exception.mas';
    $self->stash->{exception} = $self->error;
    unless( $self->view('Mason')->process( $self ) ) {
        # there must have been an error in the message page, try a
        # backup
        $self->stash->{template} = '/site/error/500.mas';
        unless( $self->view('Mason')->process( $self ) ) {
            # whoo, really bad.  set the body and status manually
            $self->res->status(500);
            $self->res->content_type('text/plain');
            $self->res->body(
                'Our apologies, a severe error has occurred.  Please email '
               .($self->config->{feedback_email} || "this site's maintainers")
               .' and report this error.'
              );
        }
    };

    # set our http status to the most severe error we have
    my ($worst_status ) =
        sort { $b <=> $a }
        map _exception_status($_),
        @{ $self->error };

    $self->res->status( $worst_status );

    # now decide which errors to actually notify about
    my ($no_notify, $notify) =
        part { ($_->can('notify') && !$_->notify) ? 0 : 1 } @{ $self->error };

    # if we have any errors that need notification, call the rest of the error plugins
    if( @{ $self->error } = @$notify ) {

        my $save_status = $self->res->status;
        my $save_body   = $self->res->body;
        $self->$orig();

        unless( $self->debug ) {
            $self->res->status( $save_status );
            $self->res->body( $save_body );
        }
    }
};

sub _exception_status {
    my $e = shift;
    return $e->http_status if blessed($e) && $e->can('http_status');
    return 500;
}


1;

