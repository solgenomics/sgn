package CXGN::Trial::TrialDesignStore;

=head1 NAME

CXGN::Trial::TrialDesignStore - Module to validate and store a trial's design (both genotyping and phenotyping trials)

Store will do the following: (for genotyping trials, replace 'plot' with 'tissue_sample')
1) Search for a trial's associated nd_experiment. There should only be one nd_experiment of type = field_layout or genotyping_layout.
2) Searches for the accession's stock_name.
# TO BE IMPLEMENTED: A boolean option to allow stock_names to be added to the database on the fly. Normally this would be set to 0, but for certain loading scripts this could be set to 1.
3) Finds or creates a stock entry for each plot_name in the design hash.
#TO BE IMPLEMENTED: Associate an owner to the plot
4) Creates stockprops (block, rep, plot_number, etc) for plots.
5) For each plot, creates a stock relationship between the plot and accession if not already present.
6) For each plot, creates an nd_experiment_stock entry if not already present. They are all linked to the same nd_experiment entry found in step 1.
7) Finds or creates a stock entry for each plant_names in the design hash.
#TO BE IMPLEMENTED: Associate an owner to the plant
8) Creates stockprops (block, rep, plot_number, plant_index_number, etc) for plants.
8) For each plant, creates a stock_relationship between the plant and accession if not already present.
9) For each plant, creates a stock_relationship between the plant and plot if not already present.
10) For each plant creates an nd_experiment_stock entry if not already present. They are all linked to the same nd_experiment entry found in step 1.

=head1 USAGE

 my $design_store = CXGN::Trial::TrialDesignStore->new({
	bcs_schema => $c->dbic_schema("Bio::Chado::Schema"),
	trial_id => $trial_id,
	design_type => 'CRD',
	design => $design_hash,
        trial_type => "pyt", # etc...
	trial_class => "phenotyping" # default
 });
 my $validate_error = $design_store->validate_design();
 my $store_error;
 if ($validate_error) {
 	print STDERR "VALIDATE ERROR: $validate_error\n";
 } else {
 	try {
		$store error = $design_store->store();
	} catch {
		$store_error = $_;
 	};
}
if ($store_error) {
	print STDERR "ERROR SAVING TRIAL!: $store_error\n";
}


=head1 DESCRIPTION


=head1 AUTHORS

 Nicolas Morales (nm529@cornell.edu)

=cut


use Moose;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;
use Try::Tiny;
use CXGN::Stock::StockLookup;
use CXGN::BreedersToolbox::Projects;
use CXGN::Trial;
use SGN::Model::Cvterm;
use Data::Dumper;

has 'bcs_schema' => (
	is       => 'rw',
	isa      => 'DBIx::Class::Schema',
	predicate => 'has_chado_schema',
	required => 1,
);
has 'trial_id' => (isa => 'Int', is => 'rw', predicate => 'has_trial_id', required => 1);
has 'nd_geolocation_id' => (isa => 'Int', is => 'rw', predicate => 'has_nd_geolocation_id', required => 1);
has 'design_type' => (isa => 'Str', is => 'rw', predicate => 'has_design_type', required => 1);
has 'design' => (isa => 'HashRef[HashRef[Str|ArrayRef]]|Undef', is => 'rw', predicate => 'has_design', required => 1);
#has 'is_genotyping' => (isa => 'Bool', is => 'rw', required => 0, default => 0);
has 'trial_class' => (isa => 'Str', is => 'rw', default => 'phenotyping' ); # phenotyping, genotyping, or averaged_trial
has 'stocks_exist' => (isa => 'Bool', is => 'rw', required => 0, default => 0);

