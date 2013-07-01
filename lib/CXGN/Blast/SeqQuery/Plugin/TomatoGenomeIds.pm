
package CXGN::Blast::SeqQuery::Plugin::TomatoGenomeIds;

use Moose;

sub name { 
    return "tomato genome identifiers";
}

sub validate { 
    my $self = shift;
    my $c = shift;
    my $input = shift;


    my @ids = split /\s+/, $input; 
    
    my @errors = ();
    foreach my $id (@ids){
	if($id !~ m/solyc\d{1,2}g\d{6}/i){
	    push @errors, $id;
	}
    }

    if (@errors) { 
	return "Illegal identifier(s): ".(join ", ", @errors);
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

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $rna_id = $schema->resultset("Cv::Cvterm")->find( { name=>'mRNA' })->cvterm_id();
    print STDERR "RNA: $rna_id\n";
    my @seqs = ();
    foreach my $id (@ids) { 
	my $rs = $schema->resultset("Sequence::Feature")->search( { type_id=>$rna_id, name => "$id" } );
	if (my $row = $rs->next()) { 
	    
	    push @seqs, ">".$row->name."\n".$->residues();
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
    
