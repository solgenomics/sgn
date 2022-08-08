
=head1 NAME

CXGN::Genotype::GenotypingProject - an object representing a genotyping project in the database

=head1 DESCRIPTION

    my $genotyping_project = CXGN::Genotype::GenotypingProject->new( { schema => $schema, trial_id => 37347 });


=head1 AUTHORS

    Titima Tantikanjana

=head1 METHODS

=cut
package CXGN::Genotype::GenotypingProject;

use Moose;
use SGN::Model::Cvterm;
use Data::Dumper;
use JSON;
use CXGN::Trial::Search;

has 'bcs_schema' => (
    isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1,
);

has 'project_id' => (
    isa => 'Int',
    is => 'rw',
    required => 1,
);

has 'genotyping_plate_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw',
);



sub BUILD {

    my $self = shift;
    my $schema = $self->bcs_schema();
    my $genotyping_project_id = $self->project_id();

    my $genotyping_project_relationship_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'genotyping_project_and_plate_relationship', 'project_relationship');
    my $relationships_rs = $schema->resultset("Project::ProjectRelationship")->search ({
        object_project_id => $genotyping_project_id,
        type_id => $genotyping_project_relationship_cvterm->cvterm_id()
    });

    my @plate_list;
    if ($relationships_rs) {
        while (my $each_relationship = $relationships_rs->next()) {
    	    push @plate_list, $each_relationship->subject_project_id();
        }
    }

    $self->genotyping_plate_list(\@plate_list);

}


sub get_plate_info {
    my $self = shift;
    my $schema = $self->bcs_schema();
    my $plate_list = $self->genotyping_plate_list();
    print STDERR "PLATE LIST =".Dumper($plate_list)."\n";
    my $trial_search = CXGN::Trial::Search->new({
        bcs_schema => $schema,
        trial_design_list => ['genotyping_plate'],
        trial_id_list => $plate_list
    });
    my ($data, $total_count) = $trial_search->search();
    print STDERR "PLATE DATA =".Dumper($data)."\n";

    return $data;

}


1;
