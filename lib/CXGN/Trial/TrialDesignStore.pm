package CXGN::Trial::TrialDesignStore;

=head1 NAME

CXGN::Trial::TrialDesignStore - Module to validate and store a trial's design (both genotyping and phenotyping trials)


=head1 USAGE

 my $design_store = CXGN::Trial::TrialDesignStore->new({
	bcs_schema => $c->dbic_schema("Bio::Chado::Schema"),
	design_type => 'CRD',
	design => $design_hash,
 });
 my $validate_error = $design_store->validate_design();
 if ($validate_error) {
 	print STDERR "VALIDATE ERROR: $validate_error\n";
 } else {
 	try {
		$design_store->store();
	} catch {
		print STDERR "ERROR SAVING TRIAL!: $_\n";
 	};
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
has 'design_type' => (isa => 'Str', is => 'rw', predicate => 'has_design_type', required => 1);
has 'design' => (isa => 'HashRef[HashRef[Str|ArrayRef]]|Undef', is => 'rw', predicate => 'has_design', required => 1);
has 'is_genotyping' => (isa => 'Bool', is => 'rw', required => 0, default => 0);

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
	if ($design_type ne 'genotyping_plate' && $design_type ne 'CRD' && $design_type ne 'Alpha' && $design_type && 'Augmented' && $design_type ne 'RCBD'){
		$error .= "Design type must be either: genotyping_plate, CRD, Alpha, Augmented, or RCBD";
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
	foreach my $stock (keys %design){
		foreach my $property (keys %{$design{$stock}}){
			if (!exists($allowed_properties{$property})) {
				$error .= "Property: $property not allowed! ";
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
	if (!$self->get_is_genotyping) {
		$nd_experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'field_layout', 'experiment_type')->cvterm_id();
		$stock_type_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plot', 'stock_type')->cvterm_id();
		$stock_rel_type_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plot_of', 'stock_relationship')->cvterm_id();
	} else {
		$nd_experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'genotyping_layout', 'experiment_type')->cvterm_id();
		$stock_type_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'tissue_sample', 'stock_type')->cvterm_id();
		$stock_rel_type_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'tissue_sample_of', 'stock_relationship')->cvterm_id();
	}

	my $nd_experiment_project = $chado_schema->resultset('NaturalDiversity::NdExperimentProject')->find(
		{
			'me.project_id'=>$self->get_trial_id(),
			'nd_experiment.type_id'=>$nd_experiment_type_id
		},
		{ join => 'nd_experiment'}
	);

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

	#print STDERR Dumper \%design;
	foreach my $key (sort { $a cmp $b} keys %design) {

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
		my $stock_name;
		if ($design{$key}->{stock_name}) {
			$stock_name = $design{$key}->{stock_name};
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
		} else {
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
					my $stock_relationship = $chado_schema->resultset("Stock::StockRelationship")->create({
						subject_id => $plot->stock_id,
						object_id => $plant->stock_id(),
						type_id => $plant_of->cvterm_id(),
					});
				}

				#create the stock_relationship of the accession with the plant, if it does not exist already
				if (!$stock_relationship_data{$stock_id_checked, $plant_of->cvterm_id(), $plant->stock_id()} ) {
					my $parent_stock = $chado_schema->resultset("Stock::StockRelationship")->create({
						object_id => $stock_id_checked,
						type_id => $plant_of->cvterm_id(),
						subject_id => $plant->stock_id()
					});
				}

				#link the experiment to the plant, if it is not already
				if (!$stock_experiment_data{$plant->stock_id(), $nd_experiment_project->nd_experiment_id(), $nd_experiment_type_id} ) {
					my $stock_experiment_link = $chado_schema->resultset("NaturalDiversity::NdExperimentStock")->create({
						nd_experiment_id => $nd_experiment_project->nd_experiment_id(),
						type_id => $nd_experiment_type_id,
						stock_id => $plant->stock_id(),
					});
				}
			}
		}
	}

}

1;
