package SGN;
use Moose;
use namespace::autoclean;

use Catalyst::Runtime 5.80;

# Set flags and add plugins for the application
#
#         -Debug: activates the debug mode for very useful log messages
#   ConfigLoader: will load the configuration from a Config::General file in the
#                 application's home directory
# Static::Simple: will serve static files from the application's root
#                 directory

use Catalyst qw/
    -Debug
    ConfigLoader
    Static::Simple
/;

extends 'Catalyst';

with qw(
        SGN::Role::Site::Config
        SGN::Role::Site::DBConnector
        SGN::Role::Site::DBIC
       );

our $VERSION = '0.01';
$VERSION = eval $VERSION;

# Start the application
__PACKAGE__->setup();

=head1 NAME

SGN - Catalyst based application

=head1 SYNOPSIS

    script/sgn_server.pl

=head1 DESCRIPTION

[enter your description here]

=head1 SEE ALSO

L<SGN::Controller::Root>, L<Catalyst>

=head1 AUTHOR

Robert Buels,,,

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
