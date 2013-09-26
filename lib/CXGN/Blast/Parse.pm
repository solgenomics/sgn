
package CXGN::Blast::Parse;

use Moose;

use Module::Pluggable require => 1;

# sub prereqs { 
#     my $self = shift;
#     my $method = shift;

#     my $prereqs = "";

#     foreach my $p ($self->plugins()) { 
# 	if ($method eq $p->name()) { 
# 	    $prereqs = $p->prereqs();
# 	}
#     }
#     return $prereqs;
# }

sub parse { 
    my $self = shift;
    my $c = shift;
    my $method = shift;
    my $file = shift; 
    my $dbd = shift;

    my $done = 0;
    my $prereqs = '';
    my $parsed_html = '';
    foreach my $p ($self->plugins()) { 
	if ($method eq $p->name()) { 
	    $prereqs = $p->prereqs();
	    $parsed_html = $p->parse($c, $file, $dbd);
	    $done = 1;
	}
    }
    if (! $done) { 
	die "BLAST parse method '$method' is currently not supported - plugin not available!\n";
    }
    return { prereqs => $prereqs, blast_report => $parsed_html };
}

1;


    
