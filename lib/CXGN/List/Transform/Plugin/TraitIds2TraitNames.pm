package CXGN::List::Transform::Plugin::TraitIds2TraitNames;

use Moose;

sub name { 
    return "trait_ids_2_trait_names";
}

sub display_name { 
    return "Trait IDs to trait names";
}

sub can { 
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
    my $c = shift;
    my $list = shift;

    my @transform = ();

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    
    my $type_id = $schema->resultset("Cv::Cvterm")->search({ name=>"plot" })->first->cvterm_id();
    


    print STDERR "PLOT TYPE ID $type_id\n";

    my @missing = ();
    foreach my $l (@$list) { 
        my $rs = $schema->resultset("Stock::Stock")->search(
            { 
                type_id=>$type_id,
                uniquename => $l, 
            }); 
        if ($rs->count() == 0) { 
            push @missing, $l;
        }
    }
    return { transform => \@transform,
	     missing => \@missing,
    };
}

1;
