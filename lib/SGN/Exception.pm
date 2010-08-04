package SGN::Exception;
use Moose;

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

has 'public_message' => (
    is  => 'ro',
    isa => 'Maybe[Str]',
   );

has 'developer_message' => (
    is  => 'ro',
    isa => 'Maybe[Str]',
   );

has 'explanation' => (
    is  => 'ro',
    isa => 'Maybe[Str]',
   );

has 'title' => (
    is  => 'ro',
    isa => 'Maybe[Str]',
   );

has 'is_server_error' => (
    is  => 'ro',
    isa => 'Bool',
    default => 1,
);

has 'is_client_error' => (
    is  => 'ro',
    isa => 'Bool',
    default => 0,
);

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

has 'notify' => (
    is  => 'ro',
    isa => 'Bool',
    lazy_build => 1,
   ); sub _build_notify {
       shift->is_server_error
   }

around 'BUILDARGS' => sub {
    my ($orig,$class,%args) = @_;
    $args{developer_message} ||= $args{message};

    return $class->$orig( %args );
};

sub stringify {
    my $self = shift;
    return
        ($self->public_message || '') . "\n"
        .'Developer message: '
        .($self->developer_message || 'none');
}

__PACKAGE__->meta->make_immutable;
1;
