
=head1 NAME

CXGN::Stock::Seedlot - a class to represent seedlots in the database

=head1 DESCRIPTION

CXGN::Stock::Seedlot inherits from CXGN::Stock.

To create a new seedlot do:
#Seedlot can either be from an accession or a cross, therefore, supply an accession_stock_id OR a cross_stock_id here

my $sl = CXGN::Stock::Seedlot->new(schema => $schema);
$sl->uniquename($seedlot_uniquename);
$sl->location_code($location_code);
$sl->accession_stock_id($accession_id);
$sl->cross_stock_id($cross_id);
$sl->organization_name($organization);
$sl->population_name($population_name);
$sl->breeding_program_id($breeding_program_id);
my $return = $sl->store();
my $seedlot_id = $return->{seedlot_id};

#The first transaction is between the accession_stock_id OR cross_stock_id that you specified above and the new seedlot created.
my $transaction = CXGN::Stock::Seedlot::Transaction->new(schema => $schema);
$transaction->factor(1);
$transaction->from_stock([$from_stock_id, $from_stock_uniquename]);
$transaction->to_stock([$seedlot_id, $seedlot_uniquename]);
$transaction->amount($amount);
$transaction->timestamp($timestamp);
$transaction->description($description);
$transaction->operator($operator);
$transaction->store();

$sl->set_current_count_property();

$phenome_schema->resultset("StockOwner")->find_or_create({
    stock_id     => $seedlot_id,
    sp_person_id =>  $user_id,
});

-------------------------------------------------------------------------------

To Update or Edit a seedlot do:

my $seedlot = CXGN::Stock::Seedlot->new(
    schema => $schema,
    seedlot_id => $seedlot_id,
);
$seedlot->name($seedlot_name);
$seedlot->uniquename($seedlot_name);
$seedlot->breeding_program_id($breeding_program_id);
$seedlot->organization_name($organization);
$seedlot->location_code($location);
$seedlot->accession_stock_id($accession_id);
$seedlot->cross_stock_id($cross_id);
$seedlot->population_name($population);
my $return = $seedlot->store();

------------------------------------------------------------------------------

To Search Across Seedlots do:
# This is different from CXGN::Stock::Search in that is retrieves information pertinent to seedlots like location and current count

my ($list, $records_total) = CXGN::Stock::Seedlot->list_seedlots(
    $c->dbic_schema("Bio::Chado::Schema"),
    $offset,
    $limit,
    $seedlot_name,
    $description,
    $breeding_program,
    $location,
    $minimum_count,
    $contents_accession,
    $contents_cross,
    $exact_match_uniquenames,
    $minimum_weight
);

------------------------------------------------------------------------------

To Retrieve a single seedlot do:

my $seedlot = CXGN::Stock::Seedlot->new(
    schema => $schema,
    seedlot_id => $seedlot_id,
);
# You can access all seedlot accessors from here such as (you can also access all CXGN::Stock accessors):
my $uniquename => $seedlot->uniquename(),
my $seedlot_id => $seedlot->seedlot_id(),
my $current_count => $seedlot->current_count(),
my $location_code => $seedlot->location_code(),
my $breeding_program => $seedlot->breeding_program_name(),
my $organization_name => $seedlot->organization_name(),
my $population_name => $seedlot->population_name(),
my $accession => $seedlot->accession(),
my $cross => $seedlot->cross(),

------------------------------------------------------------------------------

Seed transactions can be added using CXGN::Stock::Seedlot::Transaction.

------------------------------------------------------------------------------

Seed Maintenance Events can be stored and retrieved using the helper functions
in this Seedlot class.

To add a Maintenance Event:

my $seedlot = CXGN::Stock::Seedlot->new( schema => $schema, seedlot_id => $seedlot_id );
my @events = (
    {
        cvterm_id => $cvterm_id,
        value => $value,
        notes => $notes,
        operator => $operator,
        timestamp => $timestamp
    }
);
my $stored_events = $seedlot->store_events(\@events);


=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>
Nick Morales <nm529@cornell.edu>

=head1 ACCESSORS & METHODS

=cut

package CXGN::Stock::Seedlot;

use Moose;
use DateTime;

extends 'CXGN::Stock';

use Data::Dumper;
use CXGN::Stock::Seedlot::Transaction;
use CXGN::BreedersToolbox::Projects;
use SGN::Model::Cvterm;
use CXGN::List::Validate;
use Try::Tiny;
use CXGN::Stock::StockLookup;
use CXGN::Stock::Search;
use JSON::Any;

=head2 Accessor seedlot_id()

the database id of the seedlot. Is equivalent to stock_id.

=cut

has 'seedlot_id' => (
    isa => 'Maybe[Int]',
    is => 'rw',
);

=head2 Accessor location_code()

A string specifiying where the seedlot is stored. On the backend,
this is stored the nd_geolocation description field.

=cut

has 'location_code' => (
    isa => 'Str',
    is => 'rw',
    lazy     => 1,
    builder  => '_retrieve_location',
);

has 'nd_geolocation_id' => (
    isa => 'Int',
    is => 'rw',
    lazy     => 1,
    builder  => '_retrieve_location_id',
);

=head2 Accessor box_name()

A string specifiying box where the seedlot is stored. On the backend,
this is stored as a stockprop.

=cut

has 'box_name' => (
    isa => 'Str|Undef',
    is => 'rw',
    lazy     => 1,
    builder  => '_retrieve_box_name',
);

=head2 Accessor cross()

The crosses this seedlot is a "collection_of". Returns an arrayref of [$cross_stock_id, $cross_uniquename]
# for setter, use cross_stock_id

=cut

has 'cross' => (
    isa => 'ArrayRef|Undef',
    is => 'rw',
    lazy     => 1,
    builder  => '_retrieve_cross',
);

has 'cross_stock_id' =>   (
    isa => 'Int|Undef',
    is => 'rw',
);

=head2 Accessor quality()

Allows to store a string describing the quality of this seedlot. A seedlot with no quality issues has no data stored here. Requested initially by AC.

=cut

has 'quality' => (
    isa => 'Maybe[Str]',
    is => 'rw',
    lazy => 1,
    builder => '_retrieve_quality',
    );

=head2 Accessor material_type()

Material type of this seedlot. Can be seed, root, clone, plant or tissue_culture. Default material type is seed.

=cut

has 'material_type' => (
    isa => 'Maybe[Str]',
    is => 'rw',
    lazy => 1,
    builder => '_retrieve_material_type',
);

=head2 Accessor source()

The source of this seedlot. This can be the plant, plot, or accession it was sourced from, in a seed multiplication experiment, for example, in the absence of a cross experiment. Requested initially by AC.

=cut

has 'source' => (
    isa => 'Str',
    is => 'rw',
    lazy => 1,
    builder => '_retrieve_source',
    );


=head2 Accessor accessions()

The accessions this seedlot is a "collection_of". Returns an arrayref of [$accession_stock_id, $accession_uniquename]
# for setter, use accession_stock_id

=cut

has 'accession' => (
    isa => 'ArrayRef|Undef',
    is => 'rw',
    lazy     => 1,
    builder  => '_retrieve_accession',
);

has 'accession_stock_id' => (
    isa => 'Int|Undef',
    is => 'rw',
);

=head2 Accessor transactions()

a ArrayRef of CXGN::Stock::Seedlot::Transaction objects

=cut

has 'transactions' =>     (
    isa => 'ArrayRef',
    is => 'rw',
    lazy     => 1,
    builder  => '_build_transactions',
);

=head2 Accessor breeding_program

The breeding program this seedlot is from. Useful for tracking movement of seedlots across breeding programs
Use breeding_program_id as setter (to save and update seedlots).

=cut

has 'breeding_program_name' => (
    isa => 'Str',
    is => 'rw',
    lazy     => 1,
    builder  => '_retrieve_breeding_program',
);

has 'breeding_program_id' => (
    isa => 'Int',
    is => 'rw',
    lazy     => 1,
    builder  => '_retrieve_breeding_program_id',
);


after 'stock_id' => sub {
    my $self = shift;
    my $id = shift;
    return $self->seedlot_id($id);
};

# class method
=head2 Class method: list_seedlots()

 Usage:        my $seedlots = CXGN::Stock::Seedlot->list_seedlots($schema);
 Desc:         Class method that returns information on all seedlots
               available in the system
 Ret:          ArrayRef of [ seedlot_id, seedlot name, location_code]
 Args:         $schema - Bio::Chado::Schema object
 Side Effects: accesses the database

=cut

