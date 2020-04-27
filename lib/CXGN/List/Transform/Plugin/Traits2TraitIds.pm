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
    foreach my $term (@$list) { 
	my $missing_flag = 0;
	my $rs; 
    
    my @parts = split (/\|/ , $term);
    my ($db_name, $accession) = split ":", pop @parts;
    
    $accession =~ s/\s+$//;
    $accession =~ s/^\s+//;
    $db_name =~ s/\s+$//;
    $db_name =~ s/^\s+//;
	
	my $db_rs = $schema->resultset("General::Db")->search( 
	    { 
		name => $db_name,
	    });
	
	if ($db_rs->count() == 0) { 
	    $missing_flag = 1;
	}
	else {
	    my $db_id = $db_rs->first()->db_id();
	    $rs = $schema->resultset("Cv::Cvterm")->search(
		{ 
		    'dbxref.accession' => $accession, db_id => $db_id
		},
		{
		    join => 'dbxref'
		}
		);
	    if ($rs->count() == 0) { 
		$missing_flag = 1;
	    }
	}
	if (!$missing_flag) { 
	    push @transform, $rs->first()->cvterm_id();
	}
	else { 
	    push @missing, $term;
	}
    }
    return { transform => \@transform,
	     missing => \@missing,
    };
}

1;
