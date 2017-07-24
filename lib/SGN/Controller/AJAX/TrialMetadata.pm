package SGN::Controller::AJAX::TrialMetadata;

use Moose;
use Data::Dumper;
use List::Util 'max';
use Bio::Chado::Schema;
use List::Util qw | any |;
use CXGN::Trial;
use Math::Round::Var;
use List::MoreUtils qw(uniq);
use CXGN::Trial::FieldMap;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );

has 'schema' => (
		 is       => 'rw',
		 isa      => 'DBIx::Class::Schema',
		 lazy_build => 1,
		);


sub trial : Chained('/') PathPart('ajax/breeders/trial') CaptureArgs(1) {
    my $self = shift;
    my $c = shift;
    my $trial_id = shift;

    $c->stash->{trial_id} = $trial_id;
    $c->stash->{schema} =  $c->dbic_schema("Bio::Chado::Schema");
    $c->stash->{trial} = CXGN::Trial->new( { bcs_schema => $c->stash->{schema}, trial_id => $trial_id });

    if (!$c->stash->{trial}) {
	$c->stash->{rest} = { error => "The specified trial with id $trial_id does not exist" };
	return;
    }

}

=head2 delete_trial_by_file
 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:
=cut

sub delete_trial_data : Local() ActionClass('REST');

sub delete_trial_data_GET : Chained('trial') PathPart('delete') Args(1) {
    my $self = shift;
    my $c = shift;
    my $datatype = shift;

    if ($self->privileges_denied($c)) {
	$c->stash->{rest} = { error => "You have insufficient access privileges to delete trial data." };
	return;
    }

    my $error = "";

    if ($datatype eq 'phenotypes') {
	$error = $c->stash->{trial}->delete_phenotype_metadata($c->dbic_schema("CXGN::Metadata::Schema"), $c->dbic_schema("CXGN::Phenome::Schema"));
	$error .= $c->stash->{trial}->delete_phenotype_data();
    }

    elsif ($datatype eq 'layout') {
	$error = $c->stash->{trial}->delete_metadata($c->dbic_schema("CXGN::Metadata::Schema"), $c->dbic_schema("CXGN::Phenome::Schema"));
	$error = $c->stash->{trial}->delete_field_layout();
    }
    elsif ($datatype eq 'entry') {
	$error = $c->stash->{trial}->delete_project_entry();
    }
    else {
	$c->stash->{rest} = { error => "unknown delete action for $datatype" };
	return;
    }
    if ($error) {
	$c->stash->{rest} = { error => $error };
	return;
    }
    $c->stash->{rest} = { message => "Successfully deleted trial data.", success => 1 };
}

sub trial_phenotypes_fully_uploaded : Chained('trial') PathPart('phenotypes_fully_uploaded') Args(0) ActionClass('REST') {};

sub trial_phenotypes_fully_uploaded_GET   {
    my $self = shift;
    my $c = shift;
    my $trial = $c->stash->{trial};
    $c->stash->{rest} = { phenotypes_fully_uploaded => $trial->get_phenotypes_fully_uploaded() };
}

sub trial_phenotypes_fully_uploaded_POST  {
    my $self = shift;
    my $c = shift;
    my $value = $c->req->param("phenotypes_fully_uploaded");
    my $trial = $c->stash->{trial};
    eval {
        $trial->set_phenotypes_fully_uploaded($value);
    };
    if ($@) {
        $c->stash->{rest} = { error => "An error occurred setting phenotypes_fully_uploaded: $@" };
    }
    else {
        $c->stash->{rest} = { success => 1 };
    }
}

sub trial_details : Chained('trial') PathPart('details') Args(0) ActionClass('REST') {};

sub trial_details_GET   {
    my $self = shift;
    my $c = shift;

    my $trial = $c->stash->{trial};

    $c->stash->{rest} = { details => $trial->get_details() };

}

