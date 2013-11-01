package CXGN::List::Transform::Plugin::Traits2TraitIds;

use Moose;

sub name { 
    return "traits_2_trait_ids";
}

sub display_name { 
    return "Traits to trait IDs";
}

sub can_transform { 
    my $self = shift;
    my $type1 = shift;
    my $type2 = shift;

    if (($type1 eq "traits") and ($type2 eq "trait_ids")) { 
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
        my $rs = $schema->resultset("Cv::Cvterm")->search(
            { 
		name => $l,
            }); 
        if ($rs->count() == 0) { 
            push @missing, $l;
        }
	else { 
	    push @transform, $rs->first()->cvterm_id();
	}
    }
    return { transform => \@transform,
	     missing => \@missing,
    };
}

1;
