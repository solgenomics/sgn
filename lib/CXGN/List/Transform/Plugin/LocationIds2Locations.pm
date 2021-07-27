
package CXGN::List::Transform::Plugin::LocationIds2Locations;

use Moose;

sub name { 
    return "locations_ids_2_location";
}

sub display_name { 
    return "location IDs to location";
}

sub can_transform { 
    my $self = shift;
    my $type1 = shift;
    my $type2 = shift;

    if (($type1 eq "location_ids") and ($type2 eq "locations")) { 
	return 1;
    }
    else {  return 0; }
}
    

sub transform { 
    my $self = shift;
    my $schema = shift;
    my $list = shift;

    my @transform = ();

    my @missing = ();

    foreach my $l (@$list) { 
        my $rs = $schema->resultset("NaturalDiversity::NdGeolocation")->search({nd_geolocation_id =>$l});
        if ($rs->count() == 0) { 
            push @missing, $l;
        }
        else {
            push @transform, $rs->first()->description();
        }
    }
    return {
        transform => \@transform,
        missing => \@missing,
    };
}

1;
