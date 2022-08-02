=head1 NAME

CXGN::Genotype::GenotypingProject - a module for adding crossing experiment

=cut


package CXGN::Genotype::GenotypingProject;


use Moose;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;
use Try::Tiny;
use CXGN::Location::LocationLookup;
use CXGN::Trial;
use SGN::Model::Cvterm;
use Data::Dumper;

has 'chado_schema' => (isa => 'DBIx::Class::Schema',
		 is => 'rw',
		 required => 1,
		);

has 'dbh' => (
    is  => 'rw',
    required => 1,
    );

has 'breeding_program_id' => (isa =>'Int',
    is => 'rw',
    required => 1,
    );

has 'year' => (isa => 'Str',
    is => 'rw',
    required => 1,
    );

has 'project_description' => (isa => 'Str',
    is => 'rw',
    required => 1,
    );

has 'nd_geolocation_id' => (isa => 'Int|Undef',
    is => 'rw',
    required => 0,
    );

has 'project_name' => (isa => 'Str',
    is => 'rw',
    required => 1,
    );

has 'project_facility' => (isa => 'Str',
    is => 'rw',
    required => 1,
    );

has 'data_type' => (isa => 'Str',
    is => 'rw',
    required => 1,
    );

has 'owner_id' => (isa => 'Int',
    is => 'rw',
    );


sub store_genotyping_project {
    print STDERR "Check 4.1:".localtime();
    my $self = shift;
    my $schema = $self->get_chado_schema();

    if ($self->existing_genotyping_project()){
        print STDERR "Can't create genotyping project: Genotyping project name already exists\n";
        return {error => "Genotyping project not saved: Genotyping project name already exists"};
    }

    my $project_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'genotyping_project', 'project_type')->cvterm_id();
	my $genotyping_facility_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'genotyping_facility', 'project_property');
	my $design_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'design', 'project_property');

    my $genotyping_project = $schema->resultset('Project::Project')->create({
        name => $self->get_project_name(),
        description => $self->get_project_description(),
#        type_id => $project_type_cvterm_id
    });

	my $genotyping_project_id = $genotyping_project->project_id();

    my $data_type = $self->get_data_type();
	if ($data_type eq 'ssr'){
		$genotyping_project->create_projectprops({ $design_cvterm->name() => 'pcr_genotype_data_project' });
	} elsif ($data_type eq 'snp'){
		$genotyping_project->create_projectprops({ $design_cvterm->name() => 'genotype_data_project' });
	}

	$genotyping_project->create_projectprops( {$genotyping_facility_cvterm->name() => $self->get_project_facility } );

    my $project = CXGN::Trial->new({
        bcs_schema => $schema,
        trial_id => $genotyping_project_id
    });

    if ($self->get_nd_geolocation_id()){
        $project->set_location($self->get_nd_geolocation_id());
    }
    $project->set_year($self->get_year());
    $project->set_breeding_program($self->get_breeding_program_id);
    $project->set_trial_owner($self->get_owner_id);
    print STDERR "GENOTYPING PROJECT ID =".Dumper($genotyping_project_id);
    return {success=>1, trial_id=>$genotyping_project_id};

}


sub existing_genotyping_project {
    my $self = shift;
    my $project_name = $self->get_project_name();
    my $schema = $self->get_chado_schema();
    if($schema->resultset('Project::Project')->find({name=>$project_name})){
        return 1;
    }
    else{
        return;
    }
}





#########
1;
#########
