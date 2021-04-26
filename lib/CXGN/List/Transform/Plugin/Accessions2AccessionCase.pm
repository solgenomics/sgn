package CXGN::List::Transform::Plugin::Accessions2AccessionCase;

use Moose;

sub name {
    return "accessions_2_accession_case";
}

sub display_name {
    return "accessions to correct accessions case";
}

sub can_transform {
    my $self = shift;
    my $type1 = shift;
    my $type2 = shift;

    if (($type1 eq "accessions") and ($type2 eq "accession_case")) {
	return 1;
    }
    else {  return 0; }
}


sub transform {
    my $self = shift;
    my $schema = shift;
    my $list = shift;

    my @transform = ();
    my @found_ids = ();
    my @missing = ();
    my @duplicated = ();
    my %mapping;

    print STDERR "Transforming case of list.\n";
    
    my $type_id = $schema->resultset("Cv::Cvterm")->search( { name=>'accession' })->first()->cvterm_id();

    if (ref($list) eq "ARRAY" ) {
	foreach my $item (@$list) { 
	    my $rs = $schema->resultset("Stock::Stock")->search( { uniquename => { '~*' => '^'.$item.'$' }, type_id => $type_id } );

	    my $count = $rs->count();
	    if ($count == 0) {
		print STDERR "Missing item: $item\n";
		push @missing, $item;
	    }
	    
	    if ($count == 1) {
		my $row = $rs->next();
		if ($item eq $row->uniquename()) {
		    print STDERR "Found match  match: $item\n";
		    push @found_ids, $item;
		}
		else { 
		    print STDERR "Converting case from '$item' to '".$row->uniquename()."'\n";
		    push @found_ids, $row->uniquename();
		    $mapping{$item} = $row->uniquename();
		}
	    }

	    my %duplicates;
	    
	    if ($count > 1) {
		while (my $row = $rs->next()) {
		    push @{$duplicates{$item}}, $row->uniquename();
		}
		push @duplicated, \%duplicates;
	    }
	    

	}
	
    }
		


    return { transform => \@found_ids,
	     mapping => \%mapping,
	     missing => \@missing,
	     duplicated => \@duplicated,
    };

}

1;
