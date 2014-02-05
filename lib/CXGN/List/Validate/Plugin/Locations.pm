
package CXGN::List::Validate::Plugin::Locations;

use Moose;
use Data::Dumper;

sub name { 
    return "locations";
}

sub validate { 
    my $self = shift;
    my $schema = shift;
    my $list = shift;

#    print STDERR "LIST: ".Data::Dumper::Dumper($list);

    my @missing = ();
    foreach my $term (@$list) { 

	my $rs = $schema->resultset("NaturalDiversity::NdGeolocation")->search( { description => $term } );

	if ($rs->count == 0) { 
	    push @missing, $term;
	}
    }
    return { missing => \@missing };

}

1;
