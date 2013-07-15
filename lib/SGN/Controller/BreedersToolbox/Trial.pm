
package SGN::Controller::BreedersToolbox::Trial;

use Moose;
use CXGN::Trial::TrialLayout;

BEGIN { extends 'Catalyst::Controller'; }


sub trial_info : Path('/breeders_toolbox/trial') Args(1) { 
    my $self = shift;
    my $c = shift;
    my $trial_id = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $trial_layout = CXGN::Trial::TrialLayout->new({schema => $schema, trial_id => $trial_id} );
    my $trial_name =  $trial_layout->get_trial_name();
    my $trial_description =  $trial_layout->get_trial_description();
    my $trial_year =  $trial_layout->get_trial_year();
    my $design_type = $trial_layout->get_design_type();
    my $plot_names_ref = $trial_layout->get_plot_names();
    my @plot_names;
    if ($plot_names_ref) {
      @plot_names = @{$trial_layout->get_plot_names()};
    }
    print "first plot: ".$plot_names[0]."\n";

    print STDERR "\n\nTrial name: $trial_name\nTrial description: $trial_description\nTrial year: $trial_year\nDesign type: $design_type\n";
    my $testing = $trial_layout->get_plot_names();
    
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
    

    $c->stash->{years} = \@years;

    $c->stash->{plot_data} = [];

    $c->stash->{template} = '/breeders_toolbox/trial.mas';
}


1;
