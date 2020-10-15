package CXGN::BreedersToolbox::ProductProfile;


=head1 NAME

CXGN::BreedersToolbox::ProductProfile - a class to manage product profile

=head1 DESCRIPTION

The projectprop of type "product_profile_json" is stored as JSON.

=head1 EXAMPLE

my $profile = CXGN::BreedersToolbox::ProductProfile->new( { schema => $schema});

=head1 AUTHOR

Titima Tantikanjana <tt15@cornell.edu>

=cut


use Moose;

extends 'CXGN::JSONProp';

use JSON::Any;
use Data::Dumper;
use SGN::Model::Cvterm;


has 'product_profile_name' => (isa => 'Str', is => 'rw');

has 'product_profile_scope' => (isa => 'Str', is => 'rw');

has 'product_profile_details' => (isa => 'Str', is => 'rw');

has 'product_profile_submitter' => (isa => 'Str', is => 'rw');

has 'product_profile_uploaded_date' => (isa => 'Str', is => 'rw');


sub BUILD {
    my $self = shift;
    my $args = shift;

    $self->prop_table('projectprop');
    $self->prop_namespace('Project::Projectprop');
    $self->prop_primary_key('projectprop_id');
    $self->prop_type('product_profile_json');
    $self->cv_name('project_property');
    $self->allowed_fields([ qw | product_profile_name product_profile_scope product_profile_details product_profile_submitter product_profile_uploaded_date | ]);
    $self->parent_table('project');
    $self->parent_primary_key('project_id');

    $self->load();
}


sub get_product_profile_info {
    my $self = shift;
    my $schema = $self->bcs_schema();
    my $project_id = $self->parent_id();
    my $type = $self->prop_type();
    my $type_id = $self->_prop_type_id();
    my $key_ref = $self->allowed_fields();
    my @fields = @$key_ref;

    my $profile_rs = $schema->resultset("Project::Projectprop")->search({ project_id => $project_id, type_id => $type_id }, { order_by => {-asc => 'projectprop_id'} });
    my @profile_list;
    while (my $r = $profile_rs->next()){
        my @each_row = ();
        my $profile_id = $r->projectprop_id();
        push @each_row, $profile_id;
        my $profile_json = $r->value();
        my $profile_hash = JSON::Any->jsonToObj($profile_json);
        foreach my $field (@fields){
            push @each_row, $profile_hash->{$field};
        }
        push @profile_list, [@each_row];
    }
#    print STDERR "PROFILE LIST =".Dumper(\@profile_list)."\n";

    return \@profile_list;
}


1;
