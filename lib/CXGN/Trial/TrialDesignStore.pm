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
    trial_name => $trial_name,
	design_type => 'CRD',
	design => $design_hash,
	is_genotyping => 0
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
use CXGN::Trial;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::List::Validate;
use CXGN::Stock::Seedlot::Transaction;

has 'bcs_schema' => (
	is       => 'rw',
	isa      => 'DBIx::Class::Schema',
	predicate => 'has_chado_schema',
	required => 1,
);
has 'trial_id' => (isa => 'Int', is => 'rw', predicate => 'has_trial_id', required => 1);
has 'trial_name' => (isa => 'Str', is => 'rw', predicate => 'has_trial_name', required => 0);
has 'nd_experiment_id' => (isa => 'Int', is => 'rw', predicate => 'has_nd_experiment_id', required => 0);
has 'nd_geolocation_id' => (isa => 'Int', is => 'rw', predicate => 'has_nd_geolocation_id', required => 1);
has 'design_type' => (isa => 'Str', is => 'rw', predicate => 'has_design_type', required => 1);
has 'design' => (isa => 'HashRef[HashRef[Str|ArrayRef|HashRef]]|Undef', is => 'rw', predicate => 'has_design', required => 1);
has 'is_genotyping' => (isa => 'Bool', is => 'rw', required => 0, default => 0);
has 'stocks_exist' => (isa => 'Bool', is => 'rw', required => 0, default => 0);
has 'new_treatment_has_plant_entries' => (isa => 'Maybe[Int]', is => 'rw', required => 0, default => 0);
has 'new_treatment_has_subplot_entries' => (isa => 'Maybe[Int]', is => 'rw', required => 0, default => 0);
has 'operator' => (isa => 'Str', is => 'rw', required => 1);