sub trial_details_POST  {
    my $self = shift;
    my $c = shift;

    my @categories = $c->req->param("categories[]");

    my $details = {};
    foreach my $category (@categories) {
      $details->{$category} = $c->req->param("details[$category]");
    }

    if (!%{$details}) {
      $c->stash->{rest} = { error => "No values were edited, so no changes could be made for this trial's details." };
      return;
    }
    else {
    print STDERR "Here are the deets: " . Dumper($details) . "\n";
    }

    #check privileges
    print STDERR " curator status = ".$c->user()->check_roles('curator')." and submitter status = ".$c->user()->check_roles('submitter')."\n";
    if (!($c->user()->check_roles('curator') || $c->user()->check_roles('submitter'))) {
      $c->stash->{rest} = { error => 'You do not have the required privileges to edit trial details, trial details can only be edited by accounts with submitter or curator privileges' };
      return;
    }

    my $trial_id = $c->stash->{trial_id};
    my $trial = $c->stash->{trial};
    my $program_object = CXGN::BreedersToolbox::Projects->new( { schema => $c->stash->{schema} });
    my $program_ref = $program_object->get_breeding_programs_by_trial($trial_id);

    my $program_array = @$program_ref[0];
    my $breeding_program_name = @$program_array[1];
    my @user_roles = $c->user->roles();
    my %has_roles = ();
    map { $has_roles{$_} = 1; } @user_roles;

    print STDERR "my user roles = @user_roles and trial breeding program = $breeding_program_name \n";

    if (!exists($has_roles{$breeding_program_name})) {
      $c->stash->{rest} = { error => "You need to be associated with breeding program $breeding_program_name to change the details of this trial." };
      return;
    }

    # set each new detail that is defined
    eval {
      if ($details->{name}) { $trial->set_name($details->{name}); }
      if ($details->{breeding_program}) { $trial->set_breeding_program($details->{breeding_program}); }
      if ($details->{location}) { $trial->set_location($details->{location}); }
      if ($details->{year}) { $trial->set_year($details->{year}); }
      if ($details->{type}) { $trial->set_project_type($details->{type}); }
      if ($details->{planting_date}) {
        if ($details->{planting_date} eq 'remove') { $trial->remove_planting_date($trial->get_planting_date()); }
        else { $trial->set_planting_date($details->{planting_date}); }
      }
      if ($details->{harvest_date}) {
        if ($details->{harvest_date} eq 'remove') { $trial->remove_harvest_date($trial->get_harvest_date()); }
        else { $trial->set_harvest_date($details->{harvest_date}); }
      }
      if ($details->{description}) { $trial->set_description($details->{description}); }
    };

    if ($@) {
	    $c->stash->{rest} = { error => "An error occurred setting the new trial details: $@" };
    }
    else {
	    $c->stash->{rest} = { success => 1 };
    }
}

sub traits_assayed : Chained('trial') PathPart('traits_assayed') Args(0) {
    my $self = shift;
    my $c = shift;
    my $stock_type = $c->req->param('stock_type');

    my @traits_assayed  = $c->stash->{trial}->get_traits_assayed($stock_type);
    $c->stash->{rest} = { traits_assayed => \@traits_assayed };
}