sub validate_design {
	print STDERR "validating design\n";
	my $self = shift;
	my $chado_schema = $self->get_bcs_schema;
	my $design_type = $self->get_design_type;
	my %design = %{$self->get_design};
	my $error = '';

	if (( $self->get_trial_class() eq "genotyping") && ($design_type ne 'genotyping_plate')) {
	    $error .= "trial type is genotyping; however design_type not equal to 'genotyping_plate'";
	    return $error
	}
	if ((!$self->get_trial_class() eq "genotyping") && ($design_type eq 'genotyping_plate')) {
	    $error .= "The design_type 'genotyping_plate' requires is_genotyping to be true";
	    return $error;
	}
	if ($design_type ne 'genotyping_plate' && $design_type ne 'CRD' && $design_type ne 'Alpha' && $design_type && 'Augmented' && $design_type ne 'RCBD'){
	    $error .= "Design type must be either: genotyping_plate, CRD, Alpha, Augmented, or RCBD";
	    return $error;
	}
	if (($self->get_trial_class() eq "averaged_trial") && (($design_type ne "mean") || ($design_type ne "..."))) { 
	    $error .= "For averaged_trial, a correct averaging method must be supplied.";
	    return $error;
	}
	
	my @valid_properties;
	if ($design_type eq 'genotyping_plate'){
		@valid_properties = (
			'stock_name',
			'plot_name'
		);
		#plot_name is tissue sample name in well. during store, the stock is saved as stock_type 'tissue_sample' with uniquename = plot_name
	} elsif ($design_type eq 'CRD' || $design_type eq 'Alpha' || $design_type eq 'Augmented' || $design_type eq 'RCBD'){
	    @valid_properties = (
		'stock_name',
		'plot_name',
		'plot_number',
		'block_number',
		'rep_number',
		'is_a_control',
		'range_number',
		'row_number',
		'col_number',
		'plant_names'
		);
	}
	my %allowed_properties = map {$_ => 1} @valid_properties;

	my $plot_type_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plot', 'stock_type')->cvterm_id();
	my $plant_type_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plant', 'stock_type')->cvterm_id();
	my $tissue_type_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'tissue_sample', 'stock_type')->cvterm_id();
	my $accession_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'accession', 'stock_type');

	my %saved_stocks;
	my $stocks = $chado_schema->resultset('Stock::Stock')->search(
	    {
		type_id=>[$plot_type_id, $plant_type_id, $tissue_type_id]
	    });

	while (my $s = $stocks->next()) {
		$saved_stocks{$s->uniquename} = 1;
	}

	foreach my $stock (keys %design){
	    foreach my $property (keys %{$design{$stock}}){
		if (!exists($allowed_properties{$property})) {
		    $error .= "Property: $property not allowed! ";
		}
		if ($property eq 'plot_name') {
		    my $plot_name = $design{$stock}->{$property};
		    if (exists($saved_stocks{$plot_name}) && $self->get_stocks_exist() == 0) {
			$error .= "Plot or tissue $plot_name already exists in the database.";
		    }
		}
		if ($property eq 'plant_names') {
		    my $plant_names = $design{$stock}->{$property};
		    foreach (@$plant_names) {
			if (exists($saved_stocks{$_})) {
			    $error .= "Plant $_ already exists in the database.";
			}
		    }
		}
	    }
	}
	return $error;
}

