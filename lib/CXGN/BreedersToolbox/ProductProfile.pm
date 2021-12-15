package CXGN::BreedersToolbox::ProductProfile;


=head1 NAME

CXGN::BreedersToolbox::ProductProfile - a class to manage product profile

=head1 DESCRIPTION

The SpProductProfileprop of type "product_profile_json" is stored as JSON.

=head1 EXAMPLE

my $profile = CXGN::BreedersToolbox::ProductProfile->new( { people_schema => $people_schema});

=head1 AUTHOR

Titima Tantikanjana <tt15@cornell.edu>

=cut


use Moose;

use JSON::Any;
use Data::Dumper;
use SGN::Model::Cvterm;
use JSON;

has 'people_schema' => (isa => 'Ref', is => 'rw', required => 1);

has 'dbh' => (isa => 'Ref', is  => 'rw');

has 'sp_product_profile_id' => (isa => 'Int', is => 'rw');

has 'sp_stage_gate_id' => (isa => 'Int', is => 'rw');

has 'name' => (isa => 'Str', is => 'rw');

has 'scope' => (isa => 'Str', is => 'rw');

has 'sp_person_id' => (isa => 'Int', is => 'rw');

has 'create_date' => (isa => 'Str', is => 'rw');

has 'modified_date' => (isa => 'Str', is => 'rw');

has 'sp_market_segment_id' => (isa => 'Int', is => 'rw');


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
        name => $self->name(),
        scope => $self->scope(),
        sp_person_id => $self->sp_person_id(),
        create_date => $self->create_date(),
        modified_date => $self->modified_date(),
	);

    if ($self->sp_product_profile_id()) {
        $data{sp_product_profile_id} = $self->sp_product_profile_id();
    }

    my $rs = $self->people_schema()->resultset('SpProductProfile');

    my $row = $rs->update_or_create( \%data );
    my $product_profile_id = $row->sp_product_profile_id();

    my %market_segment_link_data = (
        sp_product_profile_id => $product_profile_id,
        sp_market_segment_id => $self->sp_market_segment_id(),
        sp_person_id => $self->sp_person_id(),
        create_date => $self->create_date(),
	);

    my $market_segment_link_rs = $self->people_schema()->resultset('SpProductProfileSegment');

    my $market_segment_link_row = $market_segment_link_rs->update_or_create( \%market_segment_link_data );
    my $product_profile_segment_id = $market_segment_link_row->sp_product_profile_segment_id();

    return $product_profile_id;
}


sub get_product_profile_info {

    my $self = shift;
    my $people_schema = $self->people_schema();
    my $dbh = $self->dbh();

    my $product_profile_rs = $people_schema->resultset('SpProductProfile')->search( { } );
    my @product_profiles;
    while (my $result = $product_profile_rs->next()){
        my $profile_detail_string;
        my $product_profile_id = $result->sp_product_profile_id();
        my $product_profile_name = $result->name();
        my $product_profile_scope = $result->scope();
        my $person_id = $result->sp_person_id();
        my $create_date = $result->create_date();
        my $modified_date = $result->modified_date();

        my $person= CXGN::People::Person->new($dbh, $person_id);
        my $person_name=$person->get_first_name()." ".$person->get_last_name();

        my $product_profileprop_rs = $people_schema->resultset('SpProductProfileprop')->search( { sp_product_profile_id => $product_profile_id } );
        while (my $product_profile_details = $product_profileprop_rs->next()){
            my $profile_detail_json = $product_profile_details->value();
            my $profile_detail_hash = JSON::Any->jsonToObj($profile_detail_json);
            $profile_detail_string = $profile_detail_hash->{'product_profile_details'};
        }

        push @product_profiles, [$product_profile_id, $product_profile_name, $product_profile_scope, $profile_detail_string, $person_name, $create_date, $modified_date ];
    }

    return \@product_profiles;
}


1;