sub phenotype_summary : Chained('trial') PathPart('phenotypes') Args(0) {
    my $self = shift;
    my $c = shift;

    my $schema = $c->stash->{schema};
    my $round = Math::Round::Var->new(0.01);
    my $dbh = $c->dbc->dbh();
    my $trial_id = $c->stash->{trial_id};
    my $display = $c->req->param('display');
    my $select_clause_additional = '';
    my $group_by_additional = '';
    my $stock_type_id;
    my $rel_type_id;
    my $total_complete_number;
    if ($display eq 'plots') {
        $stock_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id();
        $rel_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot_of', 'stock_relationship')->cvterm_id();
        my $plots = $c->stash->{trial}->get_plots();
        $total_complete_number = scalar (@$plots);
    }
    if ($display eq 'plants') {
        $stock_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant', 'stock_type')->cvterm_id();
        $rel_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant_of', 'stock_relationship')->cvterm_id();
        my $plants = $c->stash->{trial}->get_plants();
        $total_complete_number = scalar (@$plants);
    }
    my $stocks_per_accession;
    if ($display eq 'plots_accession') {
        $stock_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id();
        $rel_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot_of', 'stock_relationship')->cvterm_id();
        $select_clause_additional = ', accession.uniquename, accession.stock_id';
        $group_by_additional = ', accession.stock_id, accession.uniquename';
        $stocks_per_accession = $c->stash->{trial}->get_plots_per_accession();
    }
    if ($display eq 'plants_accession') {
        $stock_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant', 'stock_type')->cvterm_id();
        $rel_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant_of', 'stock_relationship')->cvterm_id();
        $select_clause_additional = ', accession.uniquename, accession.stock_id';
        $group_by_additional = ', accession.stock_id, accession.uniquename';
        $stocks_per_accession = $c->stash->{trial}->get_plants_per_accession();
    }
    my $accesion_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();

    my $h = $dbh->prepare("SELECT (((cvterm.name::text || '|'::text) || db.name::text) || ':'::text) || dbxref.accession::text AS trait,
        cvterm.cvterm_id,
        count(phenotype.value),
        to_char(avg(phenotype.value::real), 'FM999990.990'),
        to_char(max(phenotype.value::real), 'FM999990.990'),
        to_char(min(phenotype.value::real), 'FM999990.990'),
        to_char(stddev(phenotype.value::real), 'FM999990.990')
        $select_clause_additional
        FROM cvterm
            JOIN phenotype ON (cvterm_id=cvalue_id)
            JOIN nd_experiment_phenotype USING(phenotype_id)
            JOIN nd_experiment_project USING(nd_experiment_id)
            JOIN nd_experiment_stock USING(nd_experiment_id)
            JOIN stock as plot USING(stock_id)
            JOIN stock_relationship on (plot.stock_id = stock_relationship.subject_id)
            JOIN stock as accession on (accession.stock_id = stock_relationship.object_id)
            JOIN dbxref ON cvterm.dbxref_id = dbxref.dbxref_id JOIN db ON dbxref.db_id = db.db_id
        WHERE project_id=?
            AND phenotype.value~?
            AND stock_relationship.type_id=?
            AND plot.type_id=?
            AND accession.type_id=?
        GROUP BY (((cvterm.name::text || '|'::text) || db.name::text) || ':'::text) || dbxref.accession::text, cvterm.cvterm_id $group_by_additional
        ORDER BY cvterm.name ASC;");

    my $numeric_regex = '^[0-9]+([,.][0-9]+)?$';
    $h->execute($c->stash->{trial_id}, $numeric_regex, $rel_type_id, $stock_type_id, $accesion_type_id);

    my @phenotype_data;

    while (my ($trait, $trait_id, $count, $average, $max, $min, $stddev, $stock_name, $stock_id) = $h->fetchrow_array()) {

        my $cv = 0;
        if ($stddev && $average != 0) {
            $cv = ($stddev /  $average) * 100;
            $cv = $round->round($cv) . '%';
        }
        if ($average) { $average = $round->round($average); }
        if ($min) { $min = $round->round($min); }
        if ($max) { $max = $round->round($max); }
        if ($stddev) { $stddev = $round->round($stddev); }

        my @return_array;
        if ($stock_name && $stock_id) {
            $total_complete_number = scalar (@{$stocks_per_accession->{$stock_id}});
            push @return_array, qq{<a href="/stock/$stock_id/view">$stock_name</a>};
        }
        my $percent_missing = '';
        if ($total_complete_number){
            $percent_missing = 100 - sprintf("%.2f", ($count/$total_complete_number)*100)."%";
        }

        push @return_array, ( qq{<a href="/cvterm/$trait_id/view">$trait</a>}, $average, $min, $max, $stddev, $cv, $count, $percent_missing, qq{<a href="#raw_data_histogram_well" onclick="trait_summary_hist_change($trait_id)"><span class="glyphicon glyphicon-stats"></span></a>} );
        push @phenotype_data, \@return_array;
    }

    $c->stash->{rest} = { data => \@phenotype_data };
}

sub trait_histogram : Chained('trial') PathPart('trait_histogram') Args(1) {
    my $self = shift;
    my $c = shift;
    my $trait_id = shift;
    my $stock_type = $c->req->param('stock_type') || 'plot';

    my @data = $c->stash->{trial}->get_phenotypes_for_trait($trait_id, $stock_type);

    $c->stash->{rest} = { data => \@data };
}

sub get_trial_folder :Chained('trial') PathPart('folder') Args(0) {
    my $self = shift;
    my $c = shift;

    if (!($c->user()->check_roles('curator') || $c->user()->check_roles('submitter'))) {
	$c->stash->{rest} = { error => 'You do not have the required privileges to edit the trial type of this trial.' };
	return;
    }

    my $project_parent = $c->stash->{trial}->get_folder();

    $c->stash->{rest} = { folder => [ $project_parent->project_id(), $project_parent->name() ] };

}

sub trial_accessions : Chained('trial') PathPart('accessions') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $trial = CXGN::Trial->new( { bcs_schema => $schema, trial_id => $c->stash->{trial_id} });

    my @data = $trial->get_accessions();

    $c->stash->{rest} = { accessions => \@data };
}

