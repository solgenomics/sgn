
package CXGN::Blast::Parse::Plugin::Basic;

use Moose;
use File::Slurp qw | read_file |;

sub name { 
    return "Basic";
}

sub priority { 
    return 10;
}

sub prereqs { 
}

sub parse { 
    my $self = shift;
    my $c = shift;
    my $file = shift;

    return "<pre>".read_file($file)."</pre>";
}

1;