sub list_seedlots {
    my $class = shift;
    my $schema = shift;
    my $people_schema = shift;
    my $phenome_schema = shift;
    my $offset = shift;
    my $limit = shift;
    my $seedlot_name = shift;
    my $description = shift;
    my $breeding_program = shift;
    my $location = shift;
    my $minimum_count = shift;
    my $contents_accession = shift; #arrayref of uniquenames
    my $contents_cross = shift; #arrayref of uniquenames
    my $exact_match_uniquenames = shift;
    my $minimum_weight = shift;
    my $seedlot_id = shift; #added for BrAPI
    my $accession_id = shift; #added for BrAPI
    my $quality = shift;
    my $only_good_quality = shift;
    my $box_name = shift;
    my $contents_cross_db_id = shift;
    my $trial_name = shift;  # name of trial used in a transaction (must also specify trial_usage)
    my $trial_usage = shift; # transaction type (either 'source', 'sink', or 'source|sink')
                             # where the trial is the source, sink, or either of the matching seedlot's seed
    my $material_type = shift;

    select(STDERR);
    $| = 1;
    $schema->storage->debug(1);

    my %unique_seedlots;

    my $type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "seedlot", "stock_type")->cvterm_id();
    my $cross_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "cross", "stock_type")->cvterm_id();
    my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "accession", "stock_type")->cvterm_id();
    my $collection_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, "collection_of", "stock_relationship")->cvterm_id();
    my $current_count_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, "current_count", "stock_property")->cvterm_id();
    my $current_weight_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, "current_weight_gram", "stock_property")->cvterm_id();
    my $experiment_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, "seedlot_experiment", "experiment_type")->cvterm_id();
    my $seedlot_quality_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, "seedlot_quality", "stock_property")->cvterm_id();
    my $location_code_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, "location_code", "stock_property")->cvterm_id();
    my $material_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, "material_type", "stock_property")->cvterm_id();

    my %search_criteria;
    $search_criteria{'me.type_id'} = $type_id;
    $search_criteria{'stock_relationship_objects.type_id'} = $collection_of_cvterm_id;
    if ($seedlot_name) {
        # print STDERR "Adding seedlot name ($seedlot_name) to query...\n";
        $search_criteria{'me.uniquename'} = { 'ilike' => '%'.$seedlot_name.'%' };
    }
    if ($seedlot_id) {
        # print STDERR "Adding seedlot_id ($seedlot_id) to query...\n";
        $search_criteria{'me.stock_id'} = { -in => $seedlot_id };
    }
    if ($breeding_program) {
        # print STDERR "Adding breeding_program $breeding_program to query...\n";
        $search_criteria{'project.name'} = { 'ilike' => '%'.$breeding_program.'%' };
    }
    if ($location) {
        # print STDERR "Adding location $location to query...\n";
        $search_criteria{'nd_geolocation.description'} = { 'ilike' => '%'.$location.'%' };
    }
    if ($contents_accession && scalar(@$contents_accession)>0) {
        # print STDERR "Adding contents accession: $contents_accession ...\n";
        $search_criteria{'subject.type_id'} = $accession_type_id;
        if ($exact_match_uniquenames){
            $search_criteria{'subject.uniquename'} = { -in => $contents_accession };
        } else {
            foreach (@$contents_accession){
                push @{$search_criteria{'subject.uniquename'}}, { 'ilike' => '%'.$_.'%' };
            }
        }
    }
    if ($accession_id && ref($accession_id) && scalar(@$accession_id)>0) {
        print STDERR "Accession ID is ";
        print Dumper $accession_id;
        $search_criteria{'subject.type_id'} = $accession_type_id;
        $search_criteria{'subject.stock_id'} = { -in => $accession_id };
    }
    if ($contents_cross && scalar(@$contents_cross)>0) {
        $search_criteria{'subject.type_id'} = $cross_type_id;
        if ($exact_match_uniquenames){
            $search_criteria{'subject.uniquename'} = { -in => $contents_cross };
        } else {
            foreach (@$contents_cross){
                push @{$search_criteria{'subject.uniquename'}}, { 'ilike' => '%'.$_.'%' };
            }
        }
    }

    if ($contents_cross_db_id && scalar(@$contents_cross_db_id)>0) {
        $search_criteria{'subject.type_id'} = $cross_type_id;
        $search_criteria{'subject.stock_id'} = { -in => $contents_cross_db_id };
    }

    my @seedlot_search_joins = (
        {'nd_experiment_stocks' => {'nd_experiment' => [ {'nd_experiment_projects' => 'project' }, 'nd_geolocation' ] }},
        {'stock_relationship_objects' => 'subject'}
    );

    if ($minimum_count || $minimum_weight || $quality || $only_good_quality || $box_name || $material_type) {
        if ($minimum_count) {
            print STDERR "Minimum count $minimum_count\n";
            $search_criteria{'stockprops.value'} = { '<>' => 'NA' };
            $search_criteria{'stockprops.value::numeric'}  = { '>=' => $minimum_count };
            $search_criteria{'stockprops.type_id'}  = $current_count_cvterm_id;
        } elsif ($minimum_weight) {
            print STDERR "Minimum weight $minimum_weight\n";
            $search_criteria{'stockprops.value'} = { '<>' => 'NA' };
            $search_criteria{'stockprops.value::numeric'}  = { '>=' => $minimum_weight };
            $search_criteria{'stockprops.type_id'}  = $current_weight_cvterm_id;
        }
        if ($quality) {
            print STDERR "Quality $quality\n";
            $search_criteria{'stockprops.value' } = { '=' => $quality };
            $search_criteria{'stockprops.type_id' } = $seedlot_quality_cvterm_id;
        }
        if ($box_name) {
            print STDERR "Box Name $box_name\n";
            $search_criteria{'stockprops.value'} = { 'ilike' => '%'.$box_name.'%' };
            $search_criteria{'stockprops.type_id'} = $location_code_cvterm_id;
        }
        if ($material_type) {
            print STDERR "Material type $material_type\n";
            $search_criteria{'stockprops.value' } = { '=' => $material_type };
            $search_criteria{'stockprops.type_id' } = $material_type_cvterm_id;
        }

        push @seedlot_search_joins, 'stockprops';
    }

    if ($trial_name && $trial_usage) {

        # Build query to get stocks that match the requested transactions
        my @phs;
        my $q = "SELECT subject_id, object_id";
        $q .= " FROM public.stock_relationship";
        $q .= " WHERE type_id = (SELECT cvterm_id FROM public.cvterm WHERE name = 'seed transaction')";

        # Subquery to get stocks (plots, etc) in requested trial
        my $sq = "SELECT DISTINCT(observationunit_stock_id) FROM public.materialized_phenotype_jsonb_table WHERE trial_name = ?";
        my @filters;

        # Add source transaction (plot --> seedlot)
        if ( $trial_usage =~ m/source/ ) {
            push @filters, "object_id IN ($sq)";
            push @phs, $trial_name;
        }

        # Add sink transaction (seedlot --> plot)
        if ( $trial_usage =~ m/sink/ ) {
            push @filters, "subject_id IN ($sq)";
            push @phs, $trial_name;
        }

        # Add filters to main query
        $q .= " AND (" . join(" OR ", @filters) . ")";

        # Execute query
        my @seedlot_ids;
        my $h = $schema->storage->dbh()->prepare($q);
        $h->execute(@phs);
        while ( my ($subject_id, $object_id) = $h->fetchrow_array() ) {
            push @seedlot_ids, $subject_id;
            push @seedlot_ids, $object_id;
        }

        # Add Seedlot IDs as filter to overall seedlot query
        $search_criteria{'me.stock_id'} = { -in => \@seedlot_ids };
    }

    my $rs = $schema->resultset("Stock::Stock")->search(
        \%search_criteria,
        {
            join => \@seedlot_search_joins,
            '+select'=>['project.name', 'project.project_id', 'subject.stock_id', 'subject.uniquename', 'subject.type_id', 'nd_geolocation.description', 'nd_geolocation.nd_geolocation_id'],
            '+as'=>['breeding_program_name', 'breeding_program_id', 'source_stock_id', 'source_uniquename', 'source_type_id', 'location', 'location_id'],
            order_by => {-asc=>'project.name'},
            #distinct => 1
        }
    );

    my %source_types_hash = ( $type_id => 'seedlot', $accession_type_id => 'accession', $cross_type_id => 'cross' );
    my $records_total = $rs->count();
    if (defined($limit) && defined($offset)){
        $rs = $rs->slice($offset, $limit);
    }
    my %seen_seedlot_ids;
    while (my $row = $rs->next()) {
        $seen_seedlot_ids{$row->stock_id}++;

        $unique_seedlots{$row->uniquename}->{seedlot_stock_id} = $row->stock_id;
        $unique_seedlots{$row->uniquename}->{seedlot_stock_uniquename} = $row->uniquename;
        $unique_seedlots{$row->uniquename}->{seedlot_stock_description} = $row->description;
        $unique_seedlots{$row->uniquename}->{breeding_program_name} = $row->get_column('breeding_program_name');
        $unique_seedlots{$row->uniquename}->{breeding_program_id} = $row->get_column('breeding_program_id');
        $unique_seedlots{$row->uniquename}->{location} = $row->get_column('location');
        $unique_seedlots{$row->uniquename}->{location_id} = $row->get_column('location_id');

        push @{$unique_seedlots{$row->uniquename}->{source_stocks}}, [$row->get_column('source_stock_id'), $row->get_column('source_uniquename'), $source_types_hash{$row->get_column('source_type_id')}];
    }

    my @seen_seedlot_ids = keys %seen_seedlot_ids;
    my $stock_lookup = CXGN::Stock::StockLookup->new({ schema => $schema} );
    my $owners_hash = $stock_lookup->get_owner_hash_lookup(\@seen_seedlot_ids);

    my $stock_search = CXGN::Stock::Search->new({
        bcs_schema=>$schema,
        people_schema=>$people_schema,
        phenome_schema=>$phenome_schema,
        stock_id_list=>\@seen_seedlot_ids,
        stock_type_id=>$type_id,
        stockprop_columns_view=>{'current_count'=>1, 'current_weight_gram'=>1, 'organization'=>1, 'location_code'=>1, 'seedlot_quality'=>1, 'material_type'=>1},
        minimal_info=>1,  #for only returning stock_id and uniquenames
        display_pedigree=>0 #to calculate and display pedigree
    });
    my ($stocksearch_result, $records_stock_total) = $stock_search->search();

    my %stockprop_hash;
    foreach (@$stocksearch_result){
        $stockprop_hash{$_->{stock_id}} = $_;
    }

    my @seedlots;
    foreach (sort keys %unique_seedlots){
        my $owners = $owners_hash->{$unique_seedlots{$_}->{seedlot_stock_id}};
        my @owners_html;
        foreach (@$owners){
            push @owners_html ,'<a href="/solpeople/personal-info.pl?sp_person_id='.$_->[0].'">'.$_->[2].' '.$_->[3].'</a>';
        }
        my $owners_string = join ', ', @owners_html;
        $unique_seedlots{$_}->{owners_string} = $owners_string;
        $unique_seedlots{$_}->{organization} = $stockprop_hash{$unique_seedlots{$_}->{seedlot_stock_id}}->{organization} ? $stockprop_hash{$unique_seedlots{$_}->{seedlot_stock_id}}->{organization} : 'NA';
        $unique_seedlots{$_}->{box} = $stockprop_hash{$unique_seedlots{$_}->{seedlot_stock_id}}->{location_code} ? $stockprop_hash{$unique_seedlots{$_}->{seedlot_stock_id}}->{location_code} : 'NA';
        $unique_seedlots{$_}->{seedlot_quality} = $stockprop_hash{$unique_seedlots{$_}->{seedlot_stock_id}}->{seedlot_quality} ? $stockprop_hash{$unique_seedlots{$_}->{seedlot_stock_id}}->{seedlot_quality} : '';
        $unique_seedlots{$_}->{current_count} = defined($stockprop_hash{$unique_seedlots{$_}->{seedlot_stock_id}}->{current_count}) ? $stockprop_hash{$unique_seedlots{$_}->{seedlot_stock_id}}->{current_count} : 'NA';
        $unique_seedlots{$_}->{current_weight_gram} = defined($stockprop_hash{$unique_seedlots{$_}->{seedlot_stock_id}}->{current_weight_gram}) ? $stockprop_hash{$unique_seedlots{$_}->{seedlot_stock_id}}->{current_weight_gram} : 'NA';
        $unique_seedlots{$_}->{material_type} = $stockprop_hash{$unique_seedlots{$_}->{seedlot_stock_id}}->{material_type} ? $stockprop_hash{$unique_seedlots{$_}->{seedlot_stock_id}}->{material_type} : '';

        push @seedlots, $unique_seedlots{$_};

    }

    return (\@seedlots, $records_total);
}

