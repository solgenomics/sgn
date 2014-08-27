
package SGN::Controller::AJAX::Search::Trial;

use Moose;

BEGIN { extends 'Catalyst::Controller::REST'; }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );

sub search :Path('/ajax/search/trial') Args(0) { 
    my $self = shift;
    my $c = shift;

    my $params = $c->req->params();

    my $trial = $c->dbic_schema("Bio::Chado::Schema")->resultset("Project::Project");

    if ($params->{location}) { 
	$trial->search_related("NaturalDiversity::NdExperimentProject")->search_related("NaturalDiversity::NdExperiment")->search_related("NaturalDiversity::NdLocation", { description => $params->{location} });
    }
    
    if ($params->{year}) { 
	$trial->search_related("Project::Projectprop", { value => $params->{year} });
    }
    
    if ($params->{breeding_program}) { 
	$trial->search_related("Project::Projectrelationship");
    }

    if ($params->{trial_name}) { 
    }
}
