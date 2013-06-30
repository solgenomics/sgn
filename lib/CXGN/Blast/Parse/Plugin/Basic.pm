
package CXGN::Blast::Parse::Plugin::Basic;

use Moose;

sub name { 
    return "basic";
}

sub parse { 
    my $self = shift;
    my $file = shift;
    return $file;
}

1;
