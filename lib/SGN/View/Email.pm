package SGN::View::Email;
use Moose;
use namespace::autoclean;
use Data::Dump 'dump';

BEGIN { extends 'Catalyst::View::Email' }

__PACKAGE__->config(
    stash_key => 'email'
);

around 'process' => sub {
    my $orig = shift;
    my $self = shift;
    my ($c) = @_;

    if( $c->can('test_mode') && $c->test_mode ) {
        $c->log->debug("skipping email send, since running in test mode.  email:\n".dump( $c->stash->{ $self->stash_key } ));
    } else {
        $self->$orig( @_ );
    }
};

=head1 NAME

SGN::View::Email - Email View for SGN

=head1 DESCRIPTION

View for sending email from SGN.  Nearly-bare subclass of L<Catalyst::View::Email>.

=head1 AUTHOR

Robert Buels

=head1 SEE ALSO

L<SGN>
L<Catalyst::View::Email>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
