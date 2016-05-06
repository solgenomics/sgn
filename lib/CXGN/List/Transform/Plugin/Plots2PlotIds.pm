package CXGN::List::Transform::Plugin::Plots2PlotIds;

use Moose;

sub name { 
    return "plots_2_plot_ids";
}

sub display_name { 
    return "plots to plot IDs";
}

sub can_transform { 
    my $self = shift;
    my $type1 = shift;
    my $type2 = shift;

    if (($type1 eq "plots") and ($type2 eq "plot_ids")) { 
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

    my $type_id = $schema->resultset("Cv::Cvterm")->search( { name=>'plot' })->first()->cvterm_id();

    if (ref($list) eq "ARRAY" ) { 
	foreach my $l (@$list) { 
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
