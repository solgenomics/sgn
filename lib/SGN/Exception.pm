package SGN::Exception;
use Moose;

has 'message' => (
    is  => 'ro',
    isa => 'Maybe[Str]',
   );

has 'developer_message' => (
    is  => 'ro',
    isa => 'Maybe[Str]',
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


__PACKAGE__->meta->make_immutable;
1;