sub store {
    print STDERR "Saving design\n";
    my $self = shift;
    my $chado_schema = $self->get_bcs_schema;
    my $design_type = $self->get_design_type;
    my %design = %{$self->get_design};
    my $trial_id = $self->get_trial_id;
    my $nd_geolocation_id = $self->get_nd_geolocation_id;
    
    my $accession_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'accession', 'stock_type');
    my $plant_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plant', 'stock_type');
    my $plant_of = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plant_of', 'stock_relationship');
    my $plant_index_number_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plant_index_number', 'stock_property');
    my $replicate_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'replicate', 'stock_property');
    my $block_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'block', 'stock_property');
    my $plot_number_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plot number', 'stock_property');
    my $is_control_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'is a control', 'stock_property');
    my $range_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'range', 'stock_property');
    my $row_number_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'row_number', 'stock_property');
    my $col_number_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'col_number', 'stock_property');
    
    my $nd_experiment_type_id;
    my $stock_type_id;
    my $stock_rel_type_id;
    
    if ($self->get_trial_class() eq "phenotyping") {
	$nd_experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'field_layout', 'experiment_type')->cvterm_id();
	$stock_type_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plot', 'stock_type')->cvterm_id();
	$stock_rel_type_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plot_of', 'stock_relationship')->cvterm_id();
    } 
    elsif ($self->get_trial_class() eq "genotyping") {
	$nd_experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'genotyping_layout', 'experiment_type')->cvterm_id();
	$stock_type_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'tissue_sample', 'stock_type')->cvterm_id();
	$stock_rel_type_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'tissue_sample_of', 'stock_relationship')->cvterm_id();
    }
    elsif ($self->get_trial_class() eq "averaged_trial") { 
	$nd_experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'averaged_trial', 'experiment_type')->cvterm_id();
	$stock_type_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plot', 'stock_type')->cvterm_id();
	$stock_rel_type_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plot_of', 'stock_relationship')->cvterm_id();	
	# # the trial should already exist, let's retrieve it and its member accessions. The user should not call
	# # the set_stock_names(), it will be overwritten with the correct values here anyway.
	# # 
	# my $trial = CXGN::Trial->new( { bcs_schema => $chado_schema, trial_id => $trial_id });
	# my $accession_list =  [ map { $_->{accersion_name} } @{$trial->get_accessions()} ];
	# $self->set_stock_names($accession_list);
    }
    
    my $nd_experiment_project;
    my $nd_experiment_project_rs = $chado_schema->resultset('NaturalDiversity::NdExperimentProject')->search(
	{
	    'me.project_id'=>$trial_id,
	    'nd_experiment.type_id'=>$nd_experiment_type_id,
	    'nd_experiment.nd_geolocation_id'=>$nd_geolocation_id
	},
	{ join => 'nd_experiment'}
	);
    
    if ($nd_experiment_project_rs->count < 1) {
	my $nd_experiment = $chado_schema->resultset('NaturalDiversity::NdExperiment')
	    ->create({
		nd_geolocation_id => $self->get_nd_geolocation_id,
		type_id => $nd_experiment_type_id,
		     });
	$nd_experiment_project = $nd_experiment->find_or_create_related('nd_experiment_projects', {project_id => $trial_id} );
    } 
    elsif ($nd_experiment_project_rs->count > 1) {
	print STDERR "ERROR: More than one nd_experiment of type=$nd_experiment_type_id for project=$trial_id\n";
	$nd_experiment_project = $nd_experiment_project_rs->first;
    } 
    elsif ($nd_experiment_project_rs->count == 1) {
	print STDERR "OKAY: NdExperimentProject type=$nd_experiment_type_id for project$trial_id\n";
	$nd_experiment_project = $nd_experiment_project_rs->first;
    }
    
    # is there a way to make this caching smaller? In cassavabase, there are quite a few accessions...
    #
    my $rs = $chado_schema->resultset('Stock::Stock')->search(
	{ 'me.is_obsolete' => { '!=' => 't' }, 'me.type_id' => $accession_cvterm->cvterm_id },
	{ join => [ 'stock_relationship_objects', 'nd_experiment_stocks' ],
	  '+select'=> ['me.stock_id', 'me.uniquename', 'me.organism_id', 'stock_relationship_objects.type_id', 'stock_relationship_objects.subject_id', 'nd_experiment_stocks.nd_experiment_id', 'nd_experiment_stocks.type_id'],
	  '+as'=> ['stock_id', 'uniquename', 'organism_id', 'stock_relationship_type_id', 'stock_relationship_subject_id', 'stock_experiment_id', 'stock_experiment_type_id']
	}
	);
    
    my %stock_data;
    my %stock_relationship_data;
    my %stock_experiment_data;
    while (my $s = $rs->next()) {
	$stock_data{$s->get_column('uniquename')} = [$s->get_column('stock_id'), $s->get_column('organism_id') ];
	if ($s->get_column('stock_relationship_type_id') && $s->get_column('stock_relationship_subject_id') ) {
	    $stock_relationship_data{$s->get_column('stock_id'), $s->get_column('stock_relationship_type_id'), $s->get_column('stock_relationship_subject_id') } = 1;
	}
	if ($s->get_column('stock_experiment_id') && $s->get_column('stock_experiment_type_id') ) {
	    $stock_experiment_data{$s->get_column('stock_id'), $s->get_column('stock_experiment_id'), $s->get_column('stock_experiment_type_id')} = 1;
	}
    }
    
    my $stock_id_checked;
    my $organism_id_checked;
    
    my $coderef = sub {
	
	#print STDERR Dumper \%design;
	foreach my $key (sort { $a cmp $b} keys %design) {
	    
	    my $plot_name;
	    if ($design{$key}->{plot_name}) {
		$plot_name = $design{$key}->{plot_name};
	    }
	    my $plot_number;
	    if ($design{$key}->{plot_number}) {
		$plot_number = $design{$key}->{plot_number};
	    } 
	    else {
		$plot_number = $key;
	    }
	    my $plant_names;
	    if ($design{$key}->{plant_names}) {
		$plant_names = $design{$key}->{plant_names};
	    }
	    my $stock_name;
	    if ($design{$key}->{stock_name}) {
		$stock_name = $design{$key}->{stock_name};
	    }
	    my $block_number;
	    if ($design{$key}->{block_number}) { #set block number to 1 if no blocks are specified
		$block_number = $design{$key}->{block_number};
	    } 
	    else {
		$block_number = 1;
	    }
	    my $rep_number;
	    if ($design{$key}->{rep_number}) { #set rep number to 1 if no reps are specified
		$rep_number = $design{$key}->{rep_number};
	    } 
	    else {
		$rep_number = 1;
	    }
	    my $is_a_control;
	    if ($design{$key}->{is_a_control}) {
		$is_a_control = $design{$key}->{is_a_control};
	    }
	    my $row_number;
	    if ($design{$key}->{row_number}) {
		$row_number = $design{$key}->{row_number};
	    }
	    my $col_number;
	    if ($design{$key}->{col_number}) {
		$col_number = $design{$key}->{col_number};
	    }
	    my $range_number;
	    if ($design{$key}->{range_number}) {
		$range_number = $design{$key}->{range_number};
	    }
	    
	    #check if stock_name exists in database by checking if stock_name is key in %stock_data. if it is not, then check if it exists as a synonym in the database.
	    if ($stock_data{$stock_name}) {
		$stock_id_checked = $stock_data{$stock_name}[0];
		$organism_id_checked = $stock_data{$stock_name}[1];
	    } 
	    else {
		my $parent_stock;
		my $stock_lookup = CXGN::Stock::StockLookup->new(schema => $chado_schema);
		$stock_lookup->set_stock_name($stock_name);
		$parent_stock = $stock_lookup->get_stock();
		
		if (!$parent_stock) {
		    die ("Error while saving trial layout: no stocks found matching $stock_name");
		}
		
		$stock_id_checked = $parent_stock->stock_id();
		$organism_id_checked = $parent_stock->organism_id();
	    }
	    
	    #create the plot, if plot given
	    my $plot;
	    if ($plot_name) {
		$plot = $chado_schema->resultset("Stock::Stock")
		    ->find_or_create({
			organism_id => $organism_id_checked,
			name       => $plot_name,
			uniquename => $plot_name,
			type_id => $stock_type_id,
				     });
		$plot->create_stockprops({$replicate_cvterm->name() => $rep_number});
		$plot->create_stockprops({$block_cvterm->name() => $block_number});
		$plot->create_stockprops({$plot_number_cvterm->name() => $plot_number});
		if ($is_a_control) {
		    $plot->create_stockprops({$is_control_cvterm->name() => $is_a_control});
		}
		if ($range_number) {
		    $plot->create_stockprops({$range_cvterm->name() => $range_number});
		}
		if ($row_number) {
		    $plot->create_stockprops({$row_number_cvterm->name() => $row_number});
		}
		if ($col_number) {
		    $plot->create_stockprops({$col_number_cvterm->name() => $col_number});
		}
		
		#create the stock_relationship of the accession with the plot, if it does not exist already
		if (!$stock_relationship_data{$stock_id_checked, $stock_rel_type_id, $plot->stock_id()} ) {
		    my $parent_stock = $chado_schema->resultset("Stock::StockRelationship")->create({
			object_id => $stock_id_checked,
			type_id => $stock_rel_type_id,
			subject_id => $plot->stock_id()
												    });
		}
		
		#link the experiment to the plot, if it is not already
		if (!$stock_experiment_data{$plot->stock_id(), $nd_experiment_project->nd_experiment_id(), $nd_experiment_type_id} ) {
		    my $stock_experiment_link = $chado_schema->resultset("NaturalDiversity::NdExperimentStock")->create({
			nd_experiment_id => $nd_experiment_project->nd_experiment_id(),
			type_id => $nd_experiment_type_id,
			stock_id => $plot->stock_id(),
															});
		}
	    }
	    
	    #Create plant entry if given. Currently this is for the greenhouse trial creation.
	    if ($plant_names) {
		my $plant_index_number = 1;
		foreach my $plant_name (@$plant_names) {
		    my $plant = $chado_schema->resultset("Stock::Stock")
			->find_or_create({
			    organism_id => $organism_id_checked,
			    name       => $plant_name,
			    uniquename => $plant_name,
			    type_id => $plant_cvterm->cvterm_id,
					 });
		    
		    $plant->create_stockprops({$plant_index_number_cvterm->name() => $plant_index_number});
		    $plant_index_number++;
		    $plant->create_stockprops({$replicate_cvterm->name() => $rep_number});
		    $plant->create_stockprops({$block_cvterm->name() => $block_number});
		    $plant->create_stockprops({$plot_number_cvterm->name() => $plot_number});
		    if ($is_a_control) {
			$plant->create_stockprops({$is_control_cvterm->name() => $is_a_control});
		    }
		    if ($range_number) {
			$plant->create_stockprops({$range_cvterm->name() => $range_number});
		    }
		    if ($row_number) {
			$plant->create_stockprops({$row_number_cvterm->name() => $row_number});
		    }
		    if ($col_number) {
			$plant->create_stockprops({$col_number_cvterm->name() => $col_number});
		    }
		    
		    #the plant has a relationship to the plot
		    if (!$stock_relationship_data{$plant->stock_id(), $plant_of->cvterm_id(), $plot->stock_id()} ) {
			my $stock_relationship = $chado_schema->resultset("Stock::StockRelationship")->create(
			    {
				subject_id => $plot->stock_id,
				object_id => $plant->stock_id(),
				type_id => $plant_of->cvterm_id(),
			    });
		    }
		    
		    #create the stock_relationship of the accession with the plant, if it does not exist already
		    if (!$stock_relationship_data{$stock_id_checked, $plant_of->cvterm_id(), $plant->stock_id()} ) {
			my $parent_stock = $chado_schema->resultset("Stock::StockRelationship")->create(
			    {
				object_id => $stock_id_checked,
				type_id => $plant_of->cvterm_id(),
				subject_id => $plant->stock_id()
			    });
		    }
		    
		    #link the experiment to the plant, if it is not already
		    if (!$stock_experiment_data{$plant->stock_id(), $nd_experiment_project->nd_experiment_id(), $nd_experiment_type_id} ) {
			my $stock_experiment_link = $chado_schema->resultset("NaturalDiversity::NdExperimentStock")->create(
			    {
				nd_experiment_id => $nd_experiment_project->nd_experiment_id(),
				type_id => $nd_experiment_type_id,
				stock_id => $plant->stock_id(),
			    });
		    }
		}
	    }
	}	
    };
    
    my $transaction_error;
    try {
	$chado_schema->txn_do($coderef);
    } catch {
	print STDERR "Transaction Error: $_\n";
	$transaction_error =  $_;
    };
    return $transaction_error;
}

1;
