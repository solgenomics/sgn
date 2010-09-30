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
        $args{message}         ||= $args{public_message};
        $args{is_server_error} ||= $args{is_error};
        die Catalyst::Exception->new( %args );
    } else {
        die @_;
    }
}

=head2 throw_404

one arg, the context object.

Goes through some logic to figure out some things about the request,
then throws an exception that will display a 404 error page.

=cut

sub throw_404 {
    my ( $c ) = @_;

    $c->log->debug('throwing 404 error') if $c->debug;

    my %throw = (
            title => '404 - not found',
            http_status => 404,
            public_message => 'Resource not found, we apologize for the inconvenience. ',
           );

    my $self_uri  = $c->uri_for('/');
    my $our_fault = ($c->req->referer || '') =~ /$self_uri/;

    if( $our_fault ) {
        $throw{is_server_error} = 1;
        $throw{notify} = 1;
    } else {
        $throw{public_message}  .= 'You may wish to contact the referring site and inform them of the error.';
        $throw{is_client_error} = 1;
        $throw{notify} = 0;
    }

    $c->throw( %throw );
}

# convert all the errors to objects if they are not already
sub _error_objects {
    my $self = shift;

    return
        map {
            blessed($_) && $_->isa('SGN::Exception') ? $_ : SGN::Exception->new( message => "$_" )
        } @{ $self->error };
}

around 'finalize_error' => sub {
    my ( $orig, $self ) = @_;

    # render the message page for all the errors
    $self->stash({
        template         => '/site/error/exception.mas',

        exception        => [ $self->_error_objects ],
        show_dev_message => !$self->get_conf('production_server'),
        contact_email    => $self->config->{feedback_email},
    });
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

    # insert a JS pack in the error output if necessary
    $self->res->content_type('text/html');
    $self->forward('/js/insert_js_pack_html');


    # set our http status to the most severe error we have
    my ($worst_status ) =
        sort { $b <=> $a }
        map $_->http_status,
        $self->_error_objects;

    $self->res->status( $worst_status );

    # now decide which errors to actually notify about, and notify about them
    my ($no_notify, $notify) =
        part { ($_->can('notify') && !$_->notify) ? 0 : 1 } $self->_error_objects;
    $_ ||= [] for $no_notify, $notify;

    if( @$notify && $self->config->{production_server} ) {
        $self->stash->{email_errors} = $notify;
        try {
            $self->view('Email::ErrorEmail')->process( $self )
        } catch {
            $self->log->error("Failed to send error email! Error was: $_");
            push @{$self->error}, $_;
        };
    }

    my @server_errors = grep $_->is_server_error, $self->_error_objects;
    $self->clear_errors;

    if( $self->debug && ! $self->config->{production_server} ) {
        @{ $self->error } = @server_errors;
        $self->$orig();
    }
};



1;

