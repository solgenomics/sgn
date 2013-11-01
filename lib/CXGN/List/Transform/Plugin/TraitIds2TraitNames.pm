package CXGN::List::Transform::Plugin::TraitIds2TraitNames;

use Moose;

sub name { 
    return "trait_ids_2_trait_names";
}

sub display_name { 
    return "Trait IDs to trait names";
}

sub can_transform { 
    my $self = shift;
    my $type1 = shift;
    my $type2 = shift;

    if (($type1 eq "trait_ids") and ($type2 eq "traits")) { 
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
                cvterm_id => $l, 
            }); 
        if ($rs->count() == 0) { 
            push @missing, $l;
        }
	else { 
	    push @transform, $rs->first()->name();
	}
    }
    return { transform => \@transform,
	     missing => \@missing,
    };
}

1;
