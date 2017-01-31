package CXGN::List::Transform::Plugin::Populations2PopulationIds;

use Moose;

sub name {
    return "populations_2_population_ids";
}

sub display_name {
    return "populations to population IDs";
}

sub can_transform {
    my $self = shift;
    my $type1 = shift;
    my $type2 = shift;

    if (($type1 eq "populations") and ($type2 eq "population_ids")) {
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

    my $type_id = $schema->resultset("Cv::Cvterm")->search( { name=>'population' })->first()->cvterm_id();

    if (ref($list) eq "ARRAY" ) {
	foreach my $l (@$list) {
      if (!$l) { next;}
	    #print STDERR "Converting location $l to location_id...\n";
	    my $rs = $schema->resultset("Stock::Stock")->search( { uniquename => $l,
								   type_id    => $type_id });
	    if ($rs->count() == 0) {
		push @missing, $l;
	    }
	    else {
		push @transform, $rs->first()->stock_id();
	    }
	}
    }
    return { transform => \@transform,
	     missing => \@missing,
    };
}

1;
