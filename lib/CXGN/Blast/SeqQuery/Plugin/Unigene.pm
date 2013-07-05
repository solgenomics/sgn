
package CXGN::Blast::SeqQuery::Plugin::Unigene;

use Moose;

sub name { 
    return "SGN unigene identifiers";
}

sub type { 
    return 'nucleotide';
}

sub validate { 
    my $self = shift;
    my $c = shift;
    my $input = shift;

    my @ids = split /\s+/, $input; 
    
    my @errors = ();
    foreach my $id (@ids){
	if($id !~ m/SGN-U\d+/i){
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

    my $dbh = $c->dbc->dbh();

    my $query = "SELECT unigene_id, unigene_consensi.seq FROM sgn.unigene JOIN sgn.unigene_consensi using(consensi_id) WHERE unigene_id=?";
    my $h = $dbh->prepare($query);
    
    my @seqs = ();
    foreach my $id (@ids) { 
	my $numeric_id = $id;
	$numeric_id=~s/\D//g;
	$h->execute($numeric_id);
	if (my ($unigene_id, $seq) = $h->fetchrow_array()) { 
	    
	    push @seqs, ">".$id."\n".$seq;
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
    
