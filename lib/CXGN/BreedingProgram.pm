=head1 NAME

CXGN::BreedingProgram - class for retrieving breeding program information and filtering by location/s, year/s, etc.

=head1 AUTHORS

Naama Menda <nm249@cornell.edu>


=head1 METHODS

=cut

package CXGN::BreedingProgram;

use Moose;
use Data::Dumper;
use Try::Tiny;
use SGN::Model::Cvterm;
use CXGN::BreedersToolbox::Projects;
use JSON;

has 'schema' => (
    isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1,
);

sub BUILD {
    my $self = shift;
    my $breeding_program_cvterm_id = $self->get_breeding_program_cvterm_id;

    print STDERR "BREEDING PROGRAM CVTERM ID: $breeding_program_cvterm_id\n";

    $self->schema->storage->debug(1);
    my $rs = $self->schema->resultset("Project::Project")->search(
	{ 'me.project_id'             => $self->get_program_id(),
	  'projectprops.type_id' => $breeding_program_cvterm_id },
	{ join => 'projectprops' }
	);

    if ($rs->count() > 1) { print STDERR  "Multiple projectprop attributes for trial!!!"; }

    if ($rs->count() == 0) {
	die "The breeding program  ".$self->get_program_id()." does not exist";
    }

    if ($rs->count() == 1) {
	print STDERR "We have a breeding program!\n";
    }
    
    my $row = $rs->next();
    
    $self->schema->storage->debug(0);
    $self->set_project_object($row);

}

=head2 accessors get_program_id()

 Desc: get the breeding program project_id

=cut

has 'program_id' => (isa => 'Int',
		     is => 'rw',
		     reader => 'get_program_id',
		     writer => 'set_program_id',
    );



=head2 accessors get_name, set_name

 Usage:
 Desc:
 Property
 Side Effects:
 Example:

=cut

sub get_name {
    my $self = shift;
    my $project_obj = $self->get_project_object;

    if ($project_obj) {
	return $project_obj->name();
    }
}

sub set_name {
    my $self = shift;
    my $name = shift;
    my $project_obj = $self->get_project_object;
    if ($project_obj) {
	$project_obj->name($name);
	$project_obj->update();
    }
}

sub get_project_object {
  my $self = shift;
  return $self->{project_object};
}

sub set_project_object {
  my $self = shift;
  $self->{project_object} = shift;
}


=head2 accessors get_description, set_description

 Usage:
 Desc:
 Property
 Side Effects:
 Example:

=cut

sub get_description {
  my $self = shift;
  return $self->{description};
}

sub set_description {
  my $self = shift;
  $self->{description} = shift;
}


sub get_breeding_program_cvterm_id {
    my $self = shift;

    my $breeding_program_cvterm_id;
    my $breeding_program_cvterm = SGN::Model::Cvterm->get_cvterm_row($self->schema, 'breeding_program', 'project_property');
    if ($breeding_program_cvterm) {
        $breeding_program_cvterm_id = $breeding_program_cvterm->cvterm_id();
    }
    return $breeding_program_cvterm_id;
}

sub get_project_year_cvterm_id {
    my $self = shift;
    my $year_cvterm_row = SGN::Model::Cvterm->get_cvterm_row( $self->schema, 'project year', 'project_property' );
    return $year_cvterm_row->cvterm_id();
}

sub get_accession_cvterm_id {
    my $self = shift;
    my $accession_cvterm_row = SGN::Model::Cvterm->get_cvterm_row( $self->schema, 'accession', 'stock_type' );
    return $accession_cvterm_row->cvterm_id();
}
=head2 get_trials

 Usage: $self->get_trials
 Desc:  find the trials (projects) associated with the breeding program. Will fetch only trials that have a design. This is to avoid printing crosses etc.
 Ret:   BCS Project resultset
 Args:  none
 Side Effects: none
 Example:

=cut

sub get_trials {
    my $self = shift;
    my $project_obj = $self->get_project_object;

    my $trials_rs;
    my $trials_fetched;
    my $trial_rel_rs = $project_obj->project_relationship_object_projects;

    if ($trial_rel_rs) {
	my $design_cvterm = SGN::Model::Cvterm->get_cvterm_row($self->schema, 'design', 'project_property');
	$trials_rs = $trial_rel_rs->search_related('subject_project');
	$trials_fetched = $trials_rs->search(
	    {
		'projectprops.type_id' => $design_cvterm->cvterm_id
	    },
	    {
		join => 'projectprops'
	    }
	    );
    }
    return $trials_fetched;
}


