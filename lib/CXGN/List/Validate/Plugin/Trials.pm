
package CXGN::List::Validate::Plugin::Trials;

use Moose;
use Data::Dumper;

sub name { 
    return "trials";
}

sub validate { 
    my $self = shift;
    my $schema = shift;
    my $list = shift;

    my @missing = ();
    foreach my $term (@$list) { 

	my $rs = $schema->resultset("Project::Project")->search( { name => $term } );
	#$schema->storage->debug(1);
	if ($rs->count == 0) { 
	    push @missing, $term;
	}
    }
    return { missing => \@missing };

}

1;