# class method
=head2 Class method: verify_seedlot_stock_lists()

 Usage:        my $seedlots = CXGN::Stock::Seedlot->verify_seedlot_stock_lists($schema, $people_schema, $phenome_schema, \@stock_names, \@seedlot_names);
 Desc:         Class method that verifies if a given list of seedlots is valid for a given list of accessions
 Ret:          success or error
 Args:         $schema, $stock_names, $seedlot_names
 Side Effects: accesses the database

=cut

sub verify_seedlot_stock_lists {
    my $class = shift;
    my $schema = shift;
    my $people_schema = shift;
    my $phenome_schema = shift;
    my $stock_names = shift;
    my $seedlot_names = shift;
    my $error = '';
    my %return;

    if (!$stock_names) {
        $error .= "No accession list selected!";
    }
    if (!$seedlot_names) {
        $error .= "No seedlot list supplied!";
    }
    if ($error){
        $return{error} = $error;
        return \%return;
    }

    my @stock_names = @$stock_names;
    my @seedlot_names = @$seedlot_names;
    if (scalar(@stock_names)<1){
        $error .= "Your accession list is empty!";
    }
    if (scalar(@seedlot_names)<1){
        $error .= "Your seedlot list is empty!";
    }
    if ($error){
        $return{error} = $error;
        return \%return;
    }

    my $lv = CXGN::List::Validate->new();
    my @accessions_missing = @{$lv->validate($schema,'accessions',\@stock_names)->{'missing'}};
    my $lv_seedlots = CXGN::List::Validate->new();
    my @seedlots_missing = @{$lv_seedlots->validate($schema,'seedlots',\@seedlot_names)->{'missing'}};

    if (scalar(@accessions_missing) > 0){
        $error .= 'The following accessions are not valid in the database, so you must add them first: '.join ',', @accessions_missing;
    }
    if (scalar(@seedlots_missing) > 0){
        $error .= 'The following seedlots are not valid in the database, so you must add them first: '.join ',', @seedlots_missing;
    }
    if ($error){
        $return{error} = $error;
        return \%return;
    }

    my %selected_seedlots = map {$_=>1} @seedlot_names;
    my %selected_accessions = map {$_=>1} @stock_names;
    my %seedlot_hash;

    my $ac = CXGN::BreedersToolbox::Accessions->new({schema=>$schema, people_schema=>$people_schema, phenome_schema=>$phenome_schema});
    my $possible_seedlots = $ac->get_possible_seedlots(\@stock_names);
    my %allowed_seedlots;
    while (my($key,$val) = each %$possible_seedlots){
        foreach my $seedlot (@$val){
            my $seedlot_name = $seedlot->{seedlot}->[0];
            if (exists($selected_accessions{$key}) && exists($selected_seedlots{$seedlot_name})){
                push @{$seedlot_hash{$key}}, $seedlot_name;
            }
        }
    }
    #if(scalar(keys %seedlot_hash) != scalar(@stock_names)){
    #    $error .= "Error: The seedlot list you select must include seedlots for all the accessions you have selected. ";
    #}
    if ($error){
        $return{error} = $error;
    } else {
        $return{success} = 1;
        $return{seedlot_hash} = \%seedlot_hash;
    }
    return \%return;
}

# class method
=head2 Class method: verify_seedlot_plot_compatibility()

 Usage:        my $seedlots = CXGN::Stock::Seedlot->verify_seedlot_plot_compatibility($schema, [[$seedlot_name, $plot_name]]);
 Desc:         Class method that verifies if a given list of pairs of seedlot_name and plot_name have the same underlying accession.
 Ret:          success or error
 Args:         $schema, $stock_names, $seedlot_names
 Side Effects: accesses the database

=cut

sub verify_seedlot_plot_compatibility {
    my $class = shift;
    my $schema = shift;
    my $pairs = shift; #arrayref of [ [seedlot_name, plot_name] ]
    my $error = '';
    my %return;

    if (!$pairs){
        $error .= "No pair array passed!";
    }
    if ($error){
        $return{error} = $error;
        return \%return;
    }

    my @pairs = @$pairs;
    if (scalar(@pairs)<1){
        $error .= "Your pairs list is empty!";
    }
    if ($error){
        $return{error} = $error;
        return \%return;
    }

    my $plot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, "plot", "stock_type")->cvterm_id();
    my $seedlot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, "seedlot", "stock_type")->cvterm_id();
    my $plot_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, "plot_of", "stock_relationship")->cvterm_id();
    my $collection_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, "collection_of", "stock_relationship")->cvterm_id();
    foreach (@pairs){
        my $seedlot_name = $_->[0];
        my $plot_name = $_->[1];

        #The plot is linked to one accession via 'plot_of'. That accession is then linked to many seedlots via 'collection_of'. Here we can check if the provided seedlot is one of the seedlots linked to the plot's accession.
        my $seedlot_rs = $schema->resultset("Stock::Stock")->search({'me.uniquename'=>$plot_name, 'me.type_id'=>$plot_cvterm_id})->search_related('stock_relationship_subjects', {'stock_relationship_subjects.type_id'=>$plot_of_cvterm_id})->search_related('object')->search_related('stock_relationship_subjects', {'stock_relationship_subjects_2.type_id'=>$collection_of_cvterm_id})->search_related('object', {'object_2.uniquename'=>$seedlot_name, 'object_2.type_id'=>$seedlot_cvterm_id});
        if (!$seedlot_rs->first){
            $error .= "The seedlot: $seedlot_name is not linked to the same accession as the plot: $plot_name . ";
        }
    }
    if ($error){
        $return{error} = $error;
    } else {
        $return{success} = 1;
    }
    return \%return;
}

