package SGN::Exception;
use Moose;

use overload
  (
   q[""] => 'stringify',
   fallback => 1,
  );


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


sub stringify {
    my $self = shift;
    return
        $self->message."\n"
        .'Developer message: '
        .($self->developer_message || 'none');
}

__PACKAGE__->meta->make_immutable;
1;
