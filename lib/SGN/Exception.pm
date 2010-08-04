package SGN::Exception;
use Moose;

# make catalyst use this exception class
{ no warnings 'once';
  $Catalyst::Exception::CATALYST_EXCEPTION_CLASS = __PACKAGE__;
}

use overload
  (
   q[""] => 'stringify',
   fallback => 1,
  );


has 'public_message' => (
    is  => 'ro',
    isa => 'Maybe[Str]',
   );

{ no warnings 'once';
  *message = \&public_message;
}

has 'developer_message' => (
    is  => 'ro',
    isa => 'Maybe[Str]',
   );

has 'explanation' => (
    is   => 'ro',
    isa  => 'Maybe[Str]',
   );

has 'title' => (
    is  => 'ro',
    isa => 'Maybe[Str]',
   );

has 'is_error' => (
    is => 'ro',
    isa => 'Bool',
    default => 1,
);

has 'notify' => (
    is => 'ro',
    isa => 'Bool',
    lazy_build => 1,
   ); sub _build_notify {
       shift->is_error
   }

around 'BUILDARGS' => sub {
    my ($orig,$class,%args) = @_;
    $args{public_message} = $args{message}
        unless defined $args{public_message};

    return $class->$orig(%args);
};

sub stringify {
    my $self = shift;
    return
        ($self->message || '') . "\n"
        .'Developer message: '
        .($self->developer_message || 'none');
}

__PACKAGE__->meta->make_immutable;
1;
