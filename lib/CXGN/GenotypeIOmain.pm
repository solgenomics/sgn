
package CXGN::GenotypeIOmain;

use Moose;

with 'MooseX::Object::Pluggable';

sub init { 
    print STDERR "GenotypeIOmain init CALLED\n";
}

sub next { 
    print STDERR "GenotypeIOmain NEXT CALLED\n";
}


1;
