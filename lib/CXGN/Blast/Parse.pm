
package CXGN::Blast::Parse;

use Moose;

use Module::Pluggable require => 1;

sub parse { 
    my $self = shift;
    my $method = shift;
    my $file = shift; 
    my $db_id = shift;

    my $done = 0;
    my $parsed_file = '';
    foreach my $p ($self->plugins()) { 
	if ($method eq $p->name()) { 
	    $parsed_file = $p->parse($file, $db_id);
	    $done = 1;
	}
    }
    if (! $done) { 
	die "BLAST parse method '$method' is currently not supported - plugin not available!\n";
    }
    return $parsed_file;
}

1;


    