sub trial_controls : Chained('trial') PathPart('controls') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $trial = CXGN::Trial->new( { bcs_schema => $schema, trial_id => $c->stash->{trial_id} });

    my @data = $trial->get_controls();

    $c->stash->{rest} = { accessions => \@data };
}

sub controls_by_plot : Chained('trial') PathPart('controls_by_plot') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my @plot_ids = $c->req->param('plot_ids[]');

    my $trial = CXGN::Trial->new({ bcs_schema => $schema, trial_id => $c->stash->{trial_id} });

    my @data = $trial->get_controls_by_plot(\@plot_ids);

    $c->stash->{rest} = { accessions => \@data };
}

sub trial_plots : Chained('trial') PathPart('plots') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $trial = CXGN::Trial->new( { bcs_schema => $schema, trial_id => $c->stash->{trial_id} });

    my @data = $trial->get_plots();

    $c->stash->{rest} = { plots => \@data };
}

sub trial_plants : Chained('trial') PathPart('plants') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $trial = CXGN::Trial->new( { bcs_schema => $schema, trial_id => $c->stash->{trial_id} });

    my @data = $trial->get_plants();

    $c->stash->{rest} = { plants => \@data };
}

sub trial_design : Chained('trial') PathPart('design') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $layout = CXGN::Trial::TrialLayout->new({ schema => $schema, trial_id =>$c->stash->{trial_id} });

    my $design = $layout->get_design();
    my $design_type = $layout->get_design_type();
    my $plot_dimensions = $layout->get_plot_dimensions();

    my $plot_length = '';
    if ($plot_dimensions->[0]) {
	$plot_length = $plot_dimensions->[0];
    }

    my $plot_width = '';
    if ($plot_dimensions->[1]){
	$plot_width = $plot_dimensions->[1];
    }

    my $plants_per_plot = '';
    if ($plot_dimensions->[2]){
	$plants_per_plot = $plot_dimensions->[2];
    }

    my $block_numbers = $layout->get_block_numbers();
    my $number_of_blocks = '';
    if ($block_numbers) {
      $number_of_blocks = scalar(@{$block_numbers});
    }

    my $replicate_numbers = $layout->get_replicate_numbers();
    my $number_of_replicates = '';
    if ($replicate_numbers) {
      $number_of_replicates = scalar(@{$replicate_numbers});
    }

    $c->stash->{rest} = { design_type => $design_type, num_blocks => $number_of_blocks, num_reps => $number_of_replicates, plot_length => $plot_length, plot_width => $plot_width, plants_per_plot => $plants_per_plot, design => $design };
}

sub get_spatial_layout : Chained('trial') PathPart('coords') Args(0) {

    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $fieldmap = CXGN::Trial::FieldMap->new({
      bcs_schema => $schema,
      trial_id => $c->stash->{trial_id},
    });
    my $return = $fieldmap->display_fieldmap();

    $c->stash->{rest} = $return;
}

