sub compare_parental_genotypes {
    my $self = shift;
    my $female_parent_genotype = shift;
    my $male_parent_genotype = shift;

    my $self_markers = $self->markerscores();
    my $mom_markers = $female_parent_genotype->markerscores();
    my $dad_markers = $male_parent_genotype->markerscores();

    my $non_informative =0;
    my $concordant =0;
    my $non_concordant =0;
    foreach my $m (keys %$self_markers) {

	my @matrix; #mom, dad, self, 1=possible 0=impossible
	$matrix[ 0 ][ 0 ][ 0 ] ==1;
	$matrix[ 0 ][ 0 ][ 1 ] ==0;
	$matrix[ 0 ][ 0 ][ 2 ] ==0;
	$matrix[ 0 ][ 1 ][ 0 ] ==1;
	$matrix[ 0 ][ 1 ][ 1 ] ==1;
	$matrix[ 0 ][ 1 ][ 2 ] ==0;
	$matrix[ 0 ][ 2 ][ 1 ] ==1;
	$matrix[ 0 ][ 2 ][ 0 ] ==1;
	$matrix[ 0 ][ 2 ][ 2 ] ==0;

	$matrix[ 1 ][ 0 ][ 0 ] ==1;
	$matrix[ 1 ][ 0 ][ 1 ] ==1;
	$matrix[ 1 ][ 0 ][ 2 ] ==0;
	$matrix[ 1 ][ 1 ][ 0 ] ==1;
	$matrix[ 1 ][ 1 ][ 1 ] ==1;
	$matrix[ 1 ][ 1 ][ 2 ] ==0;
	$matrix[ 1 ][ 2 ][ 0 ] ==0;
	$matrix[ 1 ][ 2 ][ 1 ] ==1;
	$matrix[ 1 ][ 2 ][ 2 ] ==1;


	$matrix[ 2 ][ 0 ][ 0 ] == 0;
	$matrix[ 2 ][ 0 ][ 1 ] == 1;
	$matrix[ 2 ][ 0 ][ 2 ] == 0;
	$matrix[ 2 ][ 1 ][ 0 ] == 1;
        $matrix[ 2 ][ 1 ][ 1 ] == 1;
	$matrix[ 2 ][ 1 ][ 2 ] == 1;
	$matrix[ 2 ][ 2 ][ 0 ] == 0;
	$matrix[ 2 ][ 2 ][ 1 ] == 0;
	$matrix[ 2 ][ 2 ][ 2 ] == 1;

	print STDERR "checking $mom_markers->{$m} and $dad_markers->{$m} against $self_markers->{$m}\n";
	if ($matrix[ $mom_markers->{$m}]->[ $dad_markers->{$m}]->[ $self_markers->{$m}] == 1) {
	    $concordant++;
	    print STDERR "Plausible. \n";
	}
	else {
	    $non_concordant++;
	    print STDERR "NOT Plausible. \n";
	}
    }
    return ($concordant, $non_concordant);
}