=head2 function get_traits_assayed()
 Usage:
 Desc: Find the traits assayed in the breeding program
 Ret:  arrayref of [cvterm_id, cvterm_name]
 Args:
 Side Effects:
 Example:

=cut
sub get_traits_assayed {
    my $self= shift;
    my $dbh = $self->schema->storage()->dbh();

    my $trials = $self->get_trials;
    my @trial_ids;
    while (my $trial = $trials->next() ) {
	my $trial_id = $trial->project_id;
	push @trial_ids , $trial_id;
    }
    my $trial_ids = join ',', map { "?" } @trial_ids;
    my @traits_assayed;

    my $q;
    if ($trial_ids) {
	$q = "SELECT (((cvterm.name::text || '|'::text) || db.name::text) || ':'::text) || dbxref.accession::text AS trait, cvterm.cvterm_id, count(phenotype.value) FROM cvterm JOIN dbxref ON cvterm.dbxref_id = dbxref.dbxref_id JOIN db ON dbxref.db_id = db.db_id JOIN phenotype ON (cvterm_id=cvalue_id) JOIN nd_experiment_phenotype USING(phenotype_id) JOIN nd_experiment_project USING(nd_experiment_id) WHERE project_id in ( $trial_ids )  and phenotype.value~? GROUP BY trait, cvterm.cvterm_id ORDER BY trait;";


	my $traits_assayed_q = $dbh->prepare($q);

	my $numeric_regex = '^-?[0-9]+([,.][0-9]+)?$';
	$traits_assayed_q->execute(@trial_ids, $numeric_regex );
	while (my ($trait_name, $trait_id, $count) = $traits_assayed_q->fetchrow_array()) {
	    push @traits_assayed, [$trait_id, $trait_name];
	}
    }
    return \@traits_assayed;
}

=head2 get_locations

 Usage: my $locations = $breeding_program->get_locations()
 Desc:  find nd_geolocations by breeding program
 Ret:   NdGeolocation resultset
 Args:  none
 Side Effects: calls get_trials
 Example:

=cut

sub get_locations {
    my $self = shift;
    my $trials = $self->get_trials();
    my $nd_exp_projects = $trials->nd_experiment_projects;
    my $locations;

    if ( $nd_exp_projects ) {
	$locations = $nd_exp_projects->nd_experiment->nd_geolocation;
    }
    return $locations
}


=head2 get_years

 Usage:
 Desc:
 Ret: arrayref of project year values from projectprop
 Args:
 Side Effects: calls $self->get_trials
 Example:

=cut

sub get_years {
    my $self = shift;
    my $trials = $self->get_trials();
    my $project_year_cvterm_id = $self->get_project_year_cvterm_id;
    my $trialprops_rs = $trials->projectprops->search( { type_id=>$project_year_cvterm_id }, { distinct => 1, } );
    my @years = $trialprops_rs->value;
    return \@years;
}

=head2 get_accessions

 Usage: $self->get_accessions
 Desc:
 Ret: list of stock IDs
 Args:
 Side Effects:
 Example:

=cut

sub get_accessions {
    my $self = shift;
    my $program_id = $self->get_program_id;
    my $dbh = $self->schema->storage()->dbh();

    my $q = "SELECT distinct acc.stock_id, acc.uniquename FROM stock AS acc
             JOIN  stock_relationship ON object_id = acc.stock_id
             JOIN  stock AS plot ON plot.stock_id = stock_relationship.subject_id
             JOIN nd_experiment_stock ON nd_experiment_stock.stock_id = plot.stock_id
             JOIN nd_experiment_project using (nd_experiment_id)
             JOIN project trial ON trial.project_id = nd_experiment_project.project_id
             JOIN project_relationship ON project_relationship.subject_project_id = trial.project_id
             JOIN project program ON program.project_id = project_relationship.object_project_id
             WHERE program.project_id = ? AND acc.type_id = ?;";
    $q = $dbh->prepare($q);
    $q->execute($program_id, $self->get_accession_cvterm_id);

    my @accessions;
    while (my ( $acc_id, $acc_name ) = $q->fetchrow_array()) {
	push @accessions,  $acc_id;
    }
    return \@accessions;
}

=head2 get_locations_with_details

 Usage: my $locations = $breeding_program->get_locations_with_details()

=cut

