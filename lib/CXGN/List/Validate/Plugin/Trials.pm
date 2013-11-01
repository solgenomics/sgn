
package CXGN::List::Validate::Plugin::Trials;

use Moose;
use Data::Dumper;

sub name { 
    return "trials";
}

sub validate { 
    my $self = shift;
    my $c = shift;
    my $list = shift;

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
        
    my @missing = ();
    foreach my $term (@$list) { 

	my $rs = $schema->resultset("Project::Project")->search( { name => $term } );

	if ($rs->count == 0) { 
	    push @missing, $term;
	}
    }
    return { missing => \@missing };

}

1;
