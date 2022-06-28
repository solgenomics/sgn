package CXGN::BreedersToolbox::SoilData;


=head1 NAME

CXGN::BreedersToolbox::SoilData - a class to manage soil data

=head1 DESCRIPTION

The projectprop of type "soil_data_json" is stored as JSON.

=head1 EXAMPLE

my $soil_data = CXGN::BreedersToolbox::SoilData->new( { schema => $schema});

=head1 AUTHOR

Titima Tantikanjana <tt15@cornell.edu>

=cut


use Moose;

extends 'CXGN::JSONProp';

use JSON::Any;
use Data::Dumper;
use SGN::Model::Cvterm;


has 'description' => (isa => 'Str', is => 'rw');

has 'year' => (isa => 'Maybe[Str]', is => 'rw');

has 'gps' => (isa => 'Maybe[Str]', is => 'rw');

has 'type_of_sampling' => (isa => 'Str', is => 'rw');

has 'data_type_order' => (isa => 'ArrayRef', is => 'rw');

has 'soil_data_details' => (isa => 'HashRef', is => 'rw');


sub BUILD {
    my $self = shift;
    my $args = shift;

    $self->prop_table('projectprop');
    $self->prop_namespace('Project::Projectprop');
    $self->prop_primary_key('projectprop_id');
    $self->prop_type('soil_data_json');
    $self->cv_name('project_property');
    $self->allowed_fields([ qw | description year gps type_of_sampling data_type_order soil_data_details | ]);
    $self->parent_table('project');
    $self->parent_primary_key('project_id');

    $self->load();
}


sub get_soil_data {
    my $self = shift;
    my $schema = $self->bcs_schema();
    my $project_id = $self->parent_id();
    my $type = $self->prop_type();
    my $type_id = $self->_prop_type_id();
    my $key_ref = $self->allowed_fields();
    my @fields = @$key_ref;

    my $soil_data_rs = $schema->resultset("Project::Projectprop")->search({ project_id => $project_id, type_id => $type_id }, { order_by => {-asc => 'projectprop_id'} });
    my @soil_data_list;
    while (my $r = $soil_data_rs->next()){
        my $prop_id = $r->projectprop_id();
        my $soil_data_json = $r->value();
        my $soil_data_hash = JSON::Any->jsonToObj($soil_data_json);
        my $description = $soil_data_hash->{'description'};
        my $year = $soil_data_hash->{'year'};
        my $gps = $soil_data_hash->{'gps'};
        my $type_of_sampling = $soil_data_hash->{'type_of_sampling'};
        push @soil_data_list, [$prop_id, $description, $year, $gps, $type_of_sampling];
    }
#    print STDERR "PROFILE LIST =".Dumper(\@profile_list)."\n";

    return \@soil_data_list;
}



1;
