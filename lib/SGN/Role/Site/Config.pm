package SGN::Role::Site::Config;

use Moose::Role;
use namespace::autoclean;

use Carp;

requires 'config';

=head2 get_conf

  Status  : public
  Usage   : $c->get_conf('my_conf_variable')
  Returns : the value of the variable, as loaded by the configuration
            objects
  Args    : a single configuration variable name
  Side Eff: B<DIES> if the variable is not defined, either in defaults or
            in the configuration file.
  Example:

     my $val = $c->get_conf('my_conf_variable');


It's probably best to use $c->get_conf('var') rather than
$c->config->{var} for most purposes, because get_conf() checks that
the variable is actually set, and dies if not.

=cut

sub get_conf {
  my ( $self, $n ) = @_;

  croak "conf variable '$n' not set, and no default provided"
      unless exists $self->config->{$n};

  return $self->config->{$n};
}



1;
