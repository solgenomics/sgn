
=head1 NAME

CXGN::Stock::Seedlot - a class to represent seedlots in the database

=head1 DESCRIPTION

CXGN::Stock::Seedlot inherits from CXGN::Stock. The required fields are:

uniquename

location_code

Seed transactions can be added using CXGN::Stock::Seedlot::Transaction.

=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>

=head1 ACCESSORS & METHODS

=cut

package CXGN::Stock::Seedlot;

use Moose;

extends 'CXGN::Stock';

use Data::Dumper;
use CXGN::Stock::Seedlot::Transaction;
use CXGN::BreedersToolbox::Projects;
use SGN::Model::Cvterm;
use CXGN::List::Validate;
use Try::Tiny;

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
);

=head2 Accessor cross()

The crosses this seedlot is a "collection_of"
# for setter, use cross_stock_ids

=cut

has 'crosses' => (
    isa => 'ArrayRef[ArrayRef]',
    is => 'rw',
    lazy     => 1,
    builder  => '_retrieve_crosses',
);

has 'cross_stock_ids' =>   (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

=head2 Accessor accessions()

The accessions this seedlot is a "collection_of"
# for setter, use accession_stock_ids

=cut

has 'accessions' => (
    isa => 'ArrayRef[ArrayRef]',
    is => 'rw',
    lazy     => 1,
    builder  => '_retrieve_accessions',
);

has 'accession_stock_ids' => (
    isa => 'ArrayRef[Int]|Undef',
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
    my $offset = shift;
    my $limit = shift;
    my $seedlot_name = shift;
    my $breeding_program = shift;
    my $location = shift;
    my $minimum_count = shift;
    my $contents = shift;

    my %unique_seedlots;

    my $type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "seedlot", "stock_type")->cvterm_id();
    my $collection_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, "collection_of", "stock_relationship")->cvterm_id();
    my $current_count_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, "current_count", "stock_property")->cvterm_id();
    my $experiment_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, "seedlot_experiment", "experiment_type")->cvterm_id();

    my %search_criteria;
    $search_criteria{'me.type_id'} = $type_id;
    #$search_criteria{'nd_experiment.type_id'} = $experiment_cvterm_id;
    #$search_criteria{'nd_experiment_stocks.type_id'} = $experiment_cvterm_id;
    $search_criteria{'stock_relationship_objects.type_id'} = $collection_of_cvterm_id;
    $search_criteria{'stockprops.type_id'} = $current_count_cvterm_id;
    if ($seedlot_name) {
        $search_criteria{'me.uniquename'} = { 'ilike' => '%'.$seedlot_name.'%' };
    }
    if ($breeding_program) {
        $search_criteria{'project.name'} = { 'ilike' => '%'.$breeding_program.'%' };
    }
    if ($location) {
        $search_criteria{'nd_geolocation.description'} = { 'ilike' => '%'.$location.'%' };
    }
    if ($contents) {
        $search_criteria{'subject.uniquename'} = { 'ilike' => '%'.$contents.'%' };
    }
    if ($minimum_count) {
        $search_criteria{'stockprops.value' }  = { '>' => $minimum_count };
    }

    my $rs = $schema->resultset("Stock::Stock")->search(
        \%search_criteria,
        {
            join => [
                {'nd_experiment_stocks' => {'nd_experiment' => [ {'nd_experiment_projects' => 'project' }, 'nd_geolocation' ] }},
                {'stock_relationship_objects' => 'subject'},
                'stockprops'
            ],
            '+select'=>['project.name', 'project.project_id', 'subject.stock_id', 'subject.uniquename', 'nd_geolocation.description', 'nd_geolocation.nd_geolocation_id', 'stockprops.value'],
            '+as'=>['breeding_program_name', 'breeding_program_id', 'source_stock_id', 'source_uniquename', 'location', 'location_id', 'current_count'],
            order_by => {-asc=>'project.name'},
            #distinct => 1
        }
    );
    my $records_total = $rs->count();
    if (defined($limit) && defined($offset)){
        $rs = $rs->slice($offset, $limit);
    }
    while (my $row = $rs->next()) {
        $unique_seedlots{$row->uniquename}->{seedlot_stock_id} = $row->stock_id;
        $unique_seedlots{$row->uniquename}->{seedlot_stock_uniquename} = $row->uniquename;
        $unique_seedlots{$row->uniquename}->{seedlot_stock_description} = $row->description;
        $unique_seedlots{$row->uniquename}->{breeding_program_name} = $row->get_column('breeding_program_name');
        $unique_seedlots{$row->uniquename}->{breeding_program_id} = $row->get_column('breeding_program_id');
        $unique_seedlots{$row->uniquename}->{location} = $row->get_column('location');
        $unique_seedlots{$row->uniquename}->{location_id} = $row->get_column('location_id');
        $unique_seedlots{$row->uniquename}->{current_count} = $row->get_column('current_count');
        push @{$unique_seedlots{$row->uniquename}->{source_stocks}}, [$row->get_column('source_stock_id'), $row->get_column('source_uniquename')];
    }
    my @seedlots;
    foreach (sort keys %unique_seedlots){
        push @seedlots, $unique_seedlots{$_};
    }
    #print STDERR Dumper \@seedlots;
    return (\@seedlots, $records_total);
}