sub get_locations_with_details {
    my $self = shift;
    my $schema = $self->schema;
    my $project_obj = $self->get_project_object;
    my $program_name = $project_obj->name;
#    print STDERR "PROGRAM NAME =".Dumper($program_name)."\n";
    my $obj = CXGN::BreedersToolbox::Projects->new({schema => $schema});
    my $all_locations = $obj->get_location_geojson_data();

    my @program_locations;
    foreach my $location_hash (@$all_locations) {
        my $location = $location_hash->{'properties'};
        my $name = $location->{'Program'};
        if ($name eq $program_name) {
            push @program_locations, $location_hash;
        }
    }

    my $json = JSON->new();
    $json->canonical(); # output sorted JSON
    return $json->encode(\@program_locations);
}


=head2 get_crosses

 Usage: $self->get_crosses
 Desc:
 Ret: crosses with parents
 Args:
 Side Effects:
 Example:

=cut

sub get_crosses {
    my $self = shift;
    my $program_id = $self->get_program_id;
    my $schema = $self->schema;
    my $dbh = $self->schema->storage()->dbh();
    my $cross_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'cross', 'stock_type')->cvterm_id();
    my $female_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'female_parent', 'stock_relationship')->cvterm_id();
    my $male_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'male_parent', 'stock_relationship')->cvterm_id();

    my $q = "select stock.stock_id, stock.uniquename, female.stock_id, female.uniquename, male.stock_id, male.uniquename, stock_relationship1.value
        From stock join stock_relationship as stock_relationship1 on (stock.stock_id = stock_relationship1.object_id) and stock_relationship1.type_id = ?
        JOIN stock as female on (stock_relationship1.subject_id = female.stock_id)
        LEFT JOIN stock_relationship as stock_relationship2 on (stock.stock_id = stock_relationship2.object_id) and stock_relationship2.type_id = ?
        LEFT JOIN stock as male on (stock_relationship2.subject_id = male.stock_id)
        LEFT JOIN nd_experiment_stock on (stock.stock_id = nd_experiment_stock.stock_id)
        LEFT JOIN nd_experiment_project on (nd_experiment_stock.nd_experiment_id = nd_experiment_project.nd_experiment_id)
        LEFT JOIN project_relationship on (project_relationship.subject_project_id = nd_experiment_project.project_id)  where stock.type_id = ? and project_relationship.object_project_id = ?;";

    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute($female_cvterm_id, $male_cvterm_id, $cross_cvterm_id, $program_id);

    my @crosses = ();
    while (my($cross_id, $cross_name, $female_parent_id, $female_parent_name, $male_parent_id, $male_parent_name, $cross_type) = $h->fetchrow_array()){
        push @crosses, [$cross_id, $cross_name, $female_parent_id, $female_parent_name, $male_parent_id, $male_parent_name, $cross_type]
    }

    return \@crosses;

}


=head2 get_seedlots

 Usage: $self->get_seedlots
 Desc:
 Ret: seedlot with content
 Args:
 Side Effects:
 Example:

=cut

sub get_seedlots {
    my $self = shift;
    my $program_id = $self->get_program_id;
    my $schema = $self->schema;
    my $dbh = $self->schema->storage()->dbh();
    my $seedlot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'seedlot', 'stock_type')->cvterm_id();
    my $collection_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'collection_of', 'stock_relationship')->cvterm_id();

    my $q = "select stock.stock_id, stock.uniquename, content.stock_id, content.uniquename, cvterm.name
        From stock join stock_relationship on (stock.stock_id = stock_relationship.object_id) and stock_relationship.type_id = ?
        JOIN stock as content on (stock_relationship.subject_id = content.stock_id)
        JOIN cvterm on (content.type_id = cvterm.cvterm_id)
        JOIN nd_experiment_stock on (stock.stock_id = nd_experiment_stock.stock_id)
        JOIN nd_experiment_project on (nd_experiment_stock.nd_experiment_id = nd_experiment_project.nd_experiment_id)
        where stock.type_id = ? and nd_experiment_project.project_id = ?;";

    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute($collection_of_cvterm_id, $seedlot_cvterm_id, $program_id);

    my @seedlots = ();
    while (my($seedlot_id, $seedlot_name, $content_id, $content_name, $content_type) = $h->fetchrow_array()){
        push @seedlots, [$seedlot_id, $seedlot_name, $content_id, $content_name, $content_type]
    }

    return \@seedlots;

}




####
1;##
####
