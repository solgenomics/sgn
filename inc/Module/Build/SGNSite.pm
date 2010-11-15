package Module::Build::SGNSite;

use base 'Module::Build';

# build action just runs make on programs
sub ACTION_build {
   my $self = shift;
   $self->SUPER::ACTION_build(@_);
   system "make -C programs";
   $? and die "make failed\n";
}

# override install to just copy the whole dir into the install_base
sub ACTION_install {
   my $self = shift;

   # installation is just copying the entire dist into
   # install_base/sgn
   require File::Spec;
   my $tgt_dir = File::Spec->catdir($self->install_base,'sgn');
   system 'cp', '-rl', '.', $tgt_dir;
   $? and die "SGN site copy failed\n";
}

sub ACTION_clean {
   shift->SUPER::ACTION_clean(@_);
   system "make -C programs clean";
   $? and die "SGN site copy failed\n";
}

1;
