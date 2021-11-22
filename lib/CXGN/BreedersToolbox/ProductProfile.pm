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

use JSON::Any;
use Data::Dumper;
use SGN::Model::Cvterm;

has 'people_schema' => (isa => 'Ref', is => 'rw', required => 1);

has 'dbh' => (is  => 'rw', required => 1);

has 'sp_product_profile_id' => (isa => 'Int', is => 'rw');

has 'sp_stage_gate_id' => (isa => 'Int', is => 'rw');

has 'name' => (isa => 'Str', is => 'rw');

has 'scope' => (isa => 'Str', is => 'rw');

has 'sp_person_id' => (isa => 'Int', is => 'rw');

has 'create_date' => (isa => 'Str', is => 'rw');

has 'modified_date' => (isa => 'Str', is => 'rw');

#has 'product_profile_details' => (isa => 'Str', is => 'rw', required => 1);


sub BUILD {
    my $self = shift;
    my $args = shift;
    my $people_schema = $self->people_schema();

    if (! $args->{sp_product_profile_id}) {
	print STDERR "Creating empty object...\n";
	return $self;
    }

    my $row = $people_schema->resultset('SpProductProfile')->find( { sp_product_profile_id => $args->{sp_product_profile_id} } );

    if (!$row) {
	die "The database has no product profile entry with id $args->{sp_product_profile_id}";
    }

}


sub store {
    my $self = shift;
    my %data = (
	sp_stage_gate_id => $self->sp_stage_gate_id(),
	name => $self->name(),
	scope => $self->scope(),
	sp_person_id => $self->sp_person_id(),
    create_date => $self->create_date(),
    modified_date => $self->modified_date(),
	);

    if ($self->sp_product_profile_id()) { $data{sp_product_profile_id} = $self->sp_product_profile_id(); }

    my $rs = $self->people_schema()->resultset('SpProductProfile');

    my $row = $rs->update_or_create( \%data );

    print STDERR "SP PRODUCT PROFILE ID =".Dumper($row->sp_product_profile_id())."\n";
    return $row->sp_product_profile_id();
}



#sub BUILD {
#    my $self = shift;
#    my $args = shift;

#    $self->prop_table('projectprop');
#    $self->prop_namespace('Project::Projectprop');
#    $self->prop_primary_key('projectprop_id');
#    $self->prop_type('product_profile_json');
#    $self->cv_name('project_property');
#    $self->allowed_fields([ qw | product_profile_name product_profile_scope product_profile_details product_profile_submitter product_profile_uploaded_date | ]);
#    $self->parent_table('project');
#    $self->parent_primary_key('project_id');

#    $self->load();
#}


#sub get_product_profile_info {
#    my $self = shift;
#    my $schema = $self->bcs_schema();
#    my $project_id = $self->parent_id();
#    my $type = $self->prop_type();
#    my $type_id = $self->_prop_type_id();
#    my $key_ref = $self->allowed_fields();
#    my @fields = @$key_ref;

#    my $profile_rs = $schema->resultset("Project::Projectprop")->search({ project_id => $project_id, type_id => $type_id }, { order_by => {-asc => 'projectprop_id'} });
#    my @profile_list;
#    while (my $r = $profile_rs->next()){
#        my @each_row = ();
#        my $profile_id = $r->projectprop_id();
#        push @each_row, $profile_id;
#        my $profile_json = $r->value();
#        my $profile_hash = JSON::Any->jsonToObj($profile_json);
#        foreach my $field (@fields){
#            push @each_row, $profile_hash->{$field};
#        }
#        push @profile_list, [@each_row];
#    }
#    print STDERR "PROFILE LIST =".Dumper(\@profile_list)."\n";

#    return \@profile_list;
#}


1;
