=head1 NAME

SGN::Exception - expressive exception object for web applications

=head1 SYNOPSIS

  die SGN::Exception->new(

    title             => 'Froozle Error',
    public_message    => "Cannot process the froozle.",
    developer_message => "Froozle was '$froozle', path was '$fogbat_path'.",

    http_status       => 406,
    is_server_error   => 1,
    is_client_error   => 0,

    # developers need to be notified that this happened
    notify            => 1,

  );

=head1 DESCRIPTION

The SGN::Exception object is meant to hold a wide variety of
information about the nature of an exception or error condition.
Nearly all the attributes of the exception object are optional.

=cut

package SGN::Exception;
use Moose;
use Scalar::Util ();

# make catalyst use this exception class
{ no warnings 'once';
  $Catalyst::Exception::CATALYST_EXCEPTION_CLASS = __PACKAGE__;
}

with 'Catalyst::Exception::Basic';

use overload
  (
   q[""] => 'stringify',
   fallback => 1,
  );

=head1 ATTRIBUTES

All attributes are read-only.  None are required.

=head2 public_message

String, publicly-visible message for this error.  Should not reveal
details that could have security implications.

=cut

has 'public_message' => (
    is  => 'ro',
    isa => 'Maybe[Str]',
   );

=head2 developer_message

String, private message for developers.  Should be included in error
notifications sent to developers, debug backtraces, etc.

=cut

has 'developer_message' => (
    is  => 'ro',
    isa => 'Maybe[Str]',
   );

#TODO: redundant, deleteme
has 'explanation' => (
    is  => 'ro',
    isa => 'Maybe[Str]',
   );

=head2 title

Optional string, user-visible title for the exception as presented to the user.

=cut

has 'title' => (
    is  => 'ro',
    isa => 'Maybe[Str]',
   );

=head2 is_server_error

Boolean, true if this error indicates a problem on the server side.

Defaults to true most of the time, but defaults to false if
is_client_error is explicitly set to true.

=cut

has 'is_server_error' => (
    is  => 'ro',
    isa => 'Bool',
    default => 1,
);

=head2 is_client_error

Boolean, true if this error indicates a problem on the client side.

Defaults to false most of the time, but default to true if
is_server_error is set and false.

=cut

has 'is_client_error' => (
    is  => 'ro',
    isa => 'Bool',
    default => 0,
);

=head2 http_status

Explicitly set the status code of the HTTP response for this error
condition.

Defaults to 500 (Internal Server Error) if is_server_error is set,
else 400 (Bad Request) if is_client_error is set, or 200 (OK) if
is_client_error and is_server_error are both false.

=cut

has 'http_status' => (
    is  => 'ro',
    isa => 'Int',
    default => sub {
        my $self = shift;
        $self->is_server_error ? 500 :
        $self->is_client_error ? 400 :
                                 200
        },
);

=head2 notify

Flag indicating whether developers should be actively notified that
this exception occurred.

Boolean, defaults to true if is_server_error is set, false otherwise.

=cut

has 'notify' => (
    is  => 'ro',
    isa => 'Bool',
    lazy_build => 1,
   ); sub _build_notify {
       shift->is_server_error
   }

around 'BUILDARGS' => sub {
    my $orig  = shift;
    my $class = shift;
    my %args =  @_ > 1 ? @_ : ( message => @_ );

    $args{developer_message} ||= $args{message};
    $args{message}           ||= $args{developer_message} || $args{public_message} || '(no message)';

    if( defined $args{is_client_error} && !$args{is_client_error} ) {
        $args{is_server_error} = 1 unless defined $args{is_server_error};
    }
    if( defined $args{is_server_error} && !$args{is_server_error} ) {
        $args{is_client_error} = 1 unless defined $args{is_client_error};
    }
    if( $args{is_client_error} && ! defined $args{is_server_error} ) {
        $args{is_server_error} = 0;
    }

    return $class->$orig( %args );
};

=head1 METHODS

=head2 stringify

Return a plaintext string representation of this exception, suitable
for display in consoles and so forth.

=cut

sub stringify {
    my $self = shift;
    return
        ($self->public_message || '') . "\n"
        .'Developer message: '
        .($self->developer_message || 'none');
}

__PACKAGE__->meta->make_immutable;
1;
