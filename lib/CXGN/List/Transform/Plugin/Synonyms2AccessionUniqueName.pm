
package CXGN::List::Transform::Plugin::Synonyms2AccessionUniqueName;

use strict;

use CXGN::BreedersToolbox::AccessionsFuzzySearch;

sub name { 
    return "synonyms2accession_uniquename";
}

sub display_name { 
    return "synonyms to accession unique names";
}

sub can_transform { 
    my $self = shift;
    my $type1 = shift;
    my $type2 = shift;
    
    if (($type1 eq "accession_synonyms") and ($type2 eq "accession_names")) { 
	return 1;
    }
    return 0;
}

sub transform { 
    my $self = shift;
    my $schema = shift;
    my $list = shift;
    

    my $fs = CXGN::BreedersToolbox::AccessionsFuzzySearch->new({schema=>$schema});

    my $r = $fs->get_matches($list, 0);

    if (@{$r->{absent}} > 0) { 
	return { error => "Some accessions could not be found (".join(","), @{$r->{not_found}}.")" };
    }
    
    my @transform = ();
    foreach my $fau (@{$r->{found}}) { 
	push @transform, $fau->{unique_name};
    }

    return { 
	transform => \@transform,
        missing => $r->{absent}
    };
}

1;
    


