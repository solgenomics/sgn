package CXGN::Trial::TrialLayout;

=head1 NAME

CXGN::Trial::TrialLayout - Module to get layout information about a trial

=head1 SYNOPSIS

    This object has been converted to a factory object that will produce different classes
    based on the experiment_type. The usage has been kept the same for backwards compatibility,
    but a cleaner factory object implementation should be adopted in the future.

 my $trial_layout = CXGN::Trial::TrialLayout->new({
    schema => $schema,
    trial_id => $trial_id,
    experiment_type => $experiment_type #Either 'field_layout' or 'genotyping_layout'
 });
 my $tl = $trial_layout->get_design();

 This module handles both retrieval of field_layout and genotyping_layout experiments.

 If experiment_type is field_layout, get_design returns a hash representing
 all the plots, with their design info and plant info and samples info. The return is
 a HashRef of HashRef where the keys are the plot_number such as:

 {
    '1001' => {
        "plot_name" => "plot1",
        "plot_number" => 1001,
        "plot_id" => 1234,
        "accession_name" => "accession1",
        "accession_id" => 2345,
        "block_number" => 1,
        "row_number" => 2,
        "col_number" => 3,
        "rep_number" => 1,
        "is_a_control" => 1,
        "seedlot_name" => "seedlot1",
        "seedlot_stock_id" => 3456,
        "num_seed_per_plot" => 12,
        "seed_transaction_operator" => "janedoe",
        "plant_names" => ["plant1", "plant2"],
        "plant_ids" => [3456, 3457],
        "plot_geo_json" => {}
    }
 }

 If experiment_type is genotyping_layout, get_design returns a hash representing
 all wells in a plate, with the tissue_sample name in each well and its accession.
 The return is a HashRef of HashRef where the keys are the well number such as:

 {
    'A01' => {
        "plot_name" => "mytissuesample_A01",
        "stock_name" => "accession1",
        "plot_number" => "A01",
        "row_number" => "A",
        "col_number" => "1",
        "is_blank" => 0,
        "concentration" => "2",
        "volume" => "4",
        "dna_person" => "nmorales",
        "acquisition_date" => "2018/01/09",
        "tissue_type" => "leaf",
        "extraction" => "ctab",
        "ncbi_taxonomy_id" => "1001",
        "source_observation_unit_name" => "plant1",
        "source_observation_unit_id" => "9091"
    }
 }

 By using get_design(), this module attempts to get the design from a
 projectprop called 'trial_layout_json', but if it cannot be found it calls
 generate_and_cache_layout() to generate the design, return it, and store it
 using that projectprop.

--------------------------------------------------------------------------

This can also be used the verify that a layout has a physical map covering all
plots, as well as verifying that the relationships between entities are valid
by doing:

my $trial_layout = CXGN::Trial::TrialLayout->new({
    schema => $schema,
    trial_id => $c->stash->{trial_id},
    experiment_type => $experiment_type, #Either 'field_layout' or 'genotyping_layout'
    verify_layout=>1,
    verify_physical_map=>1
});
my $trial_errors = $trial_layout->generate_and_cache_layout();

If there are errors, $trial_errors is a HashRef like:

{
    "errors" =>
        {
            "layout_errors" => [ "the accession between plot 1 and seedlot 1 is out of sync", "the accession between plot 1 and plant 1 is out of sync" ],
            "seedlot_errors" => [ "plot1 does not have a seedlot linked" ],
            "physical_map_errors" => [ "plot 1 does not have a row_number", "plot 1 does not have a col_number"]
        }
}

=head1 DESCRIPTION


=head1 AUTHORS

 Jeremy D. Edwards (jde22@cornell.edu)

=cut


# use Moose;
# use MooseX::FollowPBP;
# use Moose::Util::TypeConstraints;
# use Try::Tiny;
# use CXGN::Stock::StockLookup;
# use CXGN::Location::LocationLookup;
# use Data::Dumper;
# use SGN::Model::Cvterm;
# use CXGN::Chado::Stock;
# use JSON;

use CXGN::Trial::TrialLayoutFactory;


# has 'schema' => (
#     is       => 'rw',
#     isa      => 'DBIx::Class::Schema',
#     required => 1,
# );

# has 'trial_id' => (
#     isa => 'Int',
#     is => 'rw',
#     predicate => 'has_trial_id',
#     trigger => \&_lookup_trial_id,
#     required => 1
# );

# has 'experiment_type' => (
#     is       => 'rw',
#     isa     => 'Str', #field_layout or genotyping_layout
#     required => 1,
# );




sub new {
    my $class = shift;

    my $args = shift;

    my $factory = CXGN::Trial::TrialLayoutFactory->new();

    my $object = $factory->create( $args );
    
    return $object;

}


1;
