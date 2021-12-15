package CXGN::BreedersToolbox::MarketSegment;


=head1 NAME

CXGN::BreedersToolbox::MarketSegment - a class to manage market segment

=head1 DESCRIPTION


=head1 EXAMPLE

my $market_segment = CXGN::BreedersToolbox::MarketSegment->new( { people_schema => $people_schema});

=head1 AUTHOR

Titima Tantikanjana <tt15@cornell.edu>

=cut


use Moose;

use JSON::Any;
use Data::Dumper;
use SGN::Model::Cvterm;
use JSON;

has 'people_schema' => (isa => 'Ref', is => 'rw', required => 1);

has 'dbh' => (is  => 'rw', required => 1);

has 'sp_market_segment_id' => (isa => 'Int', is => 'rw');

has 'name' => (isa => 'Str', is => 'rw');

has 'scope' => (isa => 'Str', is => 'rw');

has 'sp_person_id' => (isa => 'Int', is => 'rw');

has 'create_date' => (isa => 'Str', is => 'rw');

has 'modified_date' => (isa => 'Str', is => 'rw');


sub BUILD {
    my $self = shift;
    my $args = shift;
    my $people_schema = $self->people_schema();

    if (! $args->{sp_product_profile_id}) {
        print STDERR "Creating empty object...\n";
        return $self;
    }

    my $row = $people_schema->resultset('SpMarketSegment')->find( { sp_market_segment_id => $args->{sp_market_segment_id} } );

    if (!$row) {
        die "The database has no market segment entry with id $args->{sp_market_segment_id}";
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

    if ($self->sp_market_segment_id()) {
        $data{sp_market_segment_id} = $self->sp_market_segment_id();
    }

    my $rs = $self->people_schema()->resultset('SpMarketSegment');
    my $row = $rs->update_or_create( \%data );

    return $row->sp_market_segment_id();
}


sub get_market_segments {
    my $self = shift;
    my $people_schema = $self->people_schema();
    my $dbh = $self->dbh();

    my $market_segment_rs = $people_schema->resultset('SpMarketSegment')->search( { } );
    my @market_segments;
    while (my $result = $market_segment_rs->next()){
        my $market_segment_id = $result->sp_market_segment_id();
        my $market_segment_name = $result->name();
        my $market_segment_scope = $result->scope();
        my $person_id = $result->sp_person_id();
        my $create_date = $result->create_date();
        my $modified_date = $result->modified_date();

        my $product_profile_link_rs = $people_schema->resultset('SpProductProfileSegment')->search({ sp_market_segment_id => $market_segment_id });
        my @all_product_profiles;
        while (my $product_profile_result = $product_profile_link_rs->next()){
            my $product_profile_id = $product_profile_result->sp_product_profile_id();
            my $profile_name = $people_schema->resultset('SpProductProfile')->find({sp_product_profile_id => $product_profile_id})->name();
            push @all_product_profiles, $profile_name;
        }

        my @sort_product_profile_names = sort @all_product_profiles;
        my $profile_name_string = join("<br>", @sort_product_profile_names);

        my $person= CXGN::People::Person->new($dbh, $person_id);
        my $person_name=$person->get_first_name()." ".$person->get_last_name();
        push @market_segments, [$market_segment_name, $market_segment_scope, $profile_name_string, $person_name, $create_date, $modified_date ];
    }

    return \@market_segments;
}

1;