sub trial_completion_layout_section : Chained('trial') PathPart('trial_completion_layout_section') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $layout_experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'field_layout', 'experiment_type')->cvterm_id();
    my $plot_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id();
    my $plant_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant', 'stock_type')->cvterm_id();
    my $plot_number_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot number', 'stock_property')->cvterm_id();
    my $block_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'block', 'stock_property')->cvterm_id();
    my $has_plot_number_check = $schema->resultset('Stock::Stock')->search({'me.type_id'=>$plot_type_id, 'stockprops.type_id'=>$plot_number_cvterm_id, 'project.project_id'=>$c->stash->{trial_id}, 'nd_experiment.type_id'=>$layout_experiment_type_id}, {join=>['stockprops', {'nd_experiment_stocks'=>{'nd_experiment'=>{'nd_experiment_projects'=>'project'} } } ], rows=>1 });
    my $has_block_check = $schema->resultset('Stock::Stock')->search({'me.type_id'=>$plot_type_id, 'stockprops.type_id'=>$block_cvterm_id, 'project.project_id'=>$c->stash->{trial_id}, 'nd_experiment.type_id'=>$layout_experiment_type_id}, {join=>['stockprops', {'nd_experiment_stocks'=>{'nd_experiment'=>{'nd_experiment_projects'=>'project'} } } ], rows=>1 });
    my $has_layout_check = $has_plot_number_check->first && $has_block_check->first ? 1 : 0;

    my $row_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'row_number', 'stock_property')->cvterm_id();
    my $col_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'col_number', 'stock_property')->cvterm_id();
    my $has_row_check = $schema->resultset('Stock::Stock')->search({'me.type_id'=>$plot_type_id, 'stockprops.type_id'=>$row_cvterm_id, 'project.project_id'=>$c->stash->{trial_id}, 'nd_experiment.type_id'=>$layout_experiment_type_id}, {join=>['stockprops', {'nd_experiment_stocks'=>{'nd_experiment'=>{'nd_experiment_projects'=>'project'} } } ], rows=>1 });
    my $has_col_check = $schema->resultset('Stock::Stock')->search({'me.type_id'=>$plot_type_id, 'stockprops.type_id'=>$col_cvterm_id, 'project.project_id'=>$c->stash->{trial_id}, 'nd_experiment.type_id'=>$layout_experiment_type_id}, {join=>['stockprops', {'nd_experiment_stocks'=>{'nd_experiment'=>{'nd_experiment_projects'=>'project'} } } ], rows=>1 });
    my $has_physical_map_check = $has_row_check->first && $has_col_check->first ? 1 : 0;

    $c->stash->{rest} = {has_layout => $has_layout_check, has_physical_map => $has_physical_map_check};
}

sub trial_completion_phenotype_section : Chained('trial') PathPart('trial_completion_phenotype_section') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $plot_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id();
    my $plant_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant', 'stock_type')->cvterm_id();
    my $phenotyping_experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'phenotyping_experiment', 'experiment_type')->cvterm_id();
    my $has_phenotype_check = $schema->resultset('Phenotype::Phenotype')->search({'stock.type_id'=> [$plot_type_id, $plant_type_id], 'nd_experiment.type_id'=>$phenotyping_experiment_type_id, 'me.value' => { '!=' => ''}, 'project.project_id'=>$c->stash->{trial_id}}, {join=>{'nd_experiment_phenotypes'=>{'nd_experiment'=>[{'nd_experiment_stocks'=>'stock' }, {'nd_experiment_projects'=>'project'}] } }, rows=>1 });
    my $has_phenotypes = $has_phenotype_check->first ? 1 : 0;

    $c->stash->{rest} = {has_phenotypes => $has_phenotypes};
}

#sub compute_derive_traits : Path('/ajax/phenotype/delete_field_coords') Args(0) {
sub delete_field_coord : Path('/ajax/phenotype/delete_field_coords') Args(0) {
  my $self = shift;
	my $c = shift;
	my $trial_id = $c->req->param('trial_id');

  my $schema = $c->dbic_schema('Bio::Chado::Schema');

  if ($self->privileges_denied($c)) {
    $c->stash->{rest} = { error => "You have insufficient access privileges to update this map." };
    return;
  }

  my $fieldmap = CXGN::Trial::FieldMap->new({
    bcs_schema => $schema,
    trial_id => $trial_id,
  });
  my $delete_return_error = $fieldmap->delete_fieldmap();
  if ($delete_return_error) {
    $c->stash->{rest} = { error => $delete_return_error };
    return;
  }

  $c->stash->{rest} = {success => 1};
}

