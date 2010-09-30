package SGN::View::Email;
use Moose;

BEGIN { extends 'Catalyst::View::Email' }

__PACKAGE__->config(
    stash_key => 'email'
);

=head1 NAME

SGN::View::Email - Email View for SGN

=head1 DESCRIPTION

View for sending email from SGN. 

=head1 AUTHOR

Robert Buels,,,

=head1 SEE ALSO

L<SGN>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
