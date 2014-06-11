package CXGN::List::Transform::Plugin::Accessions2AccessionIds;

use Moose;

sub name { 
    return "accessions_2_accession_ids";
}

sub display_name { 
    return "accessions to accession IDs";
}

sub can_transform { 
    my $self = shift;
    my $type1 = shift;
    my $type2 = shift;

    if (($type1 eq "accessions") and ($type2 eq "accession_ids")) { 
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

    my $type_id = $schema->resultset("Cv::Cvterm")->search( { name=>'accession' })->first()->cvterm_id();

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