# class method
=head2 Class method: verify_seedlot_accessions_crosses()

 Usage:        my $seedlots = CXGN::Stock::Seedlot->verify_seedlot_accessions_crosses($schema, [[$seedlot_name, $accession_name]]);
 Desc:         Class method that verifies if a given list of pairs of seedlot_name and accession_name or seedlot_name and cross unique id have the same underlying accession/cross_unique_id.
 Ret:          success or error
 Args:         $schema, $stock_names, $seedlot_names
 Side Effects: accesses the database

=cut

sub verify_seedlot_accessions_crosses {
    my $class = shift;
    my $schema = shift;
    my $pairs = shift; #arrayref of [ [seedlot_name, accession_name] ] #note: the variable accession_name can be either accession or cross stock type
    my $error = '';
    my %return;

    if (!$pairs){
        $error .= "No pair array passed!";
    }
    if ($error){
        $return{error} = $error;
        return \%return;
    }

    my @pairs = @$pairs;
    if (scalar(@pairs)<1){
        $error .= "Your pairs list is empty!";
    }
    if ($error){
        $return{error} = $error;
        return \%return;
    }

    my %seen_accession_names;
    foreach (@pairs){
        $seen_accession_names{$_->[1]}++;
    }
    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $cross_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'cross', 'stock_type')->cvterm_id();
    my $synonym_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stock_synonym', 'stock_property')->cvterm_id();
    my $seedlot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, "seedlot", "stock_type")->cvterm_id();
    my $collection_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, "collection_of", "stock_relationship")->cvterm_id();

    my @accessions = keys %seen_accession_names;
    my $acc_synonym_rs = $schema->resultset("Stock::Stock")->search({
        'me.is_obsolete' => { '!=' => 't' },
        'stockprops.value' => { -in => \@accessions},
        'me.type_id' => $accession_cvterm_id,
        'stockprops.type_id' => $synonym_cvterm_id
    },{join => 'stockprops', '+select'=>['stockprops.value'], '+as'=>['synonym']});
    my %acc_synonyms_lookup;
    while (my $r=$acc_synonym_rs->next){
        $acc_synonyms_lookup{$r->get_column('synonym')}->{$r->uniquename} = $r->stock_id;
    }

    foreach (@pairs){
        my $seedlot_name = $_->[0];
        my $accession_name = $_->[1];

        if ($acc_synonyms_lookup{$accession_name}){
            my @accession_names = keys %{$acc_synonyms_lookup{$accession_name}};
            if (scalar(@accession_names)>1){
                print STDERR "There is more than one uniquename for this synonym $accession_name. this should not happen!\n";
            }
            $accession_name = $accession_names[0];
        }

        my $seedlot_rs = $schema->resultset("Stock::Stock")->search({'me.uniquename'=>$seedlot_name, 'me.type_id'=>$seedlot_cvterm_id})->search_related('stock_relationship_objects', {'stock_relationship_objects.type_id'=>$collection_of_cvterm_id})->search_related('subject', {'subject.uniquename'=>$accession_name, 'subject.type_id'=>[$accession_cvterm_id, $cross_cvterm_id]});
        if (!$seedlot_rs->first){
            $error .= "The seedlot: $seedlot_name is not linked to the accession/cross_unique_id: $accession_name.";
        }
    }
    if ($error){
        $return{error} = $error;
    } else {
        $return{success} = 1;
    }
    return \%return;
}


=head2 Class method: verify_seedlot_seedlot_compatibility()

 Usage:        my $seedlots = CXGN::Stock::Seedlot->verify_seedlot_seedlot_compatibility($schema, [[$seedlot_name_1, $seedlot_name_2]]);
 Desc:         Class method that verifies if a given list of pairs of seedlot_names have the same content.
 Ret:          success or error
 Args:         $schema, $seedlot_name_1, $seedlot_name_2
 Side Effects: accesses the database

=cut

sub verify_seedlot_seedlot_compatibility {
    my $class = shift;
    my $schema = shift;
    my $pairs = shift;
    my $error = '';
    my %return;

    if (!$pairs){
        $error .= "No pair array passed!";
    }
    if ($error){
        $return{error} = $error;
        return \%return;
    }

    my @pairs = @$pairs;
    if (scalar(@pairs)<1){
        $error .= "Your pairs list is empty!";
    }
    if ($error){
        $return{error} = $error;
        return \%return;
    }

    my $seedlot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, "seedlot", "stock_type")->cvterm_id();
    my $collection_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, "collection_of", "stock_relationship")->cvterm_id();
    foreach (@pairs){
        my $seedlot_name_1 = $_->[0];
        my $seedlot_name_2 = $_->[1];

        my $seedlot_rs_1 = $schema->resultset("Stock::Stock")->find({'uniquename' => $seedlot_name_1,'type_id' => $seedlot_cvterm_id});
        my $seedlot_id_1 = $seedlot_rs_1->stock_id();
        my $seedlot_1_content = $schema->resultset("Stock::StockRelationship")->find({ object_id => $seedlot_id_1, type_id => $collection_of_cvterm_id});
        my $content_1_id = $seedlot_1_content->subject_id();

        my $seedlot_rs_2 = $schema->resultset("Stock::Stock")->find({'uniquename' => $seedlot_name_2,'type_id' => $seedlot_cvterm_id});
        my $seedlot_id_2 = $seedlot_rs_2->stock_id();
        my $seedlot_2_content = $schema->resultset("Stock::StockRelationship")->find({ object_id => $seedlot_id_2, type_id => $collection_of_cvterm_id});
        my $content_2_id = $seedlot_2_content->subject_id();

        if ($content_1_id ne $content_2_id){
            $error .= "The seedlots: $seedlot_name_1 and $seedlot_name_2 have different contents.";
        }

    }

    if ($error){
        $return{error} = $error;
    } else {
        $return{success} = 1;
    }
    return \%return;
}


=head2 Class method: verify_all_seedlots_compatibility()

 Usage:        my $seedlots = CXGN::Stock::Seedlot->verify_all_seedlots_compatibility($schema, [$new_seedlot_name, \%seedlot_names]);
 Desc:         Class method that verifies if a new seedlot name is associated with only one content.
 Ret:          success or error
 Args:         $schema, \@new_seedlot_and_associated_seedlots
 Side Effects: accesses the database

=cut

sub verify_all_seedlots_compatibility {
    my $class = shift;
    my $schema = shift;
    my $new_seedlot_and_associated_seedlots = shift;
    my $error = '';
    my %return;

    if (!$new_seedlot_and_associated_seedlots){
        $error .= "No seedlot names passed!";
    }
    if ($error){
        $return{error} = $error;
        return \%return;
    }

    my $new_seedlot_name = $new_seedlot_and_associated_seedlots->[0];
    my $associated_seedlots = $new_seedlot_and_associated_seedlots->[1];
    my @seedlot_names = keys %{$associated_seedlots};

    if (scalar(@seedlot_names)<1){
        $error .= "No associated seedlot!";
    }
    if ($error){
        $return{error} = $error;
        return \%return;
    }

    my $seedlot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, "seedlot", "stock_type")->cvterm_id();
    my $collection_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, "collection_of", "stock_relationship")->cvterm_id();
    my %seen_content;
    foreach my $each_seedlot(@seedlot_names){
        my $seedlot_rs = $schema->resultset("Stock::Stock")->find({'uniquename' => $each_seedlot,'type_id' => $seedlot_cvterm_id});
        my $seedlot_id = $seedlot_rs->stock_id();
        my $seedlot_content = $schema->resultset("Stock::StockRelationship")->find({ object_id => $seedlot_id, type_id => $collection_of_cvterm_id});
        my $content_id = $seedlot_content->subject_id();
        $seen_content{$content_id}++;
    }

    my $content_count = keys %seen_content;
    if ($content_count > 1) {
        $error = "You assigned more than one content to this new seedlot name: $new_seedlot_name "
    }

    if ($error){
        $return{error} = $error;
    } else {
        $return{success} = 1;
    }
    return \%return;
}


=head2 Class method: verify_accession_content_source_compatibility()

 Usage:        my $seedlots = CXGN::Stock::Seedlot->verify_accession_content_source_compatibility($schema, [[$accession_name, $source_name]]);
 Desc:         Class method that verifies if accession of a seedlot source is the same as accession content.
 Ret:          success or error
 Args:         $schema, $accession_name, $source_name
 Side Effects: accesses the database

=cut