sub validate_design {
	print STDERR "validating design\n";
	my $self = shift;
	my $chado_schema = $self->get_bcs_schema;
	my $design_type = $self->get_design_type;
	my %design = %{$self->get_design};
	my $error = '';

	if ($self->get_is_genotyping && $design_type ne 'genotyping_plate') {
		$error .= "is_genotyping is true; however design_type not equal to 'genotyping_plate'";
		return $error;
	}
	if (!$self->get_is_genotyping && $design_type eq 'genotyping_plate') {
		$error .= "The design_type 'genotyping_plate' requires is_genotyping to be true";
		return $error;
	}
	if ($design_type ne 'genotyping_plate' && $design_type ne 'CRD' && $design_type ne 'Alpha' && $design_type && 'Augmented' && $design_type ne 'RCBD' && $design_type ne 'p-rep' && $design_type ne 'splitplot'){
		$error .= "Design $design_type type must be either: genotyping_plate, CRD, Alpha, Augmented, RCBD, p-rep, or splitplot";
		return $error;
	}
	my @valid_properties;
	if ($design_type eq 'genotyping_plate'){
		@valid_properties = (
			'stock_name',
			'plot_name'
		);
		#plot_name is tissue sample name in well. during store, the stock is saved as stock_type 'tissue_sample' with uniquename = plot_name
	} elsif ($design_type eq 'CRD' || $design_type eq 'Alpha' || $design_type eq 'Augmented' || $design_type eq 'RCBD' || $design_type eq 'p-rep' || $design_type eq 'splitplot'){
		@valid_properties = (
			'seedlot_name',
			'stock_name',
			'plot_name',
			'plot_number',
			'block_number',
			'rep_number',
			'is_a_control',
			'range_number',
			'row_number',
			'col_number',
			'plant_names',
			'plot_num_per_block',
			'subplots_names', #For splotplot
			'treatments', #For splitplot
			'subplots_plant_names', #For splitplot
		);
	}
	my %allowed_properties = map {$_ => 1} @valid_properties;

	my %seen_stock_names;
	my %seen_source_names;
	my %seen_accession_names;
	foreach my $stock (keys %design){
		if ($stock eq 'treatments'){
			next;
		}
		foreach my $property (keys %{$design{$stock}}){
			if (!exists($allowed_properties{$property})) {
				$error .= "Property: $property not allowed! ";
			}
			if ($property eq 'stock_name') {
				my $stock_name = $design{$stock}->{$property};
				$seen_accession_names{$stock_name}++;
			}
			if ($property eq 'seedlot_name') {
				my $stock_name = $design{$stock}->{$property};
				$seen_source_names{$stock_name}++;
			}
			if ($property eq 'plot_name') {
				my $plot_name = $design{$stock}->{$property};
				$seen_stock_names{$plot_name}++;
			}
			if ($property eq 'plant_names') {
				my $plant_names = $design{$stock}->{$property};
				foreach (@$plant_names) {
					$seen_stock_names{$_}++;
				}
			}
			if ($property eq 'subplots_names') {
				my $subplot_names = $design{$stock}->{$property};
				foreach (@$subplot_names) {
					$seen_stock_names{$_}++;
				}
			}
		}
	}

	my @stock_names = keys %seen_stock_names;
	my @source_names = keys %seen_source_names;
	my @accession_names = keys %seen_accession_names;
	if(scalar(@stock_names)<1){
		$error .= "You cannot create a trial with less than one plot.";
	}
	if(scalar(@source_names)<1){
		$error .= "You cannot create a trial with less than one seedlot.";
	}
	if(scalar(@accession_names)<1){
		$error .= "You cannot create a trial with less than one accession.";
	}
	my $subplot_type_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'subplot', 'stock_type')->cvterm_id();
	my $plot_type_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plot', 'stock_type')->cvterm_id();
	my $plant_type_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plant', 'stock_type')->cvterm_id();
	my $tissue_type_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'tissue_sample', 'stock_type')->cvterm_id();
	my $stocks = $chado_schema->resultset('Stock::Stock')->search({
		type_id=>[$subplot_type_id, $plot_type_id, $plant_type_id, $tissue_type_id],
		uniquename=>{-in=>\@stock_names}
	});
	while (my $s = $stocks->next()) {
		$error .= "Name $_ already exists in the database.";
	}

	my $seedlot_validator = CXGN::List::Validate->new();
	my @seedlots_missing = @{$seedlot_validator->validate($chado_schema,'seedlots',\@source_names)->{'missing'}};
	if (scalar(@seedlots_missing) > 0) {
		$error .=  "The following seedlots are not in the database as uniquenames or synonyms: ".join(',',@seedlots_missing);
	}
	my $accession_validator = CXGN::List::Validate->new();
	my @accessions_missing = @{$accession_validator->validate($chado_schema,'accessions',\@accession_names)->{'missing'}};
	if (scalar(@accessions_missing) > 0) {
		$error .=  "The following accessions are not in the database as uniquenames or synonyms: ".join(',',@accessions_missing);
	}

	return $error;
}

