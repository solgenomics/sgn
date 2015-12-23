
=head1 NAME

SGN::Model::Cvterm - a role that provides information on cvterms

=head1 DESCRIPTION

Retrieves cv terms.

get_cvterm_object retrieves the term as a CXGN::Chado::Cvterm object.

get_cvterm_row retrieves the term as a DBIx::Class row.

Both function take a cvterm name and a cv name as an argument.

If a term is not in the database, undef is returned.

This role was added to the SGN.pm website application object.

=head1 AUTHOR

Lukas Mueller

=cut

package SGN::Role::Site::Cvterm;

use Moose::Role;

use CXGN::Chado::Cvterm;

sub get_cvterm_object { 
    my $self = shift;
    my $cvterm_name = shift;
    my $cv_name = shift;

    my $cv = $self->dbic_schema("Bio::Chado::Schema")->resultset('Cv::Cv')->find( { name => $cv_name });

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
    my $name = shift;
    my $cv_name = shift;

    my $schema = $self->dbic_schema('Bio::Chado::Schema');
    my $cvterm = $schema->resultset('Cv::Cvterm')->find( 
        { 
            name => $name,
            'cv.name' => $cv_name,
        }, { join => 'cv' });

    return $cvterm;
}


1;