sub verify_accession_content_source_compatibility {
    my $class = shift;
    my $schema = shift;
    my $pairs = shift;
    my $error = '';
    my %return;

    if (!$pairs){
        $error .= "No pair array passed!";
    }
    if ($error){
        $return{error} = $error;
        return \%return;
    }

    my @pairs = @$pairs;
    if (scalar(@pairs)<1){
        $error .= "Your pairs list is empty!";
    }
    if ($error){
        $return{error} = $error;
        return \%return;
    }

    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, "accession", "stock_type")->cvterm_id();
    my $plot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, "plot", "stock_type")->cvterm_id();
    my $subplot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, "subplot", "stock_type")->cvterm_id();
    my $plant_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, "plant", "stock_type")->cvterm_id();

    my $plot_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, "plot_of", "stock_relationship")->cvterm_id();
    my $subplot_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, "subplot_of", "stock_relationship")->cvterm_id();
    my $plant_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, "plant_of", "stock_relationship")->cvterm_id();

    foreach my $each_pair (@pairs){
        my $accession_id;
        my $source_id;
        my $source_type_id;
        my $accession_source_relationship_type;
        my $source_accession_id;
        my $accession_name = $each_pair->[0];
        my $source_name = $each_pair->[1];

        my $accession_rs = $schema->resultset("Stock::Stock")->find({'uniquename' => $accession_name,'type_id' => $accession_cvterm_id});
        if ($accession_rs) {
            $accession_id = $accession_rs->stock_id();
        }

        my $source_rs = $schema->resultset("Stock::Stock")->find({'uniquename' => $source_name});
        if ($source_rs) {
            $source_id = $source_rs->stock_id();
            $source_type_id = $source_rs->type_id();

            if ($source_type_id eq $plot_cvterm_id) {
                $accession_source_relationship_type = $plot_of_cvterm_id;
            } elsif ($source_type_id eq $subplot_cvterm_id) {
                $accession_source_relationship_type = $subplot_of_cvterm_id;
            } elsif ($source_type_id eq $plant_cvterm_id) {
                $accession_source_relationship_type = $plant_of_cvterm_id;
            } else {
                $error .= "The source name: $source_name is not a plot, subplot or plant stock type.";
            }
        }

        if ($accession_id && $source_id && $accession_source_relationship_type) {
            my $accession_source_relationship_rs = $schema->resultset("Stock::StockRelationship")->find({ subject_id => $source_id, type_id => $accession_source_relationship_type});
            $source_accession_id = $accession_source_relationship_rs->object_id();

            if ($accession_id ne $source_accession_id){
                $error .= "The source name: $source_name is not linked to the same accession as the access content: $accession_name"."<br>";
            }
        }
    }

    if ($error){
        $return{error} = $error;
    } else {
        $return{success} = 1;
    }
    return \%return;
}


=head2 Class method: get_content_id()

=cut

sub get_content_id {
    my $class = shift;
    my $schema = shift;
    my $seedlot_id = shift;
    my $accession_stock_id;
    my $cross_stock_id;
    my @return_content_id = ();

    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $cross_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'cross', 'stock_type')->cvterm_id();
    my $seedlot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, "seedlot", "stock_type")->cvterm_id();
    my $collection_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, "collection_of", "stock_relationship")->cvterm_id();

    my $seedlot_content = $schema->resultset("Stock::StockRelationship")->find({ object_id => $seedlot_id, type_id => $collection_of_cvterm_id});
    my $content_id = $seedlot_content->subject_id();

    my $check_content_type = $schema->resultset("Stock::Stock")->find({'stock_id' => $content_id});
    my $type_id = $check_content_type->type_id();
    if ($type_id eq $accession_cvterm_id) {
        $accession_stock_id = $content_id;
    } elsif ($type_id eq $cross_cvterm_id) {
        $cross_stock_id = $content_id;
    }
    @return_content_id = ($accession_stock_id, $cross_stock_id);

    return \@return_content_id;
}


sub BUILDARGS {
    my $orig = shift;
    my %args = @_;
    $args{stock_id} = $args{seedlot_id};
    return \%args;
}

sub BUILD {
    my $self = shift;
    if ($self->stock_id()) {
        $self->seedlot_id($self->stock_id);
        $self->name($self->uniquename());
        $self->seedlot_id($self->stock_id());
    }
}

sub _build_transactions {
    my $self = shift;
    my $transactions = CXGN::Stock::Seedlot::Transaction->get_transactions_by_seedlot_id($self->schema(), $self->seedlot_id());
    $self->transactions($transactions);
}

sub _store_seedlot_location {
    my $self = shift;
    my $nd_geolocation = $self->schema()->resultset("NaturalDiversity::NdGeolocation")->find_or_create({
        description => $self->location_code
    });
    $self->nd_geolocation_id($nd_geolocation->nd_geolocation_id);
}

sub _retrieve_location {
    my $self = shift;
    my $experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema(), "seedlot_experiment", "experiment_type")->cvterm_id();
    my $nd_geolocation_rs = $self->schema()->resultset('Stock::Stock')->search({'me.stock_id'=>$self->seedlot_id})->search_related('nd_experiment_stocks')->search_related('nd_experiment', {'nd_experiment.type_id'=>$experiment_type_id})->search_related('nd_geolocation');
    if ($nd_geolocation_rs->count != 1){
        die "Seedlot does not have 1 nd_geolocation associated!\n";
    }
    my $nd_geolocation_id = $nd_geolocation_rs->first()->nd_geolocation_id();
    my $location_code = $nd_geolocation_rs->first()->description();
    $self->nd_geolocation_id($nd_geolocation_id);
    $self->location_code($location_code);
}

sub _retrieve_location_id {
    my $self = shift;
    my $experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema(), "seedlot_experiment", "experiment_type")->cvterm_id();
    my $nd_geolocation_rs = $self->schema()->resultset('Stock::Stock')->search({'me.stock_id'=>$self->seedlot_id})->search_related('nd_experiment_stocks')->search_related('nd_experiment', {'nd_experiment.type_id'=>$experiment_type_id})->search_related('nd_geolocation');
    if ($nd_geolocation_rs->count != 1){
        die "Seedlot does not have 1 nd_geolocation associated!\n";
    }
    my $nd_geolocation_id = $nd_geolocation_rs->first()->nd_geolocation_id();
    my $location_code = $nd_geolocation_rs->first()->description();
    $self->nd_geolocation_id($nd_geolocation_id);
}

sub _retrieve_box_name {
    my $self = shift;
    $self->box_name($self->_retrieve_stockprop('location_code'));
}

sub _retrieve_breeding_program {
    my $self = shift;
    my $experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema(), "seedlot_experiment", "experiment_type")->cvterm_id();
    my $project_rs = $self->schema()->resultset('Stock::Stock')->search({'me.stock_id'=>$self->seedlot_id})->search_related('nd_experiment_stocks')->search_related('nd_experiment', {'nd_experiment.type_id'=>$experiment_type_id})->search_related('nd_experiment_projects')->search_related('project');
    if ($project_rs->count != 1){
        die "Seedlot does not have 1 breeding program project (".$project_rs->count.") associated!\n";
    }
    my $breeding_program_id = $project_rs->first()->project_id();
    my $breeding_program_name = $project_rs->first()->name();
    $self->breeding_program_id($breeding_program_id);
    $self->breeding_program_name($breeding_program_name);
}

sub _retrieve_breeding_program_id {
    my $self = shift;
    my $experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema(), "seedlot_experiment", "experiment_type")->cvterm_id();
    my $project_rs = $self->schema()->resultset('Stock::Stock')->search({'me.stock_id'=>$self->seedlot_id})->search_related('nd_experiment_stocks')->search_related('nd_experiment', {'nd_experiment.type_id'=>$experiment_type_id})->search_related('nd_experiment_projects')->search_related('project');
    if ($project_rs->count != 1){
        die "Seedlot does not have 1 breeding program project (".$project_rs->count.") associated!\n";
    }
    my $breeding_program_id = $project_rs->first()->project_id();
    my $breeding_program_name = $project_rs->first()->name();
    $self->breeding_program_id($breeding_program_id);
}

sub _store_seedlot_relationships {
    my $self = shift;
    my $error;

    eval {
        if ($self->accession_stock_id){
            $error = $self->_store_seedlot_accession();
        }
        if ($self->cross_stock_id){
            $error = $self->_store_seedlot_cross();
        }
        if (!$error){
            my $experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema(), "seedlot_experiment", "experiment_type")->cvterm_id();
            my $experiment = $self->schema->resultset('NaturalDiversity::NdExperiment')->create({
                nd_geolocation_id => $self->nd_geolocation_id,
                type_id => $experiment_type_id
            });
            $experiment->create_related('nd_experiment_stocks', { stock_id => $self->seedlot_id(), type_id => $experiment_type_id  });
            $experiment->create_related('nd_experiment_projects', { project_id => $self->breeding_program_id });
        }
    };

    if ($@) {
        $error = $@;
    }
    return $error;
}

