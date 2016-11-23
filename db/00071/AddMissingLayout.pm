#!/usr/bin/env perl


=head1 NAME

 AddMissingLayout.pm

=head1 SYNOPSIS

mx-run ThisPackageName [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION
This patch add missing stockprops and uses the trialcreate object to add layouts for trials without layout in the database.
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

 Alex Ogbonna<aco46@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddMissingLayout;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;
use Bio::Chado::Schema;
use SGN::Model::Cvterm;
use CXGN::BreedersToolbox::Projects;
use Data::Dumper;
use CXGN::Trial;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;
use CXGN::Stock::StockLookup;
use CXGN::Location::LocationLookup;
use CXGN::People::Person;

extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch add missing stockprops and uses the trialcreate object to add layouts for trials without layouts in the database.

has '+prereq' => (
	default => sub {
        [],
    },

  );


	sub patch {
	    my $self=shift;

	    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

	    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

	    print STDOUT "\nExecuting the SQL commands.\n";

	    my $chado_schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );
			my $dbh = $self->dbh->clone;
			my $program_object = CXGN::BreedersToolbox::Projects->new( { schema => $chado_schema });
			my %design;
			my $plotNumber;
			my $accession;

			my $coderef = sub {

				my $q = "SELECT stock_id, stock.name FROM project join projectprop USING (project_id) join nd_experiment_project using(project_id) join nd_experiment_stock using(nd_experiment_id) join stock using(stock_id) WHERE projectprop.type_id IS DISTINCT FROM (SELECT cvterm_id from cvterm where cvterm.name = 'breeding_program') AND projectprop.type_id IS DISTINCT FROM (SELECT cvterm_id from cvterm where cvterm.name = 'trial_folder') AND stock_id NOT IN (select distinct stock_id from stockprop) group by 1,2";
				my $h = $self->dbh->prepare($q);
				$h->execute();

				while (my ($id, $name) = $h->fetchrow_array()) {

					my $r = $chado_schema->resultset("Stock::Stock")->search({stock_id=> $id })->first();

					if (my ($plot) = $name =~ m/plot:([\d]+)_/) { #add plot_number
						print STDERR "Matched plot number $plot in plot $name\n";
						$r->create_stockprops({'plot number' => $plot}, {autocreate => 1});
					}

					if (my ($block) = $name =~ m/replicate:([\d]+)_/) { # add block_number
						print STDERR "Matched replicate number $block in plot $name as block number\n";
						$r->create_stockprops({block => $block}, {autocreate => 1});
					}

				}
			};

	    try {
	        $chado_schema->txn_do($coderef);

	    } catch {
	        die "Load failed! " . $_ .  "\n" ;
	    };

			my $design_cvterm_id = $chado_schema->resultset("Cv::Cvterm")->search( {name => 'design' }, )->first->cvterm_id;

			my $q_9 = "select trial.name, trial.project_id from project breeding_program join project_relationship on(breeding_program.project_id = project_relationship.object_project_id) join project trial on(trial.project_id = project_relationship.subject_project_id) left join projectprop on(projectprop.project_id = trial.project_id AND projectprop.type_id IN (select cvterm_id from cvterm where name = 'trial_folder' OR name = 'cross')) where projectprop.project_id IS NULL AND trial.project_id NOT IN (select trial.project_id from project trial join nd_experiment_project on(trial.project_id = nd_experiment_project.project_id) join nd_experiment using(nd_experiment_id) where nd_experiment.type_id IN (select cvterm_id from cvterm where name = 'field_layout' OR name = 'genotyping_layout') group by 1) group by 1,2";
			my $h_9 = $self->dbh->prepare($q_9);
			$h_9->execute();
			while (my($project_name,$project_id) = $h_9->fetchrow_array()) {

				my $set_design = $chado_schema->resultset('Project::Projectprop')->find_or_create(
				{
					project_id => $project_id,
					type_id => $design_cvterm_id,
					value => 'RCBD'
				});

			  my $trials = CXGN::Trial->new({bcs_schema=>$chado_schema, trial_id=>$project_id});

			  my $accessions = $trials->get_accessions();
			  print STDERR Dumper($accessions);

			  my $design1 = $trials->get_design_type();
			  print STDERR Dumper($design1);

			  my $location = $trials->get_location();
			  print STDERR Dumper($location);
				my $trial_location = @{$location}[1];
				print "LOCATION FOR THIS TRIAL: $trial_location\n";

			  my $trial_desc = $trials->get_description();
			  print STDERR Dumper($trial_desc);

			  my $trial_year = $trials->get_year();
			  print STDERR Dumper($trial_year);

				my $user_name = $self->username;

			  print "...printing project ID:  $project_id\n";
			  my $breeding_program = $program_object->get_breeding_programs_by_trial($project_id);
			  print STDERR Dumper($breeding_program);
				my $program = @{$breeding_program}[0]->[1];

				print "BREEDING PROGRAM FOR THIS TRIAL: $program\n";

					my $q_2 = "select stock_id,uniquename from stock join nd_experiment_stock using(stock_id) join nd_experiment_project using (nd_experiment_id) join project using(project_id) where project.name=?";
					my $h_2 = $self->dbh->prepare($q_2);
					$h_2->execute($project_name);

					while (my ($stock_id, $stock_name) = $h_2->fetchrow_array()) {

						my $q_3 = "select uniquename from stock join stock_relationship on stock_id=stock_relationship_id where subject_id=? and stock.type_id= (select cvterm_id from cv join cvterm using(cv_id) where cvterm.name='accession')";
						my $h_3 = $self->dbh->prepare($q_3);
						$h_3->execute($stock_id);

						while ($accession = $h_3->fetchrow_array()){

							my $q_5 = "select value from stockprop join cvterm on cvterm_id=type_id join cv using(cv_id) where cv.name='stock_property' and cvterm.name='plot number' and stock_id=? ";
							my $h_5 = $self->dbh->prepare($q_5);
							$h_5->execute($stock_id);

							while ($plotNumber = $h_5->fetchrow_array()) {

								my $q_4 = "select cvterm.name, value from stockprop join cvterm on cvterm_id=type_id join cv using(cv_id) where cv.name='stock_property' and stock_id=?";
								my $h_4 = $self->dbh->prepare($q_4);
								$h_4->execute($stock_id);

								while (my ($field_info_name,$value) = $h_4->fetchrow_array()) {

									$design{$plotNumber}->{$field_info_name} = $value;
									$design{$plotNumber}->{stock_name} = $accession;
									$design{$plotNumber}->{plot_name} = $stock_name;
									$design{$plotNumber}->{is_a_control} = 0;

								}
						  }
						}

					}

					my $q_6 = "select nd_experiment_id from nd_experiment_project where  project_id=? limit 1";
					my $h_6 = $self->dbh->prepare($q_6);
					$h_6->execute($project_id);

					while (my ($nd_experiment_id) = $h_6->fetchrow_array()) {

							my $q_7 = "update nd_experiment_stock set nd_experiment_id=? from nd_experiment_project  where nd_experiment_stock.nd_experiment_id=nd_experiment_project.nd_experiment_id and project_id=?";
							my $h_7 = $self->dbh->prepare($q_7);
							$h_7->execute($nd_experiment_id,$project_id);

							my $q_8 = "delete from nd_experiment where nd_experiment_id IN ( select nd_experiment_id from nd_experiment_project where nd_experiment_project_id !=? and project_id=?)";
							my $h_8 = $self->dbh->prepare($q_8);
							$h_8->execute($nd_experiment_id,$project_id);

					}
				print STDERR Dumper(\%design);

			  # my $layout = CXGN::Trial::TrialLayout->new({
			  #   schema => $schema,
			  #   trial_id => $project_id
			  # });
				#
			  # my $design = $layout-> get_design();
				#
			  # print STDERR Dumper($design);

				print STDERR "**trying to save $project_name trial \n\n";

				my $owner_sp_person_id;
				$owner_sp_person_id = CXGN::People::Person->get_person_by_username($dbh, $user_name); #add person id as an option.
				if (!$owner_sp_person_id) {
					print STDERR "Can't create trial: User/owner not found\n";
					die "no owner $user_name" ;
				}

				#print STDERR "Check 4.3: ".localtime();

				my $geolocation;
				my $geolocation_lookup = CXGN::Location::LocationLookup->new(schema => $chado_schema);
				$geolocation_lookup->set_location_name($trial_location);
				$geolocation = $geolocation_lookup->get_geolocation();
				if (!$geolocation) {
					print STDERR "Can't create trial: Location not found\n";
					die "no geolocation" ;
				}

				#print STDERR "Check 4.4: ".localtime();

				my $field_layout_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'field_layout', 'experiment_type');
				my $accession_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'accession', 'stock_type');
				my $plot_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plot', 'stock_type');
				my $plant_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plant', 'stock_type');
				my $plot_of = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plot_of', 'stock_relationship');
				my $plant_of = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plant_of', 'stock_relationship');
				my $sample_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'tissue_sample', 'stock_type');
				my $sample_of = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'tissue_sample_of', 'stock_relationship');
				my $genotyping_layout_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'genotyping_layout', 'experiment_type');
				my $plant_index_number_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plant_index_number', 'stock_property')->cvterm_id();

				my $project = $chado_schema->resultset('Project::Project')
				->find_or_create({
					name => $project_name,
					description => $trial_desc,
				});

				my $field_layout_experiment = $chado_schema->resultset('NaturalDiversity::NdExperiment')
				->create({
					nd_geolocation_id => $geolocation->nd_geolocation_id(),
					type_id => $field_layout_cvterm->cvterm_id(),
				});

				my $t = CXGN::Trial->new( { bcs_schema => $chado_schema, trial_id => $project->project_id() } );
				$t->set_location($geolocation->nd_geolocation_id()); # set location also as a project prop

				my $design_type = $design1;

				#link to the project
				$field_layout_experiment->find_or_create_related('nd_experiment_projects',{project_id => $project->project_id()});

				#print STDERR "Check 4.7: ".localtime();

				$project->create_projectprops( { 'project year' => $trial_year,'design' => $design1}, {autocreate=>1});

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

					#print STDERR "Check 01: ".localtime();

					my $plot_name;
					if ($design{$key}->{plot_name}) {
						$plot_name = $design{$key}->{plot_name};
					}
					my $plot_number;
					if ($design{$key}->{plot_number}) {
						$plot_number = $design{$key}->{plot_number};
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
							type_id => $plot_cvterm->cvterm_id,
						});
						if ($rep_number) {
							$plot->create_stockprops({'replicate' => $rep_number}, {autocreate => 1} );
						}
						if ($block_number) {
							$plot->create_stockprops({'block' => $block_number}, {autocreate => 1} );
						}
						if ($plot_number) {
							$plot->create_stockprops({'plot number' => $plot_number}, {autocreate => 1});
						}
						else {
							$plot->create_stockprops({'plot number' => $key}, {autocreate => 1});
						}

						if ($is_a_control) {
							$plot->create_stockprops({'is a control' => $is_a_control}, {autocreate => 1} );
						}
						if ($design{$key}->{'range_number'}) {
							$plot->create_stockprops({'range' => $key}, {autocreate => 1});
						}
						if ($row_number) {
							$plot->create_stockprops({'row_number' => $row_number}, {autocreate => 1} );
						}
						if ($col_number) {
							$plot->create_stockprops({'col_number' => $col_number}, {autocreate => 1} );
						}

						#create the stock_relationship of the accession with the plot, if it does not exist already
						if (!$stock_relationship_data{$stock_id_checked, $plot_of->cvterm_id(), $plot->stock_id()} ) {
							my $parent_stock = $chado_schema->resultset("Stock::StockRelationship")->create({
								object_id => $stock_id_checked,
								type_id => $plot_of->cvterm_id(),
								subject_id => $plot->stock_id()
							});
						}

						#link the experiment to the plot, if it is not already
						if (!$stock_experiment_data{$plot->stock_id(), $field_layout_experiment->nd_experiment_id(), $field_layout_cvterm->cvterm_id()} ) {
							my $stock_experiment_link = $chado_schema->resultset("NaturalDiversity::NdExperimentStock")->create({
								nd_experiment_id => $field_layout_experiment->nd_experiment_id(),
								type_id => $field_layout_cvterm->cvterm_id(),
								stock_id => $plot->stock_id(),
							});
						}
					}

				}

			}

	    print "You're done!\n";
	}


	####
	1; #
	####
