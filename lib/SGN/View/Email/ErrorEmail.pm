package SGN::View::Email::ErrorEmail;
use Moose;
use Moose::Util::TypeConstraints;

use Data::Dump ();
use Data::Visitor::Callback;

=head1 NAME

SGN::View::Email::ErrorEmail - Email View for SGN

=head1 DESCRIPTION

View for sending error emails from SGN.

=cut

BEGIN { extends 'SGN::View::Email' }

before 'process' => sub {
    my ($self, $c) = @_;

    # convert the notify_errors stash key into an email stash key for
    # the generic email view
    $c->stash->{email} = {
        body => $self->_email_body( $c ),
       };

};

sub _email_body {
    my ( $self, $c ) = @_;
    my $error_num = 1;
    return join '',

        # the errors
        "==== Error(s) ====\n",
        ( map { $error_num++.".  $_\n" } @{$c->stash->{email_errors}} ),

        # all the necessary debug information
        ( map { ("\n==== $_->[0] ====\n", $_->[1], "\n") } $self->dump_these_strings( $c ) );

}

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

{ my $sc = subtype as 'ArrayRef';
  coerce $sc, from 'Str', via { [ split ] };
  has 'dump_skip_class' => (
    is      => 'ro',
    isa     => $sc,
    coerce  => 1,
    default => sub { ['Catalyst'] },
   );
}

has 'dump_visitor_args' => (
    is      => 'ro',
    isa     => 'HashRef',
    default => sub { {} },
);

=head1 METHODS

=head2 dump_these_strings( $c )

Get a list like
C<['Request', 'string dump'], ['Stash', 'string dump'], ...>
for use in debugging output.

=cut

sub dump_these_strings {
    my ($self,$c) = @_;
    return
        map [ $_->[0], Data::Dump::dump( $self->filter_object_for_dump( $_->[1] ) ) ],
        $c->dump_these;
}

=head2 filter_object_for_dump( $object )

Return a filtered copy of the given object.

=cut

sub filter_object_for_dump {
    my ( $self, $object ) = @_;
    $self->debug_filter_visitor->visit( $object );
}

=head1 AUTHOR

Robert Buels

=cut

1;
