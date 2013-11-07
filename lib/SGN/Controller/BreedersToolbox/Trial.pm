
package SGN::Controller::BreedersToolbox::Trial;

use Moose;
use CXGN::Trial::TrialLayout;
use CXGN::BreedersToolbox::Projects;

BEGIN { extends 'Catalyst::Controller'; }


sub trial_info : Path('/breeders_toolbox/trial') Args(1) { 
    my $self = shift;
    my $c = shift;
    my $trial_id = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $trial_layout = CXGN::Trial::TrialLayout->new({schema => $schema, trial_id => $trial_id} );
    my $program_object = CXGN::BreedersToolbox::Projects->new( { schema => $schema });
    my $breeding_program = $program_object->get_breeding_program_with_trial($trial_id);
    my $trial_name =  $trial_layout->get_trial_name();
    my $trial_description =  $trial_layout->get_trial_description();
    my $trial_year =  $trial_layout->get_trial_year();
    my $design_type = $trial_layout->get_design_type();
    my $plot_names_ref = $trial_layout->get_plot_names();
    my $accession_names_ref = $trial_layout->get_accession_names();
    my $control_names_ref = $trial_layout->get_control_names();
    my $block_numbers = $trial_layout->get_block_numbers();
    my $replicate_numbers = $trial_layout->get_replicate_numbers();


    my @plot_names;
    if ($plot_names_ref) {
      @plot_names = @{$trial_layout->get_plot_names()};
    }

    $c->stash->{design_type} = $design_type;
    $c->stash->{accession_names} = $accession_names_ref;
    $c->stash->{control_names} = $control_names_ref;
    $c->stash->{plot_names} = $plot_names_ref;
    $c->stash->{design_type} = $design_type;
    $c->stash->{trial_description} = $trial_description;
    $c->stash->{trial_id} = $trial_id;
    my $number_of_blocks;
    if ($block_numbers) {
      $number_of_blocks = scalar(@{$block_numbers});
    }
    $c->stash->{number_of_blocks} = $number_of_blocks;
    my $number_of_replicates;
    if ($replicate_numbers) {
      $number_of_replicates = scalar(@{$replicate_numbers});
    }
    $c->stash->{number_of_replicates} = $number_of_replicates;

    if (!$c->user()) { 
	$c->stash->{template} = '/generic_message.mas';
	$c->stash->{message}  = 'You must be logged in to access this page.';
	return;
    }
    my $dbh = $c->dbc->dbh();
    
    my $h = $dbh->prepare("SELECT project.name FROM project WHERE project_id=?");
    $h->execute($trial_id);

    my ($name) = $h->fetchrow_array();

    $c->stash->{trial_name} = $name;

    $h = $dbh->prepare("SELECT distinct(nd_geolocation.nd_geolocation_id), nd_geolocation.description, count(*) FROM nd_geolocation JOIN nd_experiment USING(nd_geolocation_id) JOIN nd_experiment_project USING (nd_experiment_id) JOIN project USING (project_id) WHERE project_id=? GROUP BY nd_geolocation_id, nd_geolocation.description");
    $h->execute($trial_id);

    my @location_data = ();
    while (my ($id, $desc, $count) = $h->fetchrow_array()) { 
	push @location_data, [$id, $desc, $count];
    }		       

    $c->stash->{location_data} = \@location_data;

    $h = $dbh->prepare("SELECT distinct(cvterm.name), count(*) FROM cvterm JOIN phenotype ON (cvterm_id=cvalue_id) JOIN nd_experiment_phenotype USING(phenotype_id) JOIN nd_experiment_project USING(nd_experiment_id) WHERE project_id=? GROUP BY cvterm.name");

    $h->execute($trial_id);

    my @phenotype_data;
    while (my ($trait, $count) = $h->fetchrow_array()) { 
	push @phenotype_data, [$trait, $count];
    }
    $c->stash->{phenotype_data} = \@phenotype_data;

    $h = $dbh->prepare("SELECT distinct(projectprop.value) FROM projectprop WHERE project_id=? AND type_id=(SELECT cvterm_id FROM cvterm WHERE name='project year')");
    $h->execute($trial_id);

    my @years;
    while (my ($year) = $h->fetchrow_array()) { 
	push @years, $year;
    }
    
    $c->stash->{breeding_program} = $breeding_program;

    $c->stash->{years} = \@years;

    $c->stash->{plot_data} = [];

    $c->stash->{template} = '/breeders_toolbox/trial.mas';
}


1;