sub replace_trial_accession : Chained('trial') PathPart('replace_accession') Args(0) {
  my $self = shift;
  my $c = shift;
  my $schema = $c->dbic_schema('Bio::Chado::Schema');
  my $old_accession_id = $c->req->param('old_accession_id');
  my $new_accession = $c->req->param('new_accession');
  my $trial_id = $c->stash->{trial_id};

  if ($self->privileges_denied($c)) {
    $c->stash->{rest} = { error => "You have insufficient access privileges to edit this map." };
    return;
  }

  if (!$new_accession){
    $c->stash->{rest} = { error => "Provide new accession name." };
    return;
  }

  my $replace_accession_fieldmap = CXGN::Trial::FieldMap->new({
    bcs_schema => $schema,
    trial_id => $trial_id,
    old_accession_id => $old_accession_id,
    new_accession => $new_accession,
  });

  my $return_error = $replace_accession_fieldmap->update_fieldmap_precheck();
     if ($return_error) {
       $c->stash->{rest} = { error => $return_error };
       return;
     }

  my $replace_return_error = $replace_accession_fieldmap->replace_trial_accession_fieldMap();
  if ($replace_return_error) {
    $c->stash->{rest} = { error => $replace_return_error };
    return;
  }

  $c->stash->{rest} = { success => 1};
}

sub replace_plot_accession : Chained('trial') PathPart('replace_plot_accessions') Args(0) {
  my $self = shift;
  my $c = shift;
  my $schema = $c->dbic_schema('Bio::Chado::Schema');
  my $old_accession = $c->req->param('old_accession');
  my $new_accession = $c->req->param('new_accession');
  my $old_plot_id = $c->req->param('old_plot_id');
  my $trial_id = $c->stash->{trial_id};

  if ($self->privileges_denied($c)) {
    $c->stash->{rest} = { error => "You have insufficient access privileges to edit this map." };
    return;
  }

  if (!$new_accession){
    $c->stash->{rest} = { error => "Provide new accession name." };
    return;
  }

  my $replace_plot_accession_fieldmap = CXGN::Trial::FieldMap->new({
    bcs_schema => $schema,
    trial_id => $trial_id,
    new_accession => $new_accession,
    old_accession => $old_accession,
    old_plot_id => $old_plot_id,

  });

  my $return_error = $replace_plot_accession_fieldmap->update_fieldmap_precheck();
     if ($return_error) {
       $c->stash->{rest} = { error => $return_error };
       return;
     }

  print "Calling Replace Function...............\n";
  my $replace_return_error = $replace_plot_accession_fieldmap->replace_plot_accession_fieldMap();
  if ($replace_return_error) {
    $c->stash->{rest} = { error => $replace_return_error };
    return;
  }

  print "OldAccession: $old_accession, NewAcc: $new_accession, OldPlotId: $old_plot_id\n";
  $c->stash->{rest} = { success => 1};
}

sub substitute_accession : Chained('trial') PathPart('substitute_accession') Args(0) {
  my $self = shift;
	my $c = shift;
  my $schema = $c->dbic_schema('Bio::Chado::Schema');
  my $trial_id = $c->stash->{trial_id};
  my $plot_1_info = $c->req->param('plot_1_info');
  my $plot_2_info = $c->req->param('plot_2_info');

  my ($plot_1_id, $accession_1) = split /,/, $plot_1_info;
  my ($plot_2_id, $accession_2) = split /,/, $plot_2_info;

  if ($self->privileges_denied($c)) {
    $c->stash->{rest} = { error => "You have insufficient access privileges to update this map." };
    return;
  }

  if ($plot_1_id == $plot_2_id){
    $c->stash->{rest} = { error => "Choose a different plot/accession in 'select Accession 2' to perform this operation." };
    return;
  }

  my @controls;
  my @ids, $plot_1_id;
	@ids, $plot_2_id;

  my $fieldmap = CXGN::Trial::FieldMap->new({
    bcs_schema => $schema,
    trial_id => $trial_id,
    first_plot_selected => $plot_1_id,
    second_plot_selected => $plot_2_id,
    first_accession_selected => $accession_1,
    second_accession_selected => $accession_2,
  });

  my $return_error = $fieldmap->update_fieldmap_precheck();
  if ($return_error) {
    $c->stash->{rest} = { error => $return_error };
    return;
  }

  my $return_check_error = $fieldmap->substitute_accession_precheck();
  if ($return_check_error) {
    $c->stash->{rest} = { error => $return_check_error };
    return;
  }

  my $update_return_error = $fieldmap->substitute_accession_fieldmap();
  if ($update_return_error) {
    $c->stash->{rest} = { error => $update_return_error };
    return;
  }

  $c->stash->{rest} = { success => 1};
}

