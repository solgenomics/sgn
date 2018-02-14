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
        if( defined $args{is_error}  && ! $args{is_error} ) {
            $args{is_server_error} = 0;
            $args{is_client_error} = 0;
        }
        my $exception = SGN::Exception->new( %args );
        if( $exception->is_server_error ) {
            die $exception;
        } else {
            $self->_set_exception_response( $exception );
            $self->detach;
        }
    } else {
        die @_;
    }
}

=head1 throw_client_error

  Usage: $c->throw_client_error(
            public_message => 'There was a special error',
            developer_message => 'the frob was not in place',
            notify => 0,
                  );
  Desc : creates and throws an L<SGN::Exception> with the given attributes.
  Args : key => val to set in the new L<SGN::Exception>,
         or if just a single argument is given, just calls die @_
  Ret  : nothing.
  Side Effects: throws an exception and renders it for the client
  Example :

      $c->throw_client_error('foo');

      #equivalent to $c->throw( public_message => 'foo', is_client_error => 1 );

=cut

sub throw_client_error {
    my ($self,%args) = @_;
    $self->throw( is_client_error => 1, %args);
}

=head2 throw_404

one arg, the context object.

Goes through some logic to figure out some things about the request,
then throws an exception that will display a 404 error page.

=cut

sub throw_404 {
    my ( $c, $message ) = @_;

    $message ||= 'Resource not found.';
    $message .= '.' unless $message =~ /\.\s*$/; #< add a period at the end if the message does not have one

    $c->log->debug("throwing 404 error ('$message')") if $c->debug;

    my %throw = (
            title => '404 - not found',
            http_status => 404,
            public_message => "$message  We apologize for the inconvenience.",
           );

    # not sure if this logic works if we run under Ambikon
    my $self_uri  = $c->uri_for('/');
    my $our_fault;
    if (defined($c->req->referer())) { 
	$our_fault = $c->req->referer() =~ /$self_uri/;
    }
    if( $our_fault ) {
        $throw{is_server_error} = 1;
        $throw{is_client_error} = 0;
        $throw{notify} = 0; # was 1 - but don't send these emails - too voluminous - and the above logic probably does not work correctly under Ambikon
        $throw{developer_message} = "404 error seems to be our fault, referrer is '".$c->req->referer."'";
    } else {
        $throw{public_message}  .= ' If you reached this page from a link on another site, you may wish to inform them that the link is incorrect.';
        $throw{is_client_error} = 1;
        $throw{is_server_error} = 0;
        $throw{notify} = 0;
        $throw{developer_message} = "404 is probably not our fault.  Referrer is '".($c->req->referer || '')."'";
    }

    $c->log->debug( $throw{developer_message} ) if $c->debug;

    $c->throw( %throw );
}

# convert all the errors to objects if they are not already
sub _error_objects {
    my $self = shift;

    return map $self->_coerce_to_exception( $_ ),
           @{ $self->error };
}

sub _coerce_to_exception {
    my ( $self, $thing ) = @_;
    return $thing if  blessed($thing) && $thing->isa('SGN::Exception');
    return SGN::Exception->new( message => "$thing" );
}


sub _set_exception_response {
    my $self = shift;
    my @exceptions = map $self->_coerce_to_exception($_), @_;

    # render the message page for all the errors
    $self->stash({
        template         => '/site/error/exception.mas',

        exception        => \@exceptions,
        show_dev_message => !$self->get_conf('production_server'),
        contact_email    => $self->config->{feedback_email},
    });

    $self->res->content_type('text/html');

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
    $self->forward('/insert_collected_html');

    # set our http status to the most severe error we have
    my ( $worst_status ) =
        sort { $b <=> $a }
        map $_->http_status,
        @exceptions;

    $self->res->status( $worst_status );

    return 1;
}

around 'finalize_error' => sub {
    my ( $orig, $self ) = @_;

    $self->_set_exception_response( @{ $self->error } );

    # now decide which errors to actually notify about, and notify about them
    my ($no_notify, $notify) =
        part { ($_->can('notify') && !$_->notify) ? 0 : 1 } $self->_error_objects;
    $_ ||= [] for $no_notify, $notify;

    if( @$notify && $self->config->{production_server} ) {
        $self->stash->{email_errors} = $notify;
        ####supress sgn-bugs emails#####
        #try {
        #    $self->view('Email::ErrorEmail')->process( $self )
        #} catch {
        #    $self->log->error("Failed to send error email! Error was: $_");
        #    push @{$self->error}, $_;
        #};
    }

    my @server_errors = grep $_->is_server_error, $self->_error_objects;

    if( $self->debug && @server_errors && ! $self->config->{production_server} ) {
        my $save_status = $self->res->status;
        @{ $self->error } = @server_errors;
        $self->$orig();
        $self->res->status( $save_status ) if $save_status;
    }

    $self->clear_errors;
};



1;

