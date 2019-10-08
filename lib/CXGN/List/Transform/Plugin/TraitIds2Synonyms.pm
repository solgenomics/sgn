package CXGN::List::Transform::Plugin::TraitIds2Synonyms;

use Moose;

sub name {
    return "trait_ids_2_synonyms";
}

sub display_name {
    return "Trait IDs to synonyms";
}

sub can_transform {
    my $self = shift;
    my $type1 = shift;
    my $type2 = shift;

    if (($type1 eq "trait_ids") and ($type2 eq "synonyms")) {
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
        my $cvterm = CXGN::Cvterm->new( schema=> $schema, cvterm_id => $l);
        my $synonym = $cvterm->get_single_synonym();

        if ($synonym) {
            push @transform, $synonym
        } else {
            push @missing, $l
        }
    }
    return { transform => \@transform,
	     missing => \@missing,
    };
}

1;
