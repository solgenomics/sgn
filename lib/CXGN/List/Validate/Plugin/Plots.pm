
package CXGN::List::Validate::Plugin::Plots;

use Moose;

sub validate { 
    my $self = shift;
    my $c = shift;
    my $list = shift;

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    
    my $type_id = $schema->resultset("Cvterm::Cvterm")->search({ name=>"plot" })->first->type_id();
    
    my @missing = ();
    foreach my $l (@$list) { 
	my $rs = $schema->resultset("Stock")->search(
	    { 
		type_id=>$type_id,
		name => $l, 
	    });	
	if (!$rs) { 
	    push @missing, $l;
	}
    }
    return @missing;
}

1;