sub store {
	print STDERR "Saving design ".localtime()."\n";
	my $self = shift;
	my $chado_schema = $self->get_bcs_schema;
	my $design_type = $self->get_design_type;
	my %design = %{$self->get_design};
	my $trial_id = $self->get_trial_id;
	my $nd_geolocation_id = $self->get_nd_geolocation_id;

	my $seedlot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'seedlot', 'stock_type')->cvterm_id();
	my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'accession', 'stock_type')->cvterm_id();
	my $subplot_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'subplot', 'stock_type');
	my $subplot_of = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'subplot_of', 'stock_relationship');
	my $plant_of_subplot = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plant_of_subplot', 'stock_relationship');
	my $subplot_index_number_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'subplot_index_number', 'stock_property');
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
	my $treatment_nd_experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'treatment_experiment', 'experiment_type')->cvterm_id();
	my $project_design_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'design', 'project_property');
	my $trial_treatment_relationship_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'trial_treatment_relationship', 'project_relationship')->cvterm_id();
	my $has_plants_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'project_has_plant_entries', 'project_property')->cvterm_id();
	my $has_subplots_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'project_has_subplot_entries', 'project_property')->cvterm_id();

	my $nd_experiment_type_id;
	my $stock_type_id;
	my $stock_rel_type_id;
	if (!$self->get_is_genotyping) {
		$nd_experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'field_layout', 'experiment_type')->cvterm_id();
		$stock_type_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plot', 'stock_type')->cvterm_id();
		$stock_rel_type_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plot_of', 'stock_relationship')->cvterm_id();
	} else {
		$nd_experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'genotyping_layout', 'experiment_type')->cvterm_id();
		$stock_type_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'tissue_sample', 'stock_type')->cvterm_id();
		$stock_rel_type_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'tissue_sample_of', 'stock_relationship')->cvterm_id();
	}

	my $nd_experiment_id;
	if ($self->has_nd_experiment_id){
		$nd_experiment_id = $self->get_nd_experiment_id();
	} else {
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
		} elsif ($nd_experiment_project_rs->count > 1) {
			print STDERR "ERROR: More than one nd_experiment of type=$nd_experiment_type_id for project=$trial_id\n";
			$nd_experiment_project = $nd_experiment_project_rs->first;
		} elsif ($nd_experiment_project_rs->count == 1) {
			print STDERR "OKAY: NdExperimentProject type=$nd_experiment_type_id for project$trial_id\n";
			$nd_experiment_project = $nd_experiment_project_rs->first;
		}
		if ($nd_experiment_project){
			$nd_experiment_id = $nd_experiment_project->nd_experiment_id();
		}
	}

	my %seen_accessions_hash;
	my %seen_seedlots_hash;
	foreach my $key (keys %design) {
		if ($design{$key}->{stock_name}) {
			my $stock_name = $design{$key}->{stock_name};
			$seen_accessions_hash{$stock_name}++;
		}
		if ($design{$key}->{seedlot_name}) {
			my $stock_name = $design{$key}->{seedlot_name};
			$seen_seedlots_hash{$stock_name}++;
		}
	}
	my @seen_accessions = keys %seen_accessions_hash;
	my @seen_seedlots = keys %seen_seedlots_hash;

	my $seedlot_rs = $chado_schema->resultset('Stock::Stock')->search({
		'is_obsolete' => { '!=' => 't' },
		'type_id' => $seedlot_cvterm_id,
		'uniquename' => {-in=>\@seen_seedlots}
	});
	my %seedlot_data;
	while (my $s = $seedlot_rs->next()) {
		$seedlot_data{$s->uniquename} = $s->stock_id;
	}

	my $rs = $chado_schema->resultset('Stock::Stock')->search({
		'is_obsolete' => { '!=' => 't' },
		'type_id' => $accession_cvterm_id,
		'uniquename' => {-in=>\@seen_accessions}
	});
	my %stock_data;
	while (my $s = $rs->next()) {
		$stock_data{$s->uniquename} = [$s->stock_id, $s->organism_id];
	}

	my $stock_id_checked;
	my $stock_name_checked;
	my $organism_id_checked;
	my $timestamp = localtime();

	my $coderef = sub {

		#print STDERR Dumper \%design;
		my %new_stock_ids_hash;
		foreach my $key (keys %design) {

			if ($key eq 'treatments'){
				next;
			}

			my $plot_name;
			if ($design{$key}->{plot_name}) {
				$plot_name = $design{$key}->{plot_name};
			}
			my $plot_number;
			if ($design{$key}->{plot_number}) {
				$plot_number = $design{$key}->{plot_number};
			} else {
				$plot_number = $key;
			}
			my $plant_names;
			if ($design{$key}->{plant_names}) {
				$plant_names = $design{$key}->{plant_names};
			}
			my $subplot_names;
			if ($design{$key}->{subplots_names}) {
				$subplot_names = $design{$key}->{subplots_names};
			}
			my $subplots_plant_names;
			if ($design{$key}->{subplots_plant_names}) {
				$subplots_plant_names = $design{$key}->{subplots_plant_names};
			}
			my $stock_name;
			if ($design{$key}->{stock_name}) {
				$stock_name = $design{$key}->{stock_name};
			}
			my $seedlot_name;
			my $seedlot_stock_id;
			if ($design{$key}->{seedlot_name}) {
				$seedlot_name = $design{$key}->{seedlot_name};
				$seedlot_stock_id = $seedlot_data{$seedlot_name};
			}
			my $block_number;
			if ($design{$key}->{block_number}) { #set block number to 1 if no blocks are specified
				$block_number = $design{$key}->{block_number};
			} else {
				$block_number = 1;
			}
			my $rep_number;
			if ($design{$key}->{rep_number}) { #set rep number to 1 if no reps are specified
				$rep_number = $design{$key}->{rep_number};
			} else {
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
				$stock_name_checked = $stock_name;
			} else {
				my $parent_stock;
				my $stock_lookup = CXGN::Stock::StockLookup->new(schema => $chado_schema);
				$stock_lookup->set_stock_name($stock_name);
				$parent_stock = $stock_lookup->get_stock();

				if (!$parent_stock) {
					die ("Error while saving trial layout: no stocks found matching $stock_name");
				}

				$stock_id_checked = $parent_stock->stock_id();
				$stock_name_checked = $parent_stock->uniquename;
				$organism_id_checked = $parent_stock->organism_id();
			}

			#create the plot, if plot given
			my $plot;
			if ($plot_name) {
				$plot = $chado_schema->resultset("Stock::Stock")
				->create({
					organism_id => $organism_id_checked,
					name       => $plot_name,
					uniquename => $plot_name,
					type_id => $stock_type_id,
				});
				$new_stock_ids_hash{$plot_name} = $plot->stock_id();
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

				my $parent_stock = $chado_schema->resultset("Stock::StockRelationship")->create({
					object_id => $stock_id_checked,
					type_id => $stock_rel_type_id,
					subject_id => $plot->stock_id()
				});

				my $stock_experiment_link = $chado_schema->resultset("NaturalDiversity::NdExperimentStock")->create({
					nd_experiment_id => $nd_experiment_id,
					type_id => $nd_experiment_type_id,
					stock_id => $plot->stock_id(),
				});

				my $transaction = CXGN::Stock::Seedlot::Transaction->new(schema => $chado_schema);
				$transaction->from_stock([$seedlot_stock_id, $seedlot_name]);
				$transaction->to_stock([$plot->stock_id(), $plot->uniquename()]);
				$transaction->amount(1);
				$transaction->timestamp($timestamp);
				my $description = "Created Trial: ".$self->get_trial_name." Plot: ".$plot->uniquename;
				$transaction->description($description);
				$transaction->operator($self->get_operator);
				my $transaction_id = $transaction->store();
			}

			#Create plant entry if given. Currently this is for the greenhouse trial creation and splitplot trial creation.
			if ($plant_names) {
				my $plant_index_number = 1;
				foreach my $plant_name (@$plant_names) {
					my $plant = $chado_schema->resultset("Stock::Stock")
					->create({
						organism_id => $organism_id_checked,
						name       => $plant_name,
						uniquename => $plant_name,
						type_id => $plant_cvterm->cvterm_id,
					});
					$new_stock_ids_hash{$plant_name} = $plant->stock_id();
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

					my $stock_relationship = $chado_schema->resultset("Stock::StockRelationship")->create({
						subject_id => $plot->stock_id,
						object_id => $plant->stock_id(),
						type_id => $plant_of->cvterm_id(),
					});

					my $parent_stock = $chado_schema->resultset("Stock::StockRelationship")->create({
						object_id => $stock_id_checked,
						type_id => $plant_of->cvterm_id(),
						subject_id => $plant->stock_id()
					});

					my $stock_experiment_link = $chado_schema->resultset("NaturalDiversity::NdExperimentStock")->create({
						nd_experiment_id => $nd_experiment_id,
						type_id => $nd_experiment_type_id,
						stock_id => $plant->stock_id(),
					});

				}
			}
			#Create subplot entry if given. Currently this is for the splitplot trial creation.
			if ($subplot_names) {
				my $subplot_index_number = 1;
				foreach my $subplot_name (@$subplot_names) {
					my $subplot = $chado_schema->resultset("Stock::Stock")
					->create({
						organism_id => $organism_id_checked,
						name       => $subplot_name,
						uniquename => $subplot_name,
						type_id => $subplot_cvterm->cvterm_id,
					});
					$new_stock_ids_hash{$subplot_name} = $subplot->stock_id();
					$subplot->create_stockprops({$subplot_index_number_cvterm->name() => $subplot_index_number});
					$subplot_index_number++;
					$subplot->create_stockprops({$replicate_cvterm->name() => $rep_number});
					$subplot->create_stockprops({$block_cvterm->name() => $block_number});
					$subplot->create_stockprops({$plot_number_cvterm->name() => $plot_number});
					if ($is_a_control) {
						$subplot->create_stockprops({$is_control_cvterm->name() => $is_a_control});
					}
					if ($range_number) {
						$subplot->create_stockprops({$range_cvterm->name() => $range_number});
					}
					if ($row_number) {
						$subplot->create_stockprops({$row_number_cvterm->name() => $row_number});
					}
					if ($col_number) {
						$subplot->create_stockprops({$col_number_cvterm->name() => $col_number});
					}

					my $stock_relationship = $chado_schema->resultset("Stock::StockRelationship")->create({
						subject_id => $plot->stock_id,
						object_id => $subplot->stock_id(),
						type_id => $subplot_of->cvterm_id(),
					});

					my $parent_stock = $chado_schema->resultset("Stock::StockRelationship")->create({
						object_id => $stock_id_checked,
						type_id => $subplot_of->cvterm_id(),
						subject_id => $subplot->stock_id()
					});

					my $stock_experiment_link = $chado_schema->resultset("NaturalDiversity::NdExperimentStock")->create({
						nd_experiment_id => $nd_experiment_id,
						type_id => $nd_experiment_type_id,
						stock_id => $subplot->stock_id(),
					});

					if ($subplots_plant_names){
						my $subplot_plants = $subplots_plant_names->{$subplot_name};
						foreach (@$subplot_plants) {
							my $plant_stock_id = $new_stock_ids_hash{$_};
							my $plant_to_subplot = $chado_schema->resultset("Stock::StockRelationship")->create({
								object_id => $subplot->stock_id(),
								type_id => $plant_of_subplot->cvterm_id(),
								subject_id => $plant_stock_id
							});
						}
					}

				}
			}
		}

		if (exists($design{treatments})){
			while(my($treatment_name, $stock_names) = each(%{$design{treatments}})){

				my $nd_experiment = $chado_schema->resultset('NaturalDiversity::NdExperiment')
				->create({
					nd_geolocation_id => $nd_geolocation_id,
					type_id => $treatment_nd_experiment_type_id,
				});

				#Create a project for each treatment_name
				my $project_treatment_name = $self->get_trial_name()."_".$treatment_name;
				my $treatment_project = $chado_schema->resultset('Project::Project')
				->create({
					name => $project_treatment_name,
					description => '',
				});
				$treatment_project->create_projectprops({
					$project_design_cvterm->name() => "treatment"
				});

				if ($self->get_new_treatment_has_plant_entries){
					my $rs = $chado_schema->resultset("Project::Projectprop")->find_or_create({
						type_id => $has_plants_cvterm,
						value => $self->get_new_treatment_has_plant_entries,
						project_id => $treatment_project->project_id(),
					});
				}
				if ($self->get_new_treatment_has_subplot_entries){
					my $rs = $chado_schema->resultset("Project::Projectprop")->find_or_create({
						type_id => $has_subplots_cvterm,
						value => $self->get_new_treatment_has_subplot_entries,
						project_id => $treatment_project->project_id(),
					});
				}

				$nd_experiment->create_related('nd_experiment_projects',{project_id => $treatment_project->project_id()});

				my $trial_treatment_relationship = $chado_schema->resultset("Project::ProjectRelationship")->create({
					object_project_id => $self->get_trial_id(),
					subject_project_id => $treatment_project->project_id(),
					type_id => $trial_treatment_relationship_cvterm_id,
				});

				foreach (@$stock_names){
					my $stock_id;
					if (exists($new_stock_ids_hash{$_})){
						$stock_id = $new_stock_ids_hash{$_};
					} else {
						$stock_id = $chado_schema->resultset("Stock::Stock")->find({uniquename=>$_})->stock_id();
					}
					my $treatment_experiment_link = $chado_schema->resultset("NaturalDiversity::NdExperimentStock")->create({
						nd_experiment_id => $nd_experiment->nd_experiment_id(),
						type_id => $treatment_nd_experiment_type_id,
						stock_id => $stock_id,
					});
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
