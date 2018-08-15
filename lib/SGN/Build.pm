package SGN::Build;
use strict;
use warnings;

use version;

my $HAVE_PARSE_DEB_CONTROL;

BEGIN {
    eval { require Parse::Deb::Control };
    if( $@ ) {
        warn "WARNING: Failed to load Parse::Deb::Control, and it is needed to check R dependencies:\n$@\n"
    }
    $HAVE_PARSE_DEB_CONTROL = !$@;
}

use Module::Build;
use base 'Module::Build';

my $HAVE_CAPTURE;
BEGIN {
    eval { require Capture::Tiny };
    $HAVE_CAPTURE = !$@;
}

# we should probably convert this to autodie at some point

# build action just runs make on programs
sub ACTION_build {
   my $self = shift;
   $self->SUPER::ACTION_build(@_);
   system "make -C programs";
   if($?) {
        _handle_errors($?);
        die "make -C programs failed\!n";
   }

   unless( $ENV{SGN_SHIPWRIGHT_BUILDING} ) {
       $self->check_R
           or die "R dependency check failed, aborting.\n";
   }

}

# override install to just copy the whole dir into the install_base
sub ACTION_install {
   my $self = shift;

   # installation is just copying the entire dist into
   # install_base/sgn
   require File::Spec;
   my $tgt_dir = File::Spec->catdir($self->install_base,'sgn');
   system 'cp', '-rl', '.', $tgt_dir;
   if($?) {
      _handle_errors($?);
      die "SGN site copy ( cp -rl . $tgt_dir ) failed!\n";
   }
}

sub ACTION_clean {
   shift->SUPER::ACTION_clean(@_);
   system "make -C programs clean";
   if($?) {
      _handle_errors($?);
      die "make -C programs clean failed!\n";
   }
}

sub ACTION_installdeps {
    my $self = shift;

    $self->_R_installdeps;

    $self->SUPER::ACTION_installdeps( @_ );
}

sub create_build_script {
    my $self = shift;

    $self->check_R
        or warn $self->{R}{check_output};

    return $self->SUPER::create_build_script(@_);
}

sub check_R {
    my ( $self, @args ) = @_;
   
    if( $HAVE_CAPTURE ) {
        my $ret;
        my $out = Capture::Tiny::capture_merged {
	    $ret = $self->_check_R_version;
        };

         $self->{R}{check_output} = $out;
  
        return $ret;
    } else {
	return $self->_check_R_version
    }
}

sub _R_installdeps {
    my ( $self ) = @_;

    print "\n\nInstalling R dependencies in ~/cxgn/R_libs. \nDepending on the number of deps to install, this may take long time.\n\nAfter the installation completes, set the env variable R_LIBS_USER in your system (/etc/R/Renviron) to \"~/cxgn/R_libs\". This will ensure deps you manually install in R will be in the same place as sgn R libraries and avoid installation of the same R packages in multiple places. It will also add packages in the \"~/cxgn/R_libs\" to the search path\n\n";

    my $rout = qx /Rscript R\/sgnPackages.r 2>&1 /;

    print "\nR dependencies installation output:\n $rout\n";

    if( $? ) {
	_handle_errors($?);
	warn "Failed to automatically install R dependencies\n\n";
    } else  {
	print "Successfully installed R dependencies.\n\n";
    }

}

sub _handle_errors {
    my ($exit_code) = @_;
    if ($exit_code == -1) {
        print "Error: failed to execute: $!\n";
    } elsif ($exit_code & 127) {
        warn sprintf("Error: child died with signal %d, %s coredump\n",
            ($exit_code & 127),  ($exit_code & 128) ? 'with' : 'without');
    } else {
        warn sprintf("Error: child exited with value %d\n",$exit_code >> 8);
    }
}

sub _run_R_check {
    my $self = shift;

    # check the R version ourself, since R CMD check apparently does
    # not do it.
    $self->_check_R_version
        or return 0;

    if ( $? ) {
        _handle_errors($?);
        warn "\nR version PREREQUISITE CHECK FAILED.\n\n";
        return 0;
    } else {
        print "\nR version prerequisite OK.\n\n";
        return 1;
    }
}

sub _check_R_version {
    my $self = shift;

    unless ($HAVE_PARSE_DEB_CONTROL) {
        warn "Parse::Deb::Control not present, skipping R configuration";
        return 0;
    }
    my ( $cmp, $v ) = $self->_R_version_required;

    if( eval '$self->_R_version_current'." $cmp version->parse('$v')" ) {
        return 1;
    } else {
        warn "R VERSION CHECK FAILED, we have ".$self->_R_version_current.", but we require $cmp $v.\n";
        warn "To install R : sudo apt-get update; sudo apt-get install r-base r-base-dev\n\n";
        return 0;
    }
}

# parse and return the R cran deps file
sub _R_desc {
    return Parse::Deb::Control->new([qw[ R_files cran ]]);
}

# parse and return the version of R we require as string list like
# ('>=','2.10.0')
sub _R_version_required {
    my $self = shift;
    
    my @k = $self->_R_desc->get_keys('Depends')
        or return ( '>=', 0 );
    my ($version) = ${$k[0]->{value}} =~ / \b R \s* \( ([^\)]+) /x
        or return ( '>=', 0 );

    my @v = split /\s+/, $version;
    unshift @v, '==' unless @v > 1;

    return @v;
}

# parse and return the current R version as a version object
sub _R_version_current {
    my $r = `R --version`;
    return 0 unless $r;

    $r =~ /R version ([\d+\.]+)/;

    return version->new($1);
}


1;

