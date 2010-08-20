package SGN::Devel::lib_relative;

=head1 NAME

SGN::Devel::lib_relative - like lib.pm, but also accepts paths
relative to the base directory of the distribution.  Works for
absolute paths too.

=head1 SYNOPSIS

use SGN::Devel::lib_relative '../ITAG/lib', '../Phenome/lib';

=cut

use strict;
use warnings;

use lib;

use Path::Class;

use Catalyst::Utils;

my $home = Catalyst::Utils::home( __PACKAGE__ );

sub import {
    my $class = shift;
    lib->import(
        map dir( $_ )->absolute( $home )->stringify,
        @_
       );
}
