package CXGN::List::Transform::Plugin::Locations2LocationIds;

use Moose;

sub name { 
    return "locations_2_location_ids";
}

sub display_name { 
    return "locations to location IDs";
}

sub can_transform { 
    my $self = shift;
    my $type1 = shift;
    my $type2 = shift;

    if (($type1 eq "locations") and ($type2 eq "location_ids")) { 
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
	#print STDERR "Converting location $l to location_id...\n";
        my $rs = $schema->resultset("NaturalDiversity::NdGeolocation")->search(
            { 
		description => $l,
            }); 
        if ($rs->count() == 0) { 
            push @missing, $l;
        }
	else { 
	    push @transform, $rs->first()->nd_geolocation_id();
	}
    }
    return { transform => \@transform,
	     missing => \@missing,
    };
}

1;
