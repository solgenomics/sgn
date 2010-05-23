package SGN::Site;
use Moose::Role;

use CXGN::Contact;

use SGN::Exception;

requires 'get_conf', 'forward_to_mason_view';

has 'site_name' => (
    is => 'ro',
    lazy_build => 1,
   ); sub _build_site_name {
       shift->get_conf('project_name')
   }

=head2 error_notify

  Usage: $c->error_notify( 'died', 'omglol it died so hard' );
  Desc : If configured as a production_server, sends an email to the
         development team with the given error message, plus a stack
         backtrace and full information about the current web request.
  Args : error verb (e.g. 'died'), message to send to website developers
  Ret  : nothing
  Side Effects: sends email to development team
  Example:

   $c->error_notify( 'made a little mistake', <<EOM );
  My program made a little mistake. See backtrace and request data below.
  EOM

=cut

sub error_notify {
    my $self       = shift;
    my $error_verb = shift;

    return unless $self->get_conf('production_server');

    $error_verb ||=
      'died or errorpaged (cause of death not indicated by caller)';

    my $developer_message = @_ ? "@_"
        : 'CXGN::Apache::Error::notify called. The error may or may not have been anticipated (no information provided by caller).';

    my $page_name = $ENV{SCRIPT_NAME};

    require CXGN::Contact;
    CXGN::Contact::send_email(
        "$page_name $error_verb",
        "$developer_message\n",
        'bugs_email',
       );

    return;
}

# called by the site-wide $SIG{__DIE__} handler with the same
# arguments as die.  handles exception objects as well as regular
# dies.
sub handle_exception {
    my $self = shift;

    my ( $exception ) = @_;
    my $exception_type =  blessed( $exception );
    if( $exception_type && $exception_type->can('message') && $exception_type->can('title') ) {
        $self->error_notify('threw exception',@_)
            unless $exception->can('notify') && ! $exception->notify;

        $self->forward_to_mason_view( '/site/error/exception.mas', exception => $exception );
    } else {
        $self->error_notify('died',@_) unless $self->_error_is_non_notify( @_ );
    }
}

# takes the whole set of die args, returns true if this error does not
# merit notifying the site maintainers
sub _error_is_non_notify {
    $_[1] =~ /Software caused connection abort/;
}

=head2 throw

  Usage: $c->throw( message => 'There was a special error',
                    developer_message => 'the frob was not in place',
                    notify => 0,
                  );
  Desc : creates and throws an L<SGN::Exception> with the given attributes
  Args : key => val to set in the new L<SGN::Exception>,
         or if just a single argument is given, just calls die @_
  Ret  : nothing.
  Side Effects: throws an exception
  Example :

      $c->throw('foo'); #equivalent to die 'foo';

      $c->throw( title => 'Special Thing',
                 message => 'This is a very strange thing, you see ...',
                 developer_message => 'the froozle was 1, but fog was 0',
                 notify => 0,   #< does not send an error email
                 is_error => 0, #< is not really an error, more of a message
               );

=cut

sub throw {
    my $self = shift;
    if( @_ > 1 ) {
        die SGN::Exception->new( @_ );
    } else {
        die @_;
    }
}


1;

