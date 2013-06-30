
package CXGN::Blast::SeqQuery::Plugin::TomatoGenomeIds;

use Moose;

sub name { 
    return "tomato genome identifiers";
}

sub validate { 
    my $self = shift;
    my $input = shift;
    my @ids = split /\s+/, $input; 
    
    my @errors = ();
    foreach my $id (@ids){
	if($id !~ m/solyc\d{1,2}g\d{6}/){
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
    my $input = shift;
    
    
}

1;
    
