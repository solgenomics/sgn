
package CXGN::GenotypeIOmain;

use Moose;

with 'MooseX::Object::Pluggable';


sub next { 
    print STDERR "NEXT CALLED\n";
}


1;
