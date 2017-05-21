
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
use Data::Dumper;

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
    my $trait_cvterm;
    if ($db_rs->first()){
        $trait_cvterm = $schema->resultset("Cv::Cvterm")
        ->find({
             'dbxref.db_id'     => $db_rs->first()->db_id(),
             'dbxref.accession' => $accession
              },
              {
              'join' => 'dbxref'
              }
        );
    }
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
    push @intersect_selects, "SELECT object_id FROM cvterm_relationship GROUP BY 1 HAVING count(object_id) = ".scalar(@$component_cvterm_ids);
    my $intersect_sql = join ' INTERSECT ', @intersect_selects;
    my $h = $schema->storage->dbh->prepare($intersect_sql);
    $h->execute();
    my @trait_cvterm_ids;
    while(my ($trait_cvterm_id) = $h->fetchrow_array()){
        push @trait_cvterm_ids, $trait_cvterm_id;
    }
    if (scalar(@trait_cvterm_ids) > 1){
        die "More than one composed trait returned for the given set of exact componenets\n";
    }
    return $trait_cvterm_ids[0];
}

sub get_trait_from_cvterm_id {
    my $schema = shift;
    my $cvterm_id = shift;
    my $format = shift;
    if ($format eq 'concise'){
        $q = "SELECT name FROM cvterm WHERE cvterm_id=?;";
    }
    if ($format eq 'extended'){
        $q = "SELECT (((cvterm.name::text || '|'::text) || db.name::text) || ':'::text) || dbxref.accession::text FROM cvterm JOIN dbxref USING(dbxref_id) JOIN db USING(db_id) WHERE cvterm_id=?;";
    }
    my $h = $schema->storage->dbh->prepare($q);
    $h->execute($cvterm_id);
    $name = $h->fetchrow();
    return $name;
}

sub _concatenate_cvterm_array {
    my $schema = shift;
    my $delimiter = shift;
    my $format = shift;
    my $first = shift;
    my $second = shift;
    my %first_hash = %$first;
    foreach my $f (keys %first_hash){
        my $ids = $first_hash{$f};
        foreach my $s (@$second){
            my $name = get_trait_from_cvterm_id($schema, $s, $format);
            my $concatenated_cvterm = $f.$delimiter.$name;
            push @$ids, $s;
            delete $first_hash{$f};
            $first_hash{$concatenated_cvterm} = $ids;
        }
    }
    return \%first_hash;
}
sub get_traits_from_component_categories {
    my $self= shift;
    my $schema = shift;
    my $allowed_composed_cvs = shift;
    my $composable_cvterm_delimiter = shift;
    my $composable_cvterm_format = shift;
    my $cvterm_id_hash = shift;
    my %id_hash = %$cvterm_id_hash;
    delete @id_hash{ grep { scalar @{$id_hash{$_}} < 1 } keys %id_hash }; #remove cvtypes with no ids
    my @id_strings;

    my @ordered_id_groups;
    foreach my $cv_name (@$allowed_composed_cvs){
        push @ordered_id_groups, $id_hash{$cv_name};
    }

    my $id_array_count = scalar(@ordered_id_groups);
    my $concatenated_cvterms;
    foreach (@{$ordered_id_groups[0]}){
        my $name = get_trait_from_cvterm_id($schema, $_, $composable_cvterm_format);
        $concatenated_cvterms->{$name} = [$_];
    }
    for my $n (0 .. $id_array_count-2){
        $concatenated_cvterms = _concatenate_cvterm_array($schema, $composable_cvterm_delimiter, $composable_cvterm_format, $concatenated_cvterms, $ordered_id_groups[$n+1]);
    }
    my %possible_traits = %$concatenated_cvterms;

    #print STDERR "possible traits are: ".Dumper(%possible_traits)."\n";

    my $contains_cvterm_id = $self->get_cvterm_row($schema, 'contains', 'relationship')->cvterm_id();

    my @intersect_selects;
    while(my($key, $value) = each %id_hash){
        if (scalar @$value > 0) {
          my @quoted_ids= map {"'$_'"} @$value;
          my $id_string = join ",", @quoted_ids;
          push @intersect_selects, "SELECT cvterm_id,
                                    (((cvterm.name::text || '|'::text) || db.name::text) || ':'::text) || dbxref.accession::text AS name
                                      FROM cvterm_relationship JOIN cvterm ON(object_id = cvterm_id)
                                      JOIN dbxref USING(dbxref_id)
                                      JOIN db ON(dbxref.db_id = db.db_id)
                                      WHERE type_id = $contains_cvterm_id AND subject_id IN ($id_string)";
        }
    }

    my $intersect_sql = join ' INTERSECT ', @intersect_selects;
    $h = $schema->storage->dbh->prepare($intersect_sql);
    $h->execute();

    my @traits;
    while(my ($id, $name) = $h->fetchrow_array()){
        push @traits, [ $id, $name ];
        if ($composable_cvterm_format eq 'concise'){
            $name =~ s/\|[^\|]+$//; # remove dbname and accession number before using as hash key
        }
        delete($possible_traits{$name});
    }

    my @new_traits;
    while(my($key, $value) = each %possible_traits){
        push @new_traits, [ $value, $key];
    }

    print STDERR "existing traits are: ".Dumper(@traits)." and new traits are".Dumper(@new_traits)."\n";

    return {
      existing_traits => \@traits,
      new_traits => \@new_traits
    };
  }

sub get_traits_from_components {
    my $self= shift;
    my $schema = shift;
    my $component_cvterm_ids = shift;
    my @component_cvterm_ids = @$component_cvterm_ids;

    my $contains_cvterm_id = $self->get_cvterm_row($schema, 'contains', 'relationship')->cvterm_id();

    my $q = "SELECT object_id FROM cvterm_relationship WHERE type_id = ? AND subject_id IN (@{[join',', ('?') x @component_cvterm_ids]}) GROUP BY 1";

    my $h = $schema->storage->dbh->prepare($q);
    $h->execute($contains_cvterm_id, @component_cvterm_ids);
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