sub _update_seedlot_breeding_program {
    my $self = shift;
    my $stock = $self->stock;
    my $seedlot_experiment_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->schema, 'seedlot_experiment', 'experiment_type')->cvterm_id();
    my $nd_exp_project = $stock->search_related('nd_experiment_stocks')->search_related('nd_experiment', {'nd_experiment.type_id'=>$seedlot_experiment_cvterm_id})->search_related('nd_experiment_projects');
    if($nd_exp_project->count != 1){
        die "There should be exactly one nd_experiment_project for any single seedlot!";
    }
    my $nd_exp_proj = $nd_exp_project->first();
    $nd_exp_proj->update({project_id=>$self->breeding_program_id});
}

sub _update_seedlot_location {
    my $self = shift;
    my $stock = $self->stock;
    my $seedlot_experiment_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->schema, 'seedlot_experiment', 'experiment_type')->cvterm_id();
    my $nd_exp = $stock->search_related('nd_experiment_stocks')->search_related('nd_experiment', {'nd_experiment.type_id'=>$seedlot_experiment_cvterm_id});
    if($nd_exp->count != 1){
        die "There should be exactly one nd_experiment for any single seedlot!";
    }
    my $nd = $nd_exp->first();
    $nd->update({nd_geolocation_id=>$self->nd_geolocation_id});
}

sub _store_seedlot_accession {
    my $self = shift;
    my $accession_stock_id = $self->accession_stock_id;

    my $organism_id = $self->schema->resultset('Stock::Stock')->find({stock_id => $accession_stock_id})->organism_id();
    if ($self->organism_id){
        if ($self->organism_id != $organism_id){
            return "Accessions must all be the same organism, so that a population can group the seed lots.\n";
        }
    }
    $self->organism_id($organism_id);

    my $type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema(), "collection_of", "stock_relationship")->cvterm_id();
    my $already_exists = $self->schema()->resultset("Stock::StockRelationship")->find({ object_id => $self->seedlot_id(), type_id => $type_id, subject_id=>$accession_stock_id });

    if ($already_exists) {
        print STDERR "Accession with id $accession_stock_id is already associated with seedlot id ".$self->seedlot_id()."\n";
        return "Accession with id $accession_stock_id is already associated with seedlot id ".$self->seedlot_id();
    }
    my $row = $self->schema()->resultset("Stock::StockRelationship")->create({
        object_id => $self->seedlot_id(),
        subject_id => $accession_stock_id,
        type_id => $type_id,
    });
    return;
}

sub _update_content_stock_id {
    my $self = shift;
    my $type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema(), "collection_of", "stock_relationship")->cvterm_id();
    my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema(), "accession", "stock_type")->cvterm_id();
    my $cross_type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema(), "cross", "stock_type")->cvterm_id();

    my $acc_rs = $self->stock->search_related('stock_relationship_objects', {'me.type_id'=>$type_id, 'subject.type_id'=>[$accession_type_id,$cross_type_id]}, {'join'=>'subject'});

    while (my $r=$acc_rs->next){
        $r->delete();
    }
    my $error;
    if ($self->accession_stock_id){
        $error = $self->_store_seedlot_accession();
    }
    if ($self->cross_stock_id){
        $error = $self->_store_seedlot_cross();
    }
    return $error;
}

sub _retrieve_accession {
    my $self = shift;
    my $type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema(), "collection_of", "stock_relationship")->cvterm_id();
    my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema(), "accession", "stock_type")->cvterm_id();
    my $rs = $self->schema()->resultset("Stock::StockRelationship")->search({ 'me.type_id' => $type_id, 'me.object_id' => $self->seedlot_id(), 'subject.type_id'=>$accession_type_id }, {'join'=>'subject'});

    my $accession_id;
    if ($rs->count == 1){
        $accession_id = $rs->first->subject_id;
    }

    if ($accession_id){
        $self->accession_stock_id($accession_id);

        my $accession_rs = $self->schema()->resultset("Stock::Stock")->find({ stock_id => $accession_id });
        $self->accession([$accession_rs->stock_id(), $accession_rs->uniquename()]);
    }
}

sub _remove_accession {
    my $self = shift;
}


sub _store_seedlot_cross {
    my $self = shift;
    my $cross_stock_id = $self->cross_stock_id;
    my $organism_id = $self->schema->resultset('Stock::Stock')->find({stock_id => $cross_stock_id})->organism_id();
    if ($self->organism_id){
        if ($self->organism_id != $organism_id){
            return "Crosses must all be the same organism to be in a seed lot.\n";
        }
    }
    $self->organism_id($organism_id);

    my $type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema(), "collection_of", "stock_relationship")->cvterm_id();
    my $already_exists = $self->schema()->resultset("Stock::StockRelationship")->find({ object_id => $self->seedlot_id(), type_id => $type_id, subject_id=>$cross_stock_id });

    if ($already_exists) {
        print STDERR "Cross with id $cross_stock_id is already associated with seedlot id ".$self->seedlot_id()."\n";
        return "Cross with id $cross_stock_id is already associated with seedlot id ".$self->seedlot_id();
    }
    my $row = $self->schema()->resultset("Stock::StockRelationship")->create({
        object_id => $self->seedlot_id(),
        subject_id => $cross_stock_id,
        type_id => $type_id,
    });
    return;
}

sub _retrieve_cross {
    my $self = shift;
    my $type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema(), "collection_of", "stock_relationship")->cvterm_id();
    my $cross_type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema(), "cross", "stock_type")->cvterm_id();
    my $rs = $self->schema()->resultset("Stock::StockRelationship")->search({ 'me.type_id' => $type_id, 'me.object_id' => $self->seedlot_id(), 'subject.type_id'=>$cross_type_id }, {'join'=>'subject'});

    my $cross_id;
    if ($rs->count == 1){
        $cross_id = $rs->first->subject_id;
    }

    if ($cross_id){
        $self->cross_stock_id($cross_id);

        my $cross_rs = $self->schema()->resultset("Stock::Stock")->find({ stock_id => $cross_id });
        $self->cross([$cross_rs->stock_id(), $cross_rs->uniquename()]);
    }
}


=head2 Method current_count()

 Usage:        my $current_count = $sl->current_count();
 Desc:         returns the current balance of seeds in the seedlot
 Ret:          a number
 Args:         none
 Side Effects: retrieves transactions from db and calculates count
 Example:

=cut

sub current_count {
    my $self = shift;
    my $transactions = $self->transactions();

    my $count = 0;
    my $na_amount_counter = 0;
    foreach my $t (@$transactions) {
        if ($t->amount() ne 'NA'){
            $count += $t->amount() * $t->factor();
        } else {
            $na_amount_counter += 1;
        }
    }
    if ($count == 0 && scalar(@$transactions) == $na_amount_counter){
        $count = 'NA';
    }
    return $count;
}

# It is convenient and also much faster to retrieve a single value for the current_count, rather than calculating it from the transactions.
sub set_current_count_property {
    my $self = shift;
    my $current_count = $self->current_count();
    my $current_count_cvterm = SGN::Model::Cvterm->get_cvterm_row($self->schema, 'current_count', 'stock_property');
    my $stock = $self->stock();
    my $recorded_current_count = $stock->find_related('stockprops', {'me.type_id'=>$current_count_cvterm->cvterm_id});
    if($recorded_current_count){
        $recorded_current_count->update({'value'=>$current_count});
    } else {
        $stock->create_stockprops({$current_count_cvterm->name() => $current_count});
    }
    return $current_count;
}

# It is convenient and also much faster to retrieve a single value for the current_count, rather than calculating it from the transactions.
sub get_current_count_property {
    my $self = shift;
    my $current_count_cvterm = SGN::Model::Cvterm->get_cvterm_row($self->schema, 'current_count', 'stock_property');
    my $recorded_current_count = $self->stock()->find_related('stockprops', {'me.type_id'=>$current_count_cvterm->cvterm_id});
    return $recorded_current_count ? $recorded_current_count->value() : '';
}

=head2 _retrieve_quality

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub _retrieve_quality {
    my $self = shift;
    $self->quality($self->_retrieve_stockprop('seedlot_quality'));
}

=head2 _retrieve_material_type

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub _retrieve_material_type {
    my $self = shift;
    my $material_type = $self->_retrieve_stockprop('material_type');
    $self->material_type($material_type);
}


=head2 Method current_weight()

 Usage:        my $current_weight = $sl->current_weight();
 Desc:         returns the current weight of seeds in the seedlot
 Ret:          a number
 Args:         none
 Side Effects: retrieves transactions from db and calculates weight
 Example:

=cut

sub current_weight {
    my $self = shift;
    my $transactions = $self->transactions();

    my $weight = 0;
    my $na_weight_counter = 0;
    foreach my $t (@$transactions) {
        if ($t->weight_gram() ne 'NA' && length($t->weight_gram)){
            $weight += $t->weight_gram() * $t->factor();
        } else {
            $na_weight_counter += 1;
        }
    }
    if ($weight == 0 && scalar(@$transactions) == $na_weight_counter){
        $weight = 'NA';
    }
    return $weight;
}

