
package CXGN::List::Validate::Plugin::Accessions;

use Moose;

sub name { 
    return "accessions";
}

sub validate { 
    my $self = shift;
    my $c = shift;
    my $list = shift;

    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $type_id = $schema->resultset("Cv::Cvterm")->search({ name=>"accession" })->first->cvterm_id();

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
    return  { missing => \@missing, };
    
}

1;
