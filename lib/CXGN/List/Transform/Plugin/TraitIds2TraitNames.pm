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
            },
	    { 
	       join => 'dbxref'
	    }); 
        if ($rs->count() == 0) { 
            push @missing, $l;
        }
	else { 
	    my $db_rs = $schema->resultset("General::Db")->search( 
		{
		    db_id => $rs->first()->dbxref->db()->db_id()
		});
	    if ($db_rs->count()> 0) { 
		push @transform, $rs->first()->name()."|".$db_rs->first()->name().":".$rs->first()->dbxref()->accession();
	    }
	    else { 
		push @missing, $l;
	    }
	}
    }
    return { transform => \@transform,
	     missing => \@missing,
    };
}

1;
