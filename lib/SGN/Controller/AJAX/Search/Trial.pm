
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
 
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    
    # pre-fetch some information; more efficient
    #
    my $breeding_program_cvterm_id  = $self->get_breeding_program_cvterm_id($c);
    my $trial_folder_cvterm_id = $self->get_trial_folder_cvterm_id($c);
    my $location_cvterm_id = $c->model("Cvterm")->get_cvterm_row($schema, "project location", "project_property")->cvterm_id();
    my $year_cvterm_id = $c->model("Cvterm")->get_cvterm_row($schema, "project year", "project_property")->cvterm_id();
    my $project_type_cv_id = $schema->resultset("Cv::Cv")->find( { name => "project_type" } )->cv_id();
    my %project_types;
    my $project_type_rs = $schema->resultset("Cv::Cvterm")->search( { cv_id => $project_type_cv_id });
    while (my $row = $project_type_rs->next()) { 
	$project_types{$row->cvterm_id} = $row->name();
    }
    my %projects;
    my $project_rs = $schema->resultset("Project::Project")->search( {} );
    while (my $p = $project_rs->next()) { 
	$projects{$p->project_id} = $p->name();
    }
  
    my %parent_projects;
    my $parent_project_rs = $schema->resultset("Project::Project")
	->search( {}, {  join =>  "project_relationship_subject_projects", 
			 '+select' => [ 'project_relationship_subject_projects.object_project_id'], 
			 '+as' => [ 'parent_project_id' ] 
		  });

    while (my $row = $parent_project_rs->next()) {
	$parent_projects{$row->project_id()} = $projects{$row->get_column('parent_project_id')};
    }

    my %locations;
    my $location_rs = $schema->resultset("NaturalDiversity::NdGeolocation")->search( { } );
    while (my $row = $location_rs->next()) { 
	$locations{$row->nd_geolocation_id()} = $row->description();
    }

    # don't need these really for the simple dataTables search
    #
#    my ( $or_conditions, $and_conditions);

# ##############################
#     if ($params->{trial_name} && ($params->{trial_name} ne "all")) { 
# 	$and_conditions->{'project.name'} = { 'ilike' => '%'.$params->{trial_name}.'%' } ; 
#     }
	

#    if ($params->{location} && ($params->{location} ne "all")) {
#        my $row = $c->dbic_schema("Bio::Chado::Schema")->resultset("NaturalDiversity::NdGeolocation")->find( { description => $params->{location} } );
#        if ($row) { 
# 	   $and_conditions->{'location.value'} = { -in => [ $row->nd_geolocation_id->as_query, 'NULL' ] }; 
#        }
#    }
#     if ($params->{year} && ($params->{year} ne "all")) { 
# 	$and_conditions->{'year.value'} = { 'ilike' => $params->{year}.'%' } ;
#     }

#     if ($params->{breeding_program} && ($params->{breeding_program} ne "all")) { 
# 	$and_conditions->{'program.name'} = { 'ilike' => '%'.$params->{breeding_program}.'%' } ;
#     }

  
# ################################################

    my $projects_rs = $schema->resultset("Project::Project")
	->search( {}, { join => 'projectprops', 
			'+select' => [ 'projectprops.type_id', 'projectprops.value' ], 
			'+as' => ['projectprop_type_id', 'projectprop_value'] 
		  });

    my @result;

    # make a unique trial list using a hash and filling in auxiliary info...
    #
    my %trials = ();

    while ( my $p = $projects_rs->next() ) {
	my $project_id = $p->project_id;
	my $project_name = $p->name();

	$trials{$project_name}->{project_id} = $p->project_id();
	$trials{$project_name}->{project_description} = $p->description();

	my $type_id = $p->get_column('projectprop_type_id');
	my $value = $p->get_column('projectprop_value');

	print STDERR "READ: $project_name, $type_id, $value\n";

	if ($type_id == $trial_folder_cvterm_id) { 
	    $trials{$project_name}->{trial_folder} = "FOLDER";
	}
	if ($type_id == $location_cvterm_id) { 
	    $trials{$project_name}->{location} = $locations{$value};
	}
	if ($type_id == $year_cvterm_id) { 
	    $trials{$project_name}->{year} = $value;
	}
	
	print "$type_id corresponds to project type $project_types{$type_id}\n";
	$trials{$project_name}->{project_type} = $project_types{$type_id};

	$trials{$project_name}->{breeding_program} = $parent_projects{$project_id};
    }
    
    foreach my $t (sort(keys(%trials))) {
	
	push @result, [ 
	    "<a href=\"/breeders_toolbox/trial/$trials{$t}->{project_id}\">$t</a>", 
	    $trials{$t}->{project_description}, 
	    $trials{$t}->{breeding_program}, 
	    $trials{$t}->{year}, 
	    $trials{$t}->{location}, 
	    $trials{$t}->{project_type} 
	];
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
