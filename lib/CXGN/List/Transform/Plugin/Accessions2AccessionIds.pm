package CXGN::List::Transform::Plugin::Accessions2AccessionIds;

use Moose;

sub name {
    return "accessions_2_accession_ids";
}

sub display_name {
    return "accessions to accession IDs";
}

sub can_transform {
    my $self = shift;
    my $type1 = shift;
    my $type2 = shift;

    if (($type1 eq "accessions") and ($type2 eq "accession_ids")) {
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

    my $type_id = $schema->resultset("Cv::Cvterm")->search( { name=>'accession' })->first()->cvterm_id();
    my $synonym_type_id = $schema->resultset("Cv::Cvterm")->search( { name=>'stock_synonym' })->first()->cvterm_id();

    if (ref($list) eq "ARRAY" ) {
      foreach my $l (@$list) {
        #print STDERR "Converting accession $l ...\n";
	      my $rs = $schema->resultset("Stock::Stock")->search( { uniquename => $l, type_id    => $type_id });

	      if ($rs->count() == 0) { #If list item isn't a uniquename, check if it's a synonym
          $rs = $schema->resultset("Stock::Stock")->search(
          { 'stockprops.value' => $l, 'stockprops.type_id' => $synonym_type_id, 'me.type_id' => $type_id},
          { join => 'stockprops' }
          );
        }

        if ($rs->count() == 0) {
          #print STDERR "No id found for accession $l\n";
          push @missing, $l;
        }
	      else {
          #print STDERR "Found id ".$rs->first()->stock_id()." for accession $l\n";
          push @transform, $rs->first()->stock_id();
        }
      }
    }
    return { transform => \@transform,
	     missing => \@missing,
    };
}

1;
