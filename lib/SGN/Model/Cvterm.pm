
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

    #for mutiterm trait_name of form term1|CHEBI:0000001||term2|CASSTIME:0000002||term3|CASSTISS:0000001
    if ($trait_name =~ /\|\|/ ) {
        my @term_array = split(/\|\|/, $trait_name);
        my $like_search = '%';
        foreach (@term_array){
            my ( $full_cvterm_name, $full_accession) = split (/\|/, $_);
            $like_search .= "$full_accession%";
        }
        my $trait_cvterm = $schema->resultset("Cv::Cvterm")->search({ name => { like => $like_search } })->single();
        return $trait_cvterm;
    }

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

1;