sub verify_seedlot_stock_lists {
    my $class = shift;
    my $schema = shift;
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

    my $ac = CXGN::BreedersToolbox::Accessions->new({schema=>$schema});
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

sub verify_seedlot_accessions {
    my $class = shift;
    my $schema = shift;
    my $pairs = shift; #arrayref of [ [seedlot_name, accession_name] ]
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
    my $seedlot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, "seedlot", "stock_type")->cvterm_id();
    my $collection_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, "collection_of", "stock_relationship")->cvterm_id();
    foreach (@pairs){
        my $seedlot_name = $_->[0];
        my $accession_name = $_->[1];

        my $seedlot_rs = $schema->resultset("Stock::Stock")->search({'me.uniquename'=>$seedlot_name, 'me.type_id'=>$seedlot_cvterm_id})->search_related('stock_relationship_objects', {'stock_relationship_objects.type_id'=>$collection_of_cvterm_id})->search_related('subject', {'subject.uniquename'=>$accession_name, 'subject.type_id'=>$accession_cvterm_id});
        if (!$seedlot_rs->first){
            $error .= "The seedlot: $seedlot_name is not linked to the accession: $accession_name.";
        }
    }
    if ($error){
        $return{error} = $error;
    } else {
        $return{success} = 1;
    }
    return \%return;
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
    #print STDERR Dumper $self->seedlot_id;
}

sub _build_transactions {
    my $self = shift;
    my $transactions = CXGN::Stock::Seedlot::Transaction->get_transactions_by_seedlot_id($self->schema(), $self->seedlot_id());
    #print STDERR Dumper($transactions);
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

sub _retrieve_breeding_program {
    my $self = shift;
    my $experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema(), "seedlot_experiment", "experiment_type")->cvterm_id();
    my $project_rs = $self->schema()->resultset('Stock::Stock')->search({'me.stock_id'=>$self->seedlot_id})->search_related('nd_experiment_stocks')->search_related('nd_experiment', {'nd_experiment.type_id'=>$experiment_type_id})->search_related('nd_experiment_projects')->search_related('project');
    if ($project_rs->count != 1){
        die "Seedlot does not have 1 breeding program project associated!\n";
    }
    my $breeding_program_id = $project_rs->first()->project_id();
    my $breeding_program_name = $project_rs->first()->name();
    $self->breeding_program_id($breeding_program_id);
    $self->breeding_program_name($breeding_program_name);
}

