package SGN::Build;
use strict;
use warnings;

use base 'Module::Build';

my $HAVE_CAPTURE;
BEGIN {
    eval { require Capture::Tiny };
    $HAVE_CAPTURE = !$@;
}

# build action just runs make on programs
sub ACTION_build {
   my $self = shift;
   $self->SUPER::ACTION_build(@_);
   system "make -C programs";
   $? and die "make failed\n";

   $self->check_R
       or die "R dependency check failed, aborting.\n";
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

sub create_build_script {
    my $self = shift;

    $self->check_R;

    return $self->SUPER::create_build_script(@_);
}

sub check_R {
    my ( $self, @args ) = @_;
    if( $HAVE_CAPTURE ) {
        my $ret;
        my $out = Capture::Tiny::capture_merged {
            $ret = $self->_check_R( @args );
        };

        warn $out unless $ret;

        return $ret;
    } else {
        return $self->_check_R( @args );
    }
}


sub _check_R {
    print "\nChecking R prerequisites...\n";

    system "R CMD check --no-manual --no-codoc --no-manual --no-vignettes -o _build R_files";
    if ( $? ) {
        warn "\nR PREREQUISITE CHECK FAILED.\n\n";
        return 0;
    } else {
        print "R prerequisites OK.\n\n";
        return 1;
    }
}


1;

