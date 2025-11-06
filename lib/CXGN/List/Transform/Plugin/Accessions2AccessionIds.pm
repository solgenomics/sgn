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

    my %found_hash = ();
    my @transform = ();
    my @found_ids = ();
    my @missing = ();

    my $type_id = $schema->resultset("Cv::Cvterm")->search( { name=>'accession' })->first()->cvterm_id();
    my $synonym_type_id = $schema->resultset("Cv::Cvterm")->search( { name=>'stock_synonym' })->first()->cvterm_id();

    if (ref($list) eq "ARRAY" ) {
         my $rs = $schema->resultset("Stock::Stock")->search( { uniquename => { -in => $list }, type_id    => $type_id });

         @found_ids = map { $_->stock_id() } $rs->all();
         my @found_names = map { $_->uniquename() } $rs->all();

         # add map of found name --> found id
         for my $i (0 .. $#found_names) {
            $found_hash{$found_names[$i]} = $found_ids[$i];
         }

         my %found_names_hash = map{$_ => 1} @found_names;
         my @not_found = grep(!defined $found_names_hash{$_}, @$list);

         if (scalar @not_found) { #If not found as uniquenames, check if list items are synonyms
             $rs = $schema->resultset("Stock::Stock")->search( { 'stockprops.value' =>  { -in => \@not_found }, 'stockprops.type_id' => $synonym_type_id, 'me.type_id' => $type_id},{ join => 'stockprops' });

             foreach my $synonym ($rs->all()) {
                  push @found_ids,  $synonym->stock_id();
                  push @found_names,  $synonym->uniquename();
                  my $syn = $synonym->stockprops({ type_id => $synonym_type_id })->first->value();
                  $found_hash{$syn} = $synonym->stock_id();
             }
         }

         if (scalar @found_ids != scalar @$list) { #Add any items still not found to list of missing
            my %found_names_hash = map{$_ => 1} @found_names;
            @missing = grep(!defined $found_names_hash{$_}, @$list);
        }
    }

    # Return ids in same order as original list
    my @sorted_found_ids;
    foreach (@$list) {
        push @sorted_found_ids, $found_hash{$_};
    }

    return { transform => \@sorted_found_ids,
	     missing => \@missing,
    };

}

1;
