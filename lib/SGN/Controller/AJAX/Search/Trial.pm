
package SGN::Controller::AJAX::Search::Trial;

use Moose;
use Data::Dumper;
use CXGN::Trial;

BEGIN { extends 'Catalyst::Controller::REST'; }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );

sub search :Path('/ajax/search/trials') Args(0) { 
    my $self = shift;
    my $c = shift;

    my $params = $c->req->params();

    $params->{page_size} = 20 if (! $params->{page_size});
    $params->{page} = 1 if (! $params->{page});
 
    
    my $breeding_program_cvterm_id  = $self->get_breeding_program_cvterm_id($c);
    my $trial_folder_cvterm_id = $self->get_trial_folder_cvterm_id($c);
    
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    
    #don't need these really for the simple dataTables search
    my ( $or_conditions, $and_conditions);

##############################
    if ($params->{trial_name} && ($params->{trial_name} ne "all")) { 
	$and_conditions->{'project.name'} = { 'ilike' => '%'.$params->{trial_name}.'%' } ; 
    }
	

   if ($params->{location} && ($params->{location} ne "all")) {
       my $row = $c->dbic_schema("Bio::Chado::Schema")->resultset("NaturalDiversity::NdGeolocation")->find( { description => $params->{location} } );
       if ($row) { 
	   $and_conditions->{'location.value'} = { -in => [ $row->nd_geolocation_id->as_query, 'NULL' ] }; 
       }
   }
    if ($params->{year} && ($params->{year} ne "all")) { 
	$and_conditions->{'year.value'} = { 'ilike' => $params->{year}.'%' } ;
    }

    if ($params->{breeding_program} && ($params->{breeding_program} ne "all")) { 
	$and_conditions->{'program.name'} = { 'ilike' => '%'.$params->{breeding_program}.'%' } ;
    }

  
################################################

    my $projects_rs = $c->dbic_schema("Bio::Chado::Schema")->resultset("Project::Projectprop")->search(
	{ 'me.type_id' => { 'not_in'  => [ $breeding_program_cvterm_id,$trial_folder_cvterm_id ]}})->search_related('project');

    
    my @result;
    while ( my $p = $projects_rs->next() ) {
	my $project_id = $p->project_id;
	

	my $project_name = $p->name;
	my $project_description = $p->description;
	my $trial = CXGN::Trial->new( { bcs_schema => $schema, trial_id => $project_id } );
	
	my $program = $trial->get_breeding_program;
	my $year  = $trial->get_year;
	my $location_ref = $trial->get_location;
	my $location = $location_ref->[1];
	my $project_type_ref = $trial->get_project_type;
	my $project_type = $project_type_ref->[1];
	
	push @result, [ "<a href=\"/breeders_toolbox/trial/$project_id\">$project_name</a>", $project_description, $program, $year, $location, $project_type ];

    }

    $c->stash->{rest} = { data => \@result };

}

sub get_project_year_cvterm_id { 
    my $self = shift;
    my $c = shift;
    
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $row = $schema->resultset("Cv::Cvterm")->find( { name => 'project year' });

    return $row->cvterm_id();
}

sub get_project_location_cvterm_id { 
   my $self = shift;
    my $c = shift;
    
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $row = $schema->resultset("Cv::Cvterm")->find( { name => 'project location' });

    return $row->cvterm_id();
}

sub get_breeding_program_cvterm_id { 
   my $self = shift;
   my $c = shift;
   my $schema = $c->dbic_schema("Bio::Chado::Schema");
   my $row = $schema->resultset("Cv::Cvterm")->find( { name => 'breeding_program' });
   
   return $row->cvterm_id();
}


sub get_trial_folder_cvterm_id { 
   my $self = shift;
   my $c = shift;
   my $schema = $c->dbic_schema("Bio::Chado::Schema");
   my $row = $schema->resultset("Cv::Cvterm")->find( { name => 'trial_folder' });
   
   return $row->cvterm_id();
}
