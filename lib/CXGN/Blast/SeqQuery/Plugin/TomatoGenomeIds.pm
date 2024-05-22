
package CXGN::Blast::SeqQuery::Plugin::TomatoGenomeIds;

use Moose;

sub name { 
    return "tomato genome identifiers";
}

sub type { 
    return 'nucleotide';
}

sub example { 
    return "Solyc01g005370
Solyc01g005590
Solyc01g016780
Solyc01g058740
Solyc01g080500";
}

sub validate { 
    my $self = shift;
    my $c = shift;
    my $input = shift;

    my @ids = split /\s+/, $input; 
    
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $rna_id = $schema->resultset("Cv::Cvterm")->find( { name=>'mRNA' })->cvterm_id();
    
    my @missing = ();
    foreach my $id (@ids) { 
	print STDERR "Validating $id... ";
	my $rs = $schema->resultset("Sequence::Feature")->search( { type_id=>$rna_id, name => { ilike => "$id".'.%.1' } } );
	if ($rs->count() ==0) { 
	    print STDERR " not found.\n";
	    push @missing, $id;
	}
	else { print STDERR "OK\n"; }

    }
    if (@missing) { 
	return "The folloing ids entered do not exist: ".(join ",", @missing);
    }
    else { 
	return "OK";
    }
}

sub process { 
    my $self = shift;
    my $c = shift;
    my $input = shift;
    
    my @ids = split /\s+/, $input; 

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $rna_id = $schema->resultset("Cv::Cvterm")->find( { name=>'mRNA' })->cvterm_id();
    print STDERR "RNA: $rna_id\n";
    my @seqs = ();
    foreach my $id (@ids) { 
	my $rs = $schema->resultset("Sequence::Feature")->search( { type_id=>$rna_id, name => { ilike => "$id".'.%.1' } } );
	if (my $row = $rs->next()) { 
	    
	    push @seqs, ">".$row->name."\n".$row->residues();
	}
	else { 
	    	    die "ID $id does not exist!";
	}
    }
    my $sequence =  join "\n", @seqs;
    print STDERR "SEQUENCE = $sequence\n";

    return $sequence;
    
    
}

1;
    
