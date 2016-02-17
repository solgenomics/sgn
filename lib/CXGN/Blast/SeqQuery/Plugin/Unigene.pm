
package CXGN::Blast::SeqQuery::Plugin::Unigene;

use Moose;

sub name { 
    return "unigene identifiers";
}

sub type { 
    return 'nucleotide';
}

sub example { 
    return "SGN-U222222\nSGN-U222223\nSGN-U222224\n";
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

    my $query = "SELECT unigene_id, nr_members, unigene_consensi.seq FROM sgn.unigene JOIN sgn.unigene_consensi using(consensi_id) WHERE unigene_id=?";
    my $h = $dbh->prepare($query);
    
    my @seqs = ();
    foreach my $id (@ids) {
      my $numeric_id = $id;
      $numeric_id=~s/\D//g;
      $h->execute($numeric_id);
      
      if (my ($unigene_id, $nr_members, $seq) = $h->fetchrow_array()) {
      
        if ($nr_members > 1) {
          push @seqs, ">".$id."\n".$seq;
        }
        elsif ($nr_members == 1) {
          my $query = "SELECT unigene_id, seq FROM sgn.unigene_member JOIN sgn.est using(est_id) WHERE unigene_id=?";
          my $h = $dbh->prepare($query);
          $h->execute($numeric_id);
          
          if (my ($unigene_id, $seq) = $h->fetchrow_array()) {
            push @seqs, ">".$id."\n".$seq;
          }
          else { 
            die "Unigene $id singleton could not be found!";
          }
          
        }
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
    
