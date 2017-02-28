
=head1 NAME

SGN::Model::Cvterm - a simple model that provides information on cvterms

=head1 DESCRIPTION

Retrieves cv terms.

get_cvterm_object retrieves the term as a CXGN::Chado::Cvterm object.

get_cvterm_row retrieves the term as a DBIx::Class row.

Both function take a schema object, cvterm name and a cv name as an argument.

If a term is not in the database, undef is returned.

=head1 AUTHOR

Lukas Mueller

=cut

package SGN::Model::Cvterm;

use CXGN::Chado::Cvterm;

sub get_cvterm_object { 
    my $self = shift;
    my $schema = shift;
    my $cvterm_name = shift;
    my $cv_name = shift;

    my $cv = $schema->resultset('Cv::Cv')->find( { name => $cv_name });

    if (! $cv) { 
	print STDERR "CV $cv_name not found. Ignoring.";
	return undef;
    }
    my $term = CXGN::Chado::Cvterm->new_with_term_name(
	$self->dbc()->dbh(), 
	$cvterm_name, 
	$cv->cv_id()
	);
    
    return $term;
}

sub get_cvterm_row { 
    my $self = shift;
    my $schema = shift;
    my $name = shift;
    my $cv_name = shift;

    my $cvterm = $schema->resultset('Cv::Cvterm')->find( 
        { 
            'me.name' => $name,
            'cv.name' => $cv_name,
        }, { join => 'cv' });

    return $cvterm;
}

sub get_cvterm_row_from_trait_name {
    my $self = shift;
    my $schema = shift;
    my $trait_name = shift;

    #print STDERR $trait_name;

    #fieldbook trait string should be "$trait_name|$dbname:$trait_accession" e.g. plant height|CO:0000123. substring on last occurance of |
    my $delim = "|";
    my $full_accession = substr $trait_name, rindex( $trait_name, $delim ) + length($delim);
    my $full_accession_length = length($full_accession) + length($delim);
    my $full_cvterm_name = substr($trait_name, 0, -$full_accession_length);
    my ( $db_name , $accession ) = split (/:/ , $full_accession);

    #check if the trait name string does have  
    $accession =~ s/\s+$//;
    $accession =~ s/^\s+//;
    $db_name  =~ s/\s+$//;
    $db_name  =~ s/^\s+//;

    my $db_rs = $schema->resultset("General::Db")->search( { 'me.name' => $db_name });
    my $trait_cvterm = $schema->resultset("Cv::Cvterm")
	->find({
	     'dbxref.db_id'     => $db_rs->first()->db_id(),
	     'dbxref.accession' => $accession 
	      },
	      {
	      'join' => 'dbxref'
	      }
	);
    return $trait_cvterm;
}

sub get_trait_from_exact_components {
    my $self= shift;
    my $schema = shift;
    my $component_cvterm_ids = shift;

    my @intersect_selects;
    foreach my $cvterm_id (@$component_cvterm_ids){
        push @intersect_selects, "SELECT object_id FROM cvterm_relationship WHERE subject_id = $cvterm_id";
    }
    push @intersect_selects, "SELECT object_id FROM cvterm_relationship HAVING count(object_id) = ".scalar(@$component_cvterm_ids);
    my $intersect_sql = join ' INTERSECT ', @intersect_selects;
    my $h = $schema->storage->dbh->prepare($intersect_sql);
    $h->execute();
    my @trait_cvterm_ids;
    while(my ($trait_cvterm_id) = $h->fetchrow_array()){
        push @trait_cvterm_ids, $trait_cvterm_id;
    }
    if (scalar(@trait_cvterm_ids) > 1){
        die "More than one composed trait returned for a given set of exact componenets\n";
    }
    my $trait_cvterm = $schema->resultset('Cv::Cvterm')->find({cvterm_id=>$trait_cvterm_ids[0]});
    return $trait_cvterm;
}

sub get_traits_from_components {
    my $self= shift;
    my $schema = shift;
    my $component_cvterm_ids = shift;

    my @intersect_selects;
    my $contains_cvterm_id = $self->get_cvterm_row($schema, 'contains', 'relationship')->cvterm_id();
    foreach my $cvterm_id (@$component_cvterm_ids){
        push @intersect_selects, "SELECT object_id FROM cvterm_relationship WHERE subject_id = $cvterm_id and type_id = $contains_cvterm_id";
    }
    my $intersect_sql = join ' UNION ', @intersect_selects;
    my $h = $schema->storage->dbh->prepare($intersect_sql);
    $h->execute();
    my @trait_cvterm_ids;
    while(my ($trait_cvterm_id) = $h->fetchrow_array()){
        push @trait_cvterm_ids, $trait_cvterm_id;
    }
    return \@trait_cvterm_ids;
}

sub get_components_from_trait {
    my $self= shift;
    my $schema = shift;
    my $trait_cvterm_id = shift;

    my $contains_cvterm_id = $self->get_cvterm_row($schema, 'contains', 'relationship')->cvterm_id();
    my $q = "SELECT subject_id FROM cvterm_relationship WHERE object_id = $trait_cvterm_id and type_id = $contains_cvterm_id;";
    my $h = $schema->storage->dbh->prepare($q);
    $h->execute();
    my @component_cvterm_ids;
    while(my ($component_cvterm_id) = $h->fetchrow_array()){
        push @component_cvterm_ids, $component_cvterm_id;
    }
    return \@component_cvterm_ids;
}

1;