# It is convenient and also much faster to retrieve a single value for the current_weight, rather than calculating it from the transactions.
sub set_current_weight_property {
    my $self = shift;
    my $current_weight = $self->current_weight();
    my $current_weight_cvterm = SGN::Model::Cvterm->get_cvterm_row($self->schema, 'current_weight_gram', 'stock_property');
    my $stock = $self->stock();
    my $recorded_current_weight = $stock->find_related('stockprops', {'me.type_id'=>$current_weight_cvterm->cvterm_id});
    if ($recorded_current_weight){
        $recorded_current_weight->update({'value'=>$current_weight});
    } else {
        $stock->create_stockprops({$current_weight_cvterm->name() => $current_weight});
    }
    return $current_weight;
}

# It is convenient and also much faster to retrieve a single value for the current_weight, rather than calculating it from the transactions.
sub get_current_weight_property {
    my $self = shift;
    my $current_count_cvterm = SGN::Model::Cvterm->get_cvterm_row($self->schema, 'current_weight_gram', 'stock_property');
    my $recorded_current_count = $self->stock()->find_related('stockprops', {'me.type_id'=>$current_count_cvterm->cvterm_id});
    return $recorded_current_count ? $recorded_current_count->value() : '';
}


sub _add_transaction {
    my $self = shift;
    my $transaction = shift;

    my $transactions = $self->transactions();
    push @$transactions, $transaction;

    $self->transactions($transactions);
}

=head2 store()

 Usage:        my $seedlot_id = $sl->store();
 Desc:         stores the current state of the object to the db. uses CXGN::Stock store as well.
 Ret:          the seedlot id.
 Args:         none
 Side Effects: accesses the db. Creates a new seedlot ID if not
               already existing.
 Example:

=cut

sub store {
    my $self = shift;
    my $error;

    my $coderef = sub {
        #Creating new seedlot
        if(!$self->stock){
            $self->name($self->uniquename());
            $self->type('seedlot');
            my $id = $self->SUPER::store();
            print STDERR "Saving seedlot returned ID $id.".localtime."\n";
            $self->seedlot_id($id);
            $self->_store_seedlot_location();
            $error = $self->_store_seedlot_relationships();
            if ($error){
                die $error;
            }
            if ($self->box_name){
                $self->_store_stockprop('location_code', $self->box_name);
            }
            if ($self->quality()) {
                $self->_store_stockprop('seedlot_quality', $self->quality());
            }
            if ($self->material_type()) {
                $self->_store_stockprop('material_type', $self->material_type());
            }

        } else { #Updating seedlot

            #Attempting to update seedlot's accession. Will not proceed if seedlot has already been used in transactions.
            if($self->accession_stock_id){
                my $input_accession_id = $self->accession_stock_id;
                my $transactions = $self->transactions();
                my $stored_accession_id = $self->accession ? $self->accession->[0] : 0;
                $self->accession_stock_id($input_accession_id);
                my $accessions_have_changed = $input_accession_id == $stored_accession_id ? 0 : 1;
                if ($accessions_have_changed && scalar(@$transactions)>1){
                    $error = "This seedlot ".$self->uniquename." has been used in transactions, so the contents (accessions) cannot be changed now!";
                } elsif ($accessions_have_changed && scalar(@$transactions) <= 1) {
                    $error = $self->_update_content_stock_id();
                    my $update_first_transaction_id = $transactions->[0]->update_transaction_object_id($self->accession_stock_id);
                }
                if ($error){
                    die $error;
                }
            }

            #Attempting to update seedlot's cross. Will not proceed if seedlot has already been used in transactions.
            if($self->cross_stock_id){
                my $input_cross_id = $self->cross_stock_id;
                my $transactions = $self->transactions();
                my $stored_cross_id = $self->cross ? $self->cross->[0] : 0;
                $self->cross_stock_id($input_cross_id);
                my $crosses_have_changed = $input_cross_id == $stored_cross_id ? 0 : 1;
                if ($crosses_have_changed && scalar(@$transactions)>1){
                    $error = "This seedlot ".$self->uniquename." has been used in transactions, so the contents (crosses) cannot be changed now!";
                } elsif ($crosses_have_changed && scalar(@$transactions) <= 1) {
                    $error = $self->_update_content_stock_id();
                    my $update_first_transaction_id = $transactions->[0]->update_transaction_object_id($self->cross_stock_id);
                }
                if ($error){
                    die $error;
                }
            }

            my $id = $self->SUPER::store();
            print STDERR "Updating seedlot returned ID $id.".localtime."\n";
            $self->seedlot_id($id);
            if($self->breeding_program_id){
                $self->_update_seedlot_breeding_program();
            }
            if($self->location_code){
                $self->_store_seedlot_location();
                $self->_update_seedlot_location();
            }
            if($self->box_name){
                $self->_update_stockprop('location_code', $self->box_name);
            }
            if($self->quality) {
                $self->_update_stockprop('seedlot_quality', $self->quality());
            }
            if($self->material_type) {
                $self->_update_stockprop('material_type', $self->material_type());
            }

        }
    };

    my $transaction_error;
	try {
		$self->schema->txn_do($coderef);
	} catch {
		print STDERR "Transaction Error: $_\n";
		$transaction_error =  $_;
	};
	if ($transaction_error){
        return { error=>$transaction_error };
    } else {
        return { success=>1, seedlot_id=>$self->stock_id() };
    }
}

=head2 delete()

 Usage:        my $error_message = $sl->delete();
 Desc:         delete the seedlot from the database. only possible to delete a seedlot that has not been used in any transactions other than the transaction that initiated it.
 Ret:          any error message. undef if no errors
 Args:         none
 Side Effects: accesses the db. Deletes seedlot
 Example:

=cut

sub delete {
    my $self = shift;
    my $error = '';
    my $transactions = $self->transactions();
    my $name = $self->name();
    if (scalar(@$transactions)>1){
        $error = "Seedlot '$name' has been used in transactions and so cannot be deleted!";
    } else {
        my $stock = $self->stock();
        my $experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema(), "seedlot_experiment", "experiment_type")->cvterm_id();
        my $nd_experiment_rs = $self->schema()->resultset('Stock::Stock')->search({'me.stock_id'=>$self->seedlot_id})->search_related('nd_experiment_stocks')->search_related('nd_experiment', {'nd_experiment.type_id'=>$experiment_type_id});
        if ($nd_experiment_rs->count != 1){
            $error = "Seedlot '$name' should have only one associated nd_experiment!";
        } else {
            my $nd_experiment = $nd_experiment_rs->first();
            $nd_experiment->delete();
            my $stock_owner_rs = $self->phenome_schema->resultset("StockOwner")->find({stock_id=>$self->stock_id});
            if ($stock_owner_rs){
                $stock_owner_rs->delete();
            }
            $stock->delete();
        }
    }

    return $error;
}


### CLASS FUNCTION DELETE_USING_LIST

sub delete_verify_using_list {
    my $class = shift;
    my $schema = shift;
    my $phenome_schema = shift;
    my $list_id = shift;

    my $list = CXGN::List->new( { dbh => $schema->storage->dbh(), list_id => $list_id } );
    my $type_row = SGN::Model::Cvterm->get_cvterm_row($schema, "seedlot", 'stock_type');

    my $type_id;
    if ($type_row) {
	$type_id = $type_row->cvterm_id();
    }

    print STDERR "TYPE ID = $type_id\n";

    my $elements = $list->elements();

    my @errors;
    my @ok;

    print STDERR "ELEMENTS ".join(",", @$elements);
    my $delete_count = 0;
    foreach my $ele (@$elements) {
	print STDERR "start deletion for seedlot ".Dumper($ele)."...\n";
	my $rs = $schema->resultset("Stock::Stock")->search( { uniquename => $ele, type_id => $type_id });
	if ($rs->count() == 0) {
	    print STDERR "No such seedlot $ele\n";
	    push @errors, [ $ele, "No seedlot named '$ele' could be found in the database" ];
	}
	else {
	    my $experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "seedlot_experiment", "experiment_type")->cvterm_id();
	    my $seedlot_id = $rs->next()->stock_id();
	    print STDERR "SEEDLOT ID: $seedlot_id\n";
	    my $nd_experiment_rs = $schema->resultset('Stock::Stock')->search({'me.stock_id'=> $seedlot_id})->search_related('nd_experiment_stocks')->search_related('nd_experiment', {'nd_experiment.type_id'=>$experiment_type_id});
	    if ($nd_experiment_rs->count != 1){
		my $error = "Seedlot '$ele' should have only one associated nd_experiment!";
		push @errors, [ $ele, $error];
	    }
	    else {
		push @ok, $ele;
	    }

	}
    }
    return ( \@ok, \@errors );


}