sub _store_seedlot_relationships {
    my $self = shift;
    my $error;

    eval {
        $error = $self->_store_seedlot_accessions();
        if (!$error){
            $error = $self->_store_seedlot_crosses();
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

sub _store_seedlot_accessions {
    my $self = shift;
    foreach my $a (@{$self->accession_stock_ids()}) {
        my $organism_id = $self->schema->resultset('Stock::Stock')->find({stock_id => $a})->organism_id();
        if ($self->organism_id){
            if ($self->organism_id != $organism_id){
                return "Accessions must all be the same organism, so that a population can group the seed lots.\n";
            }
        }
        $self->organism_id($organism_id);
    }

    my $type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema(), "collection_of", "stock_relationship")->cvterm_id();
    foreach my $a (@{$self->accession_stock_ids()}) {
        my $already_exists = $self->schema()->resultset("Stock::StockRelationship")->find({ object_id => $self->seedlot_id(), type_id => $type_id, subject_id=>$a });

        if ($already_exists) {
            print STDERR "Accession with id $a is already associated with seedlot id ".$self->seedlot_id()."\n";
            next;
        }
        my $row = $self->schema()->resultset("Stock::StockRelationship")->create({
            object_id => $self->seedlot_id(),
            subject_id => $a,
            type_id => $type_id,
        });
    }
}

sub _update_accession_stock_ids {
    my $self = shift;
    my $type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema(), "collection_of", "stock_relationship")->cvterm_id();
    my $acc_rs = $self->stock->search_related('stock_relationship_objects', {'type_id'=>$type_id});
    while (my $r=$acc_rs->next){
        $r->delete();
    }
    my $error = $self->_store_seedlot_accessions();
    return $error;
}

sub _retrieve_accessions {
    my $self = shift;

    my $type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema(), "collection_of", "stock_relationship")->cvterm_id();

    my $rs = $self->schema()->resultset("Stock::StockRelationship")->search( { type_id => $type_id, object_id => $self->seedlot_id() } );

    my @accession_ids;
    while (my $row = $rs->next()) {
	push @accession_ids, $row->subject_id();
    }

    $self->accession_stock_ids(\@accession_ids);

    $rs = $self->schema()->resultset("Stock::Stock")->search( { stock_id => { in => \@accession_ids }});
    my @names;
    while (my $s = $rs->next()) {
        push @names, [ $s->stock_id(), $s->uniquename() ];
    }
    $self->accessions(\@names);
}

sub _remove_accession {
    my $self = shift;
}


sub _store_seedlot_crosses {
    my $self = shift;
    foreach my $a (@{$self->cross_stock_ids()}) {
        my $organism_id = $self->schema->resultset('Stock::Stock')->find({stock_id => $a})->organism_id();
        if ($self->organism_id){
            if ($self->organism_id != $organism_id){
                return "Crosses must all be the same organism to be in a seed lot.\n";
            }
        }
        $self->organism_id($organism_id);
    }

    my $type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema(), "collection_of", "stock_relationship")->cvterm_id();
    foreach my $a (@{$self->cross_stock_ids()}) {
        my $already_exists = $self->schema()->resultset("Stock::StockRelationship")->find({ object_id => $self->seedlot_id(), type_id => $type_id, subject_id=>$a });

        if ($already_exists) {
            print STDERR "Cross with id $a is already associated with seedlot id ".$self->seedlot_id()."\n";
            next;
        }
        my $row = $self->schema()->resultset("Stock::StockRelationship")->create({
            object_id => $self->seedlot_id(),
            subject_id => $a,
            type_id => $type_id,
        });
    }
}

sub _update_cross_stock_ids {
    my $self = shift;
    my $type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema(), "collection_of", "stock_relationship")->cvterm_id();
    my $acc_rs = $self->stock->search_related('stock_relationship_objects', {'type_id'=>$type_id});
    while (my $r=$acc_rs->next){
        $r->delete();
    }
    my $error = $self->_store_seedlot_crosses();
    return $error;
}

