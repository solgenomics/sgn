
package CXGN::GenotypeIOmain;

use Moose;

with 'MooseX::Object::Pluggable';

sub init { 
}

sub next { 
    print STDERR "NEXT CALLED\n";
}


1;
