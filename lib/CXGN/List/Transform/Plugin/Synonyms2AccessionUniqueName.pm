
package CXGN::List::Transform::Plugin::Synonyms2AccessionUniqueName;

use strict;

use Data::Dumper;

sub name {
    return "synonyms2accession_uniquename";
}

sub display_name {
    return "synonyms to accession unique names";
}

sub can_transform {
    my $self = shift;
    my $type1 = shift;
    my $type2 = shift;

    if (($type1 eq "accession_synonyms") and ($type2 eq "accession_names")) {
	return 1;
    }
    return 0;
}

sub transform {
    my $self = shift;
    my $schema = shift;
    my $list = shift;

    my $type_id = $schema->resultset("Cv::Cvterm")->search({ name=>"accession" })->first->cvterm_id();

    my $stock_property_cv_id = $schema->resultset("Cv::Cv")->search({ name=> "stock_property" })->first()->cv_id();

    my $synonym_type_id = $schema->resultset("Cv::Cvterm")->search({name=>"stock_synonym", cv_id=> $stock_property_cv_id })->first->cvterm_id();

    my %items = ();
    my @transform = ();

    # check uniquename
    #
    foreach my $item (@$list) {
	my $rs = $schema->resultset("Stock::Stock")->search( { uniquename => { ilike =>  $item} });

	if ($rs->count > 0) { $items{$item}++ }
    }

    print STDERR "synonym type id = $synonym_type_id\n";

    my @missing;

    foreach my $item (@$list) {
	my $rs = $schema->resultset("Stock::Stock")->search( { 'stockprops.value' => { ilike =>  $item }, 'stockprops.type_id' => $synonym_type_id }, { join => { 'stockprops'   } });

	if ($items{$item} > 0) { # matched the uniquename
	    push @transform, $item;
	}
	elsif ($rs->count > 0) {
	    push @transform, $rs->first->uniquename();
	}
	else {
	    push @missing, $item;
	}
    }



	my $data =  {
	transform => \@transform,
        missing => \@missing
    };

    #print STDERR Dumper($data);
    return $data;
}

1;