sub _retrieve_crosses {
    my $self = shift;

    my $type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema(), "collection_of", "stock_relationship")->cvterm_id();

    my $rs = $self->schema()->resultset("Stock::StockRelationship")->search( { type_id => $type_id, object_id => $self->seedlot_id() } );

    my @cross_ids;
    while (my $row = $rs->next()) {
        push @cross_ids, $row->subject_id();
    }

    $self->cross_stock_ids(\@cross_ids);

    $rs = $self->schema()->resultset("Stock::Stock")->search( { stock_id => { in => \@cross_ids }});
    my @names;
    while (my $s = $rs->next()) {
        push @names, [ $s->stock_id(), $s->uniquename() ];
    }
    $self->crosses(\@names);
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
    foreach my $t (@$transactions) {
        $count += $t->amount() * $t->factor();
    }
    return $count;
}

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

sub get_current_count_property {
    my $self = shift;
    my $current_count_cvterm = SGN::Model::Cvterm->get_cvterm_row($self->schema, 'current_count', 'stock_property');
    my $recorded_current_count = $self->stock()->find_related('stockprops', {'me.type_id'=>$current_count_cvterm->cvterm_id});
    return $recorded_current_count->value();
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
            my $type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema, 'seedlot', 'stock_type')->cvterm_id();
            $self->type_id($type_id);
            my $id = $self->SUPER::store();
            print STDERR "Saving seedlot returned ID $id.".localtime."\n";
            $self->seedlot_id($id);
            $self->_store_seedlot_location();
            $error = $self->_store_seedlot_relationships();
            if ($error){
                die $error;
            }

        } else { #Updating seedlot
            if($self->accession_stock_ids){
                my $input_accession_ids = $self->accession_stock_ids;
                my $transactions = $self->transactions();
                my %stored_accessions = map {$_->[0] => 1} @{$self->accessions};
                my $accessions_have_changed;
                foreach (@$input_accession_ids){
                    if (!exists($stored_accessions{$_})){
                        $accessions_have_changed = 1;
                    }
                }
                if ($accessions_have_changed && scalar(@$transactions)>1){
                    $error = "This seedlot ".$self->uniquename." has been used in transactions, so the contents (accessions) cannot be changed now!";
                } else {
                    $error = $self->_update_accession_stock_ids();
                }
                if ($error){
                    die $error;
                }
            }
            if($self->cross_stock_ids){
                my $input_cross_ids = $self->cross_stock_ids;
                my $transactions = $self->transactions();
                my %stored_crosses = map {$_->[0] => 1} @{$self->crosses};
                my $crosses_have_changed;
                foreach (@$input_cross_ids){
                    if (!exists($stored_crosses{$_})){
                        $crosses_have_changed = 1;
                    }
                }
                if ($crosses_have_changed && scalar(@$transactions)>1){
                    $error = "This seedlot ".$self->uniquename." has been used in transactions, so the contents (crosses) cannot be changed now!";
                } else {
                    $error = $self->_update_cross_stock_ids();
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
        return { success=>1, seedlot_id=>$self->seedlot_id() };
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
    if (scalar(@$transactions)>1){
        $error = "This seedlot has been used in transactions and so cannot be deleted!";
    } else {
        my $stock = $self->stock();
        my $experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema(), "seedlot_experiment", "experiment_type")->cvterm_id();
        my $nd_experiment_rs = $self->schema()->resultset('Stock::Stock')->search({'me.stock_id'=>$self->seedlot_id})->search_related('nd_experiment_stocks')->search_related('nd_experiment', {'nd_experiment.type_id'=>$experiment_type_id});
        if ($nd_experiment_rs->count != 1){
            $error = "Seedlot does not have 1 nd_experiment associated!";
        } else {
            my $nd_experiment = $nd_experiment_rs->first();
            $nd_experiment->delete();
            $stock->delete();
        }
    }

    return $error;
}

1;

no Moose;
__PACKAGE__->meta->make_immutable;
