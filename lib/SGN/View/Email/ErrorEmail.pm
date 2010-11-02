package SGN::View::Email::ErrorEmail;
use Moose;
use Moose::Util::TypeConstraints;

use Data::Dump ();
use Data::Visitor::Callback;

use Socket;

=head1 NAME

SGN::View::Email::ErrorEmail - Email View for SGN

=head1 DESCRIPTION

View for sending error emails from SGN.  Errors to email should be an
arrayref of strings in C<$c-E<gt>stash-E<gt>{email_errors}>.

=cut

BEGIN { extends 'SGN::View::Email' }

before 'process' => sub {
    my ($self, $c) = @_;

    # convert the notify_errors stash key into an email stash key for
    # the generic email view
    $c->stash->{email} = $self->make_email( $c );

    $c->log->debug('sending error email to '.$c->stash->{email}->{to}) if $c->debug;
};

=head1 ATTRIBUTES

=head2 debug_filter_visitor

The L<Data::Visitor::Callback> object being used for filtering.  Can
be replaced with your own L<Data::Visitor> subclass if desired.

=cut

has 'debug_filter_visitor' => (
    is => 'rw',
    isa => 'Data::Visitor',
    lazy_build => 1,
   );
sub _build_debug_filter_visitor {
    my ($self) = @_;

    return Data::Visitor::Callback->new(

        # descend into objects also
        object => 'visit_ref',

        # render skip_class option as visitor args
        ( map {
            my $class = $_;
            $class => sub { shift; '('.ref(shift)." object skipped, isa $class)" }
         } @{ $self->dump_skip_class }
        ),

        #render any other visitor args
        %{ $self->dump_visitor_args },

       );
}

=head2 dump_skip_class

One or more class names to filter out of objects to be dumped.  If an
object is-a one of these classes, the dump filtering will replace
the object with a string "skipped" message.

Can be either an arrayref or a whitespace-separated list of class names.

Default: "Catalyst", which will filter out Catalyst context objects.

=cut

{ my $sc = subtype as 'ArrayRef';
  coerce $sc, from 'Str', via { [ split ] };
  has 'dump_skip_class' => (
    is      => 'ro',
    isa     => $sc,
    coerce  => 1,
    default => sub { ['Catalyst'] },
   );
}

=head2 dump_visitor_args

Hashref of additional constructor args passed to the
L<Data::Visitor::Callback> object used to filter the objects for
dumping.  Can be used to introduce nearly any kind of additional
filtering desired.

Example:

   # replace all scalar values in dumped objects with "chicken"
   DebugFilter => {
      visitor_args => {
         value => sub { 'Chicken' },
      },
   }

=cut

has 'dump_visitor_args' => (
    is      => 'ro',
    isa     => 'HashRef',
    default => sub { {} },
);

=head2 reverse_dns

Boolean, default true.

If set, attempts to do a reverse DNS lookup to
resolve the hostname of the client.

=cut

has 'reverse_dns' => (
    is      => 'ro',
    isa     => 'Bool',
    default => 1,
   );

=head1 METHODS

=head2 make_email( $c )

Returns a hashref of error email information, suitable for rendering
with L<Catalyst::View::Email>.

=cut

sub make_email {
    my ( $self, $c ) = @_;
    my $error_num = 1;

    my $type = ( grep $_->is_server_error, @{$c->stash->{email_errors}} ) ? 'E' : 'NB';

    my $body = join '',
        # the errors
        "==== Error(s) ====\n\n",
        ( map { $error_num++.".  $_\n" } @{$c->stash->{email_errors}} ),

        # all the necessary debug information
        ( map { ("\n==== $_->[0] ====\n\n", $_->[1], "\n") } $self->dump_these_strings( $c ) );

    return {
        to      => $self->default->{to},
        from    => $self->default->{from},
        subject => '['.$c->config->{name}."]($type) ".$c->req->uri->path_query,
        body    => $body,
    };

}


=head2 dump_these_strings( $c )

Get a list like
C<['Request', 'string dump'], ['Stash', 'string dump'], ...>
for use in debugging output.

These are filtered, suitable for debugging output.

=cut

sub dump_these_strings {
    my ($self,$c) = @_;
    return
        [ 'Summary', $self->summary_text( $c ) ],
        map [ $_->[0], Data::Dump::dump( $self->filter_object_for_dump( $_->[1] ) ) ],
        $c->dump_these;
}

# SGN-specific filtering, removing db passwords and cookie encryption
# strings from error email output
around 'dump_these_strings' => sub {
    my $orig = shift;
    my $self = shift;
    my ($c) = @_;

    my @ret = $self->$orig(@_);

    my @remove_strings =
        map  { Data::Dump::dump( $_ ) }
        grep { $_ }
        (
            @{$c->config}{qw{ cookie_encryption_key dbpass }},
            ( map $_->{password}, values %{$c->config->{DatabaseConnection} || {}} ),
        );

    for my $ret ( @ret ) {
        for my $redact ( @remove_strings ) {
            $ret->[1] =~ s/$redact/"<redacted>"/g;
        }
    }

    return @ret;
};


=head2 filter_object_for_dump( $object )

Return a filtered copy of the given object.

=cut

sub filter_object_for_dump {
    my ( $self, $object ) = @_;
    $self->debug_filter_visitor->visit( $object );
}

=head2 summary_text( $c )

Get an un-indented block of text of the most salient features of the
error.  Example:

  Path_Query: /path/to/request?foo=bar&baz=boo
  Process ID: <PID of the serving process>
  User-Agent: <user agent string>
  Referrer:   <referrer string>

=cut

sub summary_text {
    my ( $self, $c ) = @_;

    my $client_ip       = $c->req->address;
    my $client_hostname = $self->reverse_dns
        ? ' ('.(gethostbyaddr( inet_aton( $client_ip ), AF_INET ) || 'reverse DNS lookup failed').')'
        : '';

    no warnings 'uninitialized';
    return join '', map "$_\n", (
      'Request    : '.$c->req->method.' '.$c->req->uri,
      'User-Agent : '.$c->req->user_agent,
      'Referrer   : '.$c->req->referer,
      'Client Addr: '.$client_ip.$client_hostname,
      'Process ID : '.$$,
     );
}

=head1 AUTHOR

Robert Buels

=cut

1;
