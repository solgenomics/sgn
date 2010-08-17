package TestAppErrors;

use Moose;
extends 'Catalyst';

__PACKAGE__->config( default_view => 'Mason' );
__PACKAGE__->setup;

# overriding a few crucial parts to pass errors directly
# to the caller. Don't do this at home!

sub handle_request {
    my $class = shift;
    my $c = $class->prepare( @_ );
    $c->dispatch;
    $c->finalize;
}

sub finalize_error {
  my $self = shift;
  die @{ $self->error };
}

1;