sub create_plant_subplots : Chained('trial') PathPart('create_subplots') Args(0) {
    my $self = shift;
    my $c = shift;
    my $plants_per_plot = $c->req->param("plants_per_plot") || 8;

    if (my $error = $self->privileges_denied($c)) {
	$c->stash->{rest} = { error => $error };
	return;
    }

    if (!$plants_per_plot || $plants_per_plot > 50) {
	$c->stash->{rest} = { error => "Plants per plot number is required and must be smaller than 50." };
	return;
    }

    my $t = CXGN::Trial->new( { bcs_schema => $c->dbic_schema("Bio::Chado::Schema"), trial_id => $c->stash->{trial_id} });

    if ($t->create_plant_entities($plants_per_plot)) {
        $c->stash->{rest} = {success => 1};
        return;
    } else {
        $c->stash->{rest} = { error => "Error creating plant entries in controller." };
    	return;
    }

}

sub privileges_denied {
    my $self = shift;
    my $c = shift;

    my $trial_id = $c->stash->{trial_id};

    if (! $c->user) { return "Login required for modifying trial."; }
    my $user_id = $c->user->get_object->get_sp_person_id();

    if ($c->user->check_roles('curator')) {
	     return 0;
    }

    my $breeding_programs = $c->stash->{trial}->get_breeding_programs();

    if ( ($c->user->check_roles('submitter')) && ( $c->user->check_roles($breeding_programs->[0]->[1]))) {
	return 0;
    }
    return "You have insufficient privileges to modify or delete this trial.";
}

# loading field coordinates

sub upload_trial_coordinates : Path('/ajax/breeders/trial/coordsupload') Args(0) {
    my $self = shift;
    my $c = shift;

    if (!$c->user()) {
    	print STDERR "User not logged in... not uploading coordinates.\n";
    	$c->stash->{rest} = {error => "You need to be logged in to upload coordinates." };
    	return;
    }

    if (!any { $_ eq "curator" || $_ eq "submitter" } ($c->user()->roles)  ) {
    	$c->stash->{rest} = {error =>  "You have insufficient privileges to add coordinates." };
    	return;
    }

    my $time = DateTime->now();
    my $user_id = $c->user()->get_object()->get_sp_person_id();
    my $user_name = $c->user()->get_object()->get_username();
    my $timestamp = $time->ymd()."_".$time->hms();
    my $subdirectory = 'trial_coords_upload';
    my $upload = $c->req->upload('trial_coordinates_uploaded_file');
    my $upload_tempfile  = $upload->tempname;
    my $upload_original_name  = $upload->filename();
    my $md5;
    my %upload_metadata;

    # Store uploaded temporary file in archive
    print STDERR "TEMP FILE: $upload_tempfile\n";
    my $uploader = CXGN::UploadFile->new({
        tempfile => $upload_tempfile,
        subdirectory => $subdirectory,
        archive_path => $c->config->{archive_path},
        archive_filename => $upload_original_name,
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $c->user()->roles
    });
    my $archived_filename_with_path = $uploader->archive();

    if (!$archived_filename_with_path) {
    	$c->stash->{rest} = {error => "Could not save file $upload_original_name in archive",};
    	return;
    }

    $md5 = $uploader->get_md5($archived_filename_with_path);
    unlink $upload_tempfile;

   # open file and remove return of line
    open(my $F, "<", $archived_filename_with_path) || die "Can't open archive file $archived_filename_with_path";
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $header = <$F>;
    while (<$F>) {
    	chomp;
    	$_ =~ s/\r//g;
    	my ($plot,$row,$col) = split /\t/ ;
    	my $rs = $schema->resultset("Stock::Stock")->search({uniquename=> $plot });
    	if ($rs->count()== 1) {
      	my $r =  $rs->first();
      	print STDERR "The plots $plot was found.\n Loading row $row col $col\n";
      	$r->create_stockprops({row_number => $row, col_number => $col}, {autocreate => 1});
      }
      else {
      	print STDERR "WARNING! $plot was not found in the database.\n";
      }
    }

    $c->stash->{rest} = {success => 1};
}

1;
