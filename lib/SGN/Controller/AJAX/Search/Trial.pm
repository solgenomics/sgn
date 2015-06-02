
package SGN::Controller::AJAX::Search::Trial;

use Moose;
use Data::Dumper;

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
 
    my $project_year_cvterm_id = $self->get_project_year_cvterm_id($c);
    my $project_location_cvterm_id = $self->get_project_location_cvterm_id($c);

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    
    my $project_type_cv_id = $schema->resultset("Cv::Cv")->search( { name => 'project_type' })->first()->cv_id();

    my $trial_name_condition;
    
    my @conditions;
    my @bind_values;

    # get all locations
    #
    my $loc_rs = $schema->resultset("NaturalDiversity::NdGeolocation")->search();
    my %locations = ();
    while (my $row = $loc_rs->next()) { 
	$locations{ $row->nd_geolocation_id() } = $row->description();
    }

    my $type_rs = $schema->resultset("Cv::Cvterm")->search({ cv_id => $project_type_cv_id });
    my %project_types = ();
    while (my $row = $type_rs->next()) { 
    	$project_types{$row->cvterm_id()} = $project_types{$row->name()};
    }
    my $project_types = join ",", keys(%project_types);

    if ($params->{trial_name} && ($params->{trial_name} ne "all")) { 
	push @conditions, "project.name ilike ?";
	push @bind_values, '%'.$params->{trial_name}."%";
    }
   if ($params->{location} && ($params->{location} ne "all")) {
       my $row = $c->dbic_schema("Bio::Chado::Schema")->resultset("NaturalDiversity::NdGeolocation")->find( { description => $params->{location} } );
       if ($row) { 
	   push @conditions, " (location.value = ? OR location.value IS NULL) ";
	   push @bind_values, $row->nd_geolocation_id();
       }
   }
    if ($params->{year} && ($params->{year} ne "all")) { 
	push @conditions, " (year.value ilike ? OR year.value IS NULL) ";
	push @bind_values, $params->{year}.'%';
    }
    if ($params->{breeding_program} && ($params->{breeding_program} ne "all")) { 
	push @conditions, " (program.name ilike ? OR program.name IS NULL) ";
	push @bind_values, $params->{breeding_program};
    }

    my $select_clause = "SELECT distinct(project.project_id), project.name, project.description, program.name, year.value, location.value, type_cvterm.name ";

    my $count_clause = "SELECT count(distinct(project.project_id)) ";

    my $from_clause = " FROM project LEFT JOIN projectprop AS year ON (project.project_id = year.project_id) LEFT JOIN projectprop AS location ON (project.project_id = location.project_id) LEFT JOIN project_relationship ON (project.project_id = project_relationship.subject_project_id) LEFT JOIN project as program ON (project_relationship.object_project_id=program.project_id) LEFT JOIN projectprop as project_type ON (project.project_id=project_type.project_id) LEFT JOIN cvterm AS type_cvterm ON (project_type.type_id=type_cvterm.cvterm_id) WHERE (year.type_id=$project_year_cvterm_id OR year.type_id IS NULL) and (location.type_id=$project_location_cvterm_id OR location.type_id IS NULL) and (type_cvterm.cvterm_id in ($project_types) OR type_cvterm.cvterm_id IS NULL) ";

    my $where_clause = " AND ". join (" AND ", @conditions) if (@conditions);

    my $order_clause = " ORDER BY year.value desc, program.name, project.name ";

    my $q .= $count_clause . $from_clause . $where_clause;

    my $offset = ""; # " LIMIT ".$params->{page_size}. " OFFSET ".(($params->{page}-1) * $params->{page_size}) ;

    print STDERR "QUERY: $q\n";
    
    my $h = $c->dbc->dbh->prepare($q);
    $h->execute(@bind_values);

    my ($total) = $h->fetchrow_array();

    print STDERR "Total matches: $total\n";

    $q = $select_clause . $from_clause . $where_clause . $order_clause . $offset;

    print STDERR "QUERY: $q\n";

    $h = $c->dbc->dbh->prepare($q);

    $h->execute(@bind_values);

    my @result;
    while (my ($project_id, $project_name, $project_description, $program, $year, $location_id, $project_type) = $h->fetchrow_array()) { 
	push @result, [ "<a href=\"/breeders_toolbox/trial/$project_id\">$project_name</a>", $project_description, $program, $year, $locations{$location_id}, $project_type ];
    }

    print STDERR Dumper(\@result);
#    $c->stash->{rest} =  { 
#	trials => \@result,
#	total_count => $total,
#    };

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