sub delete_using_list {
    my $class = shift;
    my $schema = shift;
    my $phenome_schema = shift;
    my $list_id = shift;

    my $list = CXGN::List->new( { dbh => $schema->storage->dbh(), list_id => $list_id } );
    my $type_row = SGN::Model::Cvterm->get_cvterm_row($schema, "seedlot", 'stock_type');

    my $type_id;
    if ($type_row) {
	$type_id = $type_row->cvterm_id();
    }

    print STDERR "TYPE ID = $type_id\n";

    my $elements = $list->elements();

    my @errors;
    my $delete_count = 0;
    foreach my $ele (@$elements) {
	print STDERR "start deletion for seedlot ".Dumper($ele)."...\n";
	my $rs = $schema->resultset("Stock::Stock")->search( { uniquename => $ele, type_id => $type_id });
	if ($rs->count() == 0) {
	    print STDERR "No such seedlot $ele\n";
	    push @errors, "No seedlot named '$ele' could be found in the database";
	}
	else {
	    my $seedlot = CXGN::Stock::Seedlot->new( schema => $schema, phenome_schema => $phenome_schema, seedlot_id => $rs->next()->stock_id());
	    my $error = $seedlot->delete();
	    if ($error) {
		print STDERR "Error during seedlot deletion: $error\n";
		push @errors, $error;
	    }
	    else {
		$delete_count++;
	    }
	}
    }
    return ( scalar(@$elements), $delete_count, \@errors );
}


#
# SEEDLOT MAINTENANCE EVENT FUNCTIONS
#

=head2 get_events()

 Usage:         my @events = $sl->get_events();
 Desc:          get all of seedlot maintenance events associated with the seedlot
 Args:          page = (optional) the page number of results to return
                pageSize = (optional) the number of results per page to return
 Ret:           a hash with the results metadata and the matching seedlot events:
                    - page: current page number
                    - maxPage: the number of the last page
                    - pageSize: (max) number of results per page
                    - total: total number of results
                    - results: an arrayref of hases of the seedlot's stored events, with the following keys:
                        - stock_id: the unique id of the seedlot
                        - uniquename: the unique name of the seedlot
                        - stockprop_id: the unique id of the maintenance event
                        - cvterm_id: id of seedlot maintenance event ontology term
                        - cvterm_name: name of seedlot maintenance event ontology term
                        - value: value of the seedlot maintenance event
                        - notes: additional notes/comments about the event
                        - operator: username of the person creating the event
                        - timestamp: timestamp string of when the event was created ('YYYY-MM-DD HH:MM:SS' format)

=cut

sub get_events {
    my $self = shift;
    my $page = shift;
    my $pageSize = shift;
    my $schema = $self->schema();
    my $seedlot_name = $self->uniquename();
    my $m = CXGN::Stock::Seedlot::Maintenance->new({ bcs_schema => $schema });

    return $m->filter_events({ names => [$seedlot_name] }, $page, $pageSize);
}


=head2 get_event()

 Usage:         my $event = $sl->get_event($id);
 Desc:          get the specified seedlot maintenance event associated with the seedlot
 Args:          id = stockprop_id of maintenance event
 Ret:           a hashref of the seedlot maintenance event, with the following keys:
                    - stock_id: the unique id of the seedlot
                    - uniquename: the unique name of the seedlot
                    - stockprop_id: the unique id of the maintenance event
                    - cvterm_id: id of seedlot maintenance event ontology term
                    - cvterm_name: name of seedlot maintenance event ontology term
                    - value: value of the seedlot maintenance event
                    - notes: additional notes/comments about the event
                    - operator: username of the person creating the event
                    - timestamp: timestamp string of when the event was created ('YYYY-MM-DD HH:MM:SS' format)

=cut

sub get_event {
    my $self = shift;
    my $event_id = shift;
    my $schema = $self->schema();
    my $seedlot_name = $self->uniquename();
    my $m = CXGN::Stock::Seedlot::Maintenance->new({ bcs_schema => $schema });

    my $events = $m->filter_events({ names => [$seedlot_name], events => [$event_id] });
    return $events->{'results'}->[0];
}


=head2 store_events()

 Usage:         my @events = ({ cvterm_id => $cvterm_id, value => $value, notes => $notes, operator => $operator, timestamp => $timestamp }, ... );
                my $stored_events = $sl->store_events(\@events);
 Desc:          store one or more seedlot maintenance events in the database as a JSON stockprop associated with the seedlot's stock entry.
                this function uses the CXGN::Stock::Seedlot::Maintenance class to store the JSON stockprop
 Args:          $events = arrayref of hashes of the event properties, with the following keys:
                    - cvterm_id: id of seedlot maintenance event ontology term
                    - value: value of the seedlot maintenance event
                    - notes: (optional) additional notes/comments about the event
                    - operator: username of the person creating the event
                    - timestamp: timestamp string of when the event was created ('YYYY-MM-DD HH:MM:SS' format)
 Ret:           an arrayref of hashes of the processed/stored events (includes stockprop_id), with the following keys:
                    - stockprop_id: the unique id of the maintenance event
                    - stock_id: the unique id of the seedlot
                    - cvterm_id: id of seedlot maintenance event ontology term
                    - cvterm_name: name of seedlot maintenance event ontology term
                    - value: value of the seedlot maintenance event
                    - notes: additional notes/comments about the event
                    - operator: username of the person creating the event
                    - timestamp: timestamp string of when the event was created ('YYYY-MM-DD HH:MM:SS' format)
                the function will die on a caught error

=cut

sub store_events {
    my $self = shift;
    my $events = shift;
    my $schema = $self->schema();
    my $seedlot_id = $self->seedlot_id();

    # Process the passed events
    my @processed_events = ();
    foreach my $event (@$events) {
        my $cvterm_id = $event->{cvterm_id};
        my $value = $event->{value};
        my $notes = $event->{notes};
        my $operator = $event->{operator};
        my $timestamp = $event->{timestamp};

        # Check for required parameters
        if ( !defined $cvterm_id || $cvterm_id eq '' ) {
            die "cvterm_id is required!";
        }
        if ( !defined $value || $value eq '' ) {
            die "value is required!";
        }
        if ( !defined $operator || $operator eq '' ) {
            die "operator is required!";
        }
        if ( !defined $timestamp || $timestamp eq '' ) {
            die "timestamp is required!";
        }
        if ( $timestamp !~ /^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$/ ) {
            die "timestamp not valid format [YYYY-MM-DD HH:MM:SS]!";
        }

        # Find matching cvterm by id
        my $cvterm_rs = $schema->resultset("Cv::Cvterm")->search({ cvterm_id => $cvterm_id })->first();
        if ( !defined $cvterm_rs ) {
            die "cvterm_id $cvterm_id not found!";
        }
        my $cvterm_name = $cvterm_rs->name();

        # Save processed event
        my %processed_event = (
            cvterm_id => $cvterm_id,
            cvterm_name => $cvterm_name,
            value => $value,
            notes => $notes,
            operator => $operator,
            timestamp => $timestamp
        );
        push(@processed_events, \%processed_event);
    }

    # Store the processed events
    foreach my $processed_event (@processed_events) {
        my $event_obj = CXGN::Stock::Seedlot::Maintenance->new({ bcs_schema => $schema, parent_id => $seedlot_id });
        $event_obj->cvterm_id($processed_event->{cvterm_id});
        $event_obj->cvterm_name($processed_event->{cvterm_name});
        $event_obj->value($processed_event->{value});
        $event_obj->notes($processed_event->{notes});
        $event_obj->operator($processed_event->{operator});
        $event_obj->timestamp($processed_event->{timestamp});
        my $stockprop_id = $event_obj->store_by_rank();
        $processed_event->{stockprop_id} = $stockprop_id;
        $processed_event->{stock_id} = $seedlot_id;
    }

    # Return the processed events
    return(\@processed_events);
}


=head2 remove_event()

 Usage:         $sl->remove_event($id)
 Desc:          delete the specified seedlot maintenance event from the database
 Args:          $id = stockprop_id of the seedlot maintenance event
 Ret:

=cut

sub remove_event {
    my $self = shift;
    my $event_id = shift;
    my $seedlot_id = $self->seedlot_id();
    my $schema = $self->schema();
    my $m = CXGN::Stock::Seedlot::Maintenance->new({ bcs_schema => $schema, parent_id => $seedlot_id, prop_id => $event_id });

    $m->delete();
}


=head2 get_seedlot_species()

 Usage:         $seedlot->get_seedlot_species($id)
 Desc:          retrieve species of seedlot content
 Ret:

=cut

sub get_seedlot_species {
    my $self = shift;
    my $schema = $self->schema();
    my $seedlot_id = $self->seedlot_id();

    my $collection_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'collection_of', 'stock_relationship')->cvterm_id();

    my $q = "SELECT organism.species FROM stock_relationship
    JOIN stock ON (stock_relationship.subject_id = stock.stock_id) AND stock_relationship.type_id = ?
    JOIN organism ON (stock.organism_id = organism.organism_id)
    WHERE stock_relationship.object_id = ?";

    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute($collection_of_type_id, $seedlot_id);

    my @data = ();
    while(my($species) = $h->fetchrow_array()){
        push @data, [$species];
    }

    my $species_info = $data[0][0];

    return $species_info
}



1;

no Moose;
__PACKAGE__->meta->make_immutable;
