=head1 NAME

SGN::Role::Site::Exceptions - Moose role for Catalyst-based site
exception handling

=cut

package SGN::Role::Site::Exceptions;
use Moose::Role;
use namespace::autoclean;

use List::MoreUtils qw/ part /;
use Scalar::Util;

use SGN::Exception;

requires 'finalize_error';

$SIG{ __DIE__ } = sub {
    return if blessed $_[ 0 ];
    SGN::Exception->throw( developer_message => join '', @_ );
};

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
                 is_error => 0, #< is not really an error, more of a message
               );

=cut

sub throw {
    my $self = shift;
    if( @_ > 1 ) {
        my %args = @_;
        #$args{public_message} ||= delete $args{message};
        die SGN::Exception->new( %args );
    } else {
        die @_;
    }
}


sub finalize_error {
    my ( $self ) = @_;

    local $SIG{__DIE__} = \&Carp::confess;

    my @errors = @{ $self->error };

    # render the message page for all the errors
    $self->stash->{template}  = '/site/error/exception.mas';
    $self->stash->{exception} = \@errors;
    $self->view('Mason')->process( $self );

    my ($no_notify, $notify) =
        part { $_->notify ? 1 : 0 } @errors;

};


1;

