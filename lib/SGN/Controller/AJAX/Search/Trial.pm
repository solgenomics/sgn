
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

sub search : Path('/ajax/search/trials') Args(0) {
    my $self = shift;
    my $c    = shift;

    my $nd_geolocation = $c->req->param('nd_geolocation');

    print STDERR "location: " . $nd_geolocation . "\n";

    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    # pre-fetch some information; more efficient
    my $breeding_program_cvterm_id = $self->get_breeding_program_cvterm_id($c);
    my $breeding_program_trial_relationship_id =
      $c->model("Cvterm")
      ->get_cvterm_row( $schema, "breeding_program_trial_relationship",
        "project_relationship" )->cvterm_id();
    my $trial_folder_cvterm_id = $self->get_trial_folder_cvterm_id($c);
    my $cross_cvterm_id =
      $c->model("Cvterm")->get_cvterm_row( $schema, "cross", "stock_type" )
      ->cvterm_id();
    my $location_cvterm_id =
      $c->model("Cvterm")
      ->get_cvterm_row( $schema, "project location", "project_property" )
      ->cvterm_id();
    my $year_cvterm_id =
      $c->model("Cvterm")
      ->get_cvterm_row( $schema, "project year", "project_property" )
      ->cvterm_id();
    my $design_cvterm_id = $c->model("Cvterm")
      ->get_cvterm_row( $schema, "design", "project_property" )->cvterm_id();
    my $project_type_cv_id =
      $schema->resultset("Cv::Cv")->find( { name => "project_type" } )->cv_id();
    my $project_type_rs = $schema->resultset("Cv::Cvterm")
      ->search( { cv_id => $project_type_cv_id } );
    my %trial_types;

    while ( my $row = $project_type_rs->next() ) {
        $trial_types{ $row->cvterm_id } = $row->name();
    }

    my $not_trials_rs = $schema->resultset("Project::Projectprop")->search(
        [
            { type_id => $breeding_program_cvterm_id },
            { type_id => $trial_folder_cvterm_id },
            { type_id => $cross_cvterm_id }
        ]
    );

    my %not_trials;
    while ( my $row = $not_trials_rs->next() ) {
        $not_trials{ $row->project_id() } = 1;
    }

    my %breeding_programs;
    my $breeding_program_rs = $schema->resultset("Project::Project")->search(
        {},
        {
            join =>
              { 'project_relationship_object_projects' => 'subject_project' },
            where => { type_id => $breeding_program_trial_relationship_id },
            select => [ 'me.name', 'subject_project.project_id' ],
            as     => [ 'breeding_program', 'trial_id' ]
        }
    );

    while ( my $row = $breeding_program_rs->next() ) {
        $breeding_programs{ $row->get_column('trial_id') } =
          $row->get_column('breeding_program');
    }

    my %folders;
    my $folder_rs = $schema->resultset("Project::Project")->search(
        {},
        {
            join =>
              { 'project_relationship_object_projects' => 'subject_project' },
            where => { type_id => $trial_folder_cvterm_id },
            select => [ 'me.name', 'me.project_id', 'subject_project.project_id' ],
            as     => [ 'folder', 'folder_id','trial_id' ]
        }
    );

    while ( my $row = $folder_rs->next() ) {
        my $folder = $row->get_column('folder');
        my $folder_id = $row->get_column('folder_id');
        $folders{ $row->get_column('trial_id') } ="<a href=\"/folder/$folder_id\">$folder</a>";
    }

    my %locations;
    my $location_rs =
      $schema->resultset("NaturalDiversity::NdGeolocation")->search( {} );

    while ( my $row = $location_rs->next() ) {
        $locations{ $row->nd_geolocation_id() } = $row->description();
    }

    my $trial_rs = $schema->resultset("Project::Project")->search(
        {},
        {
            join      => 'projectprops',
            '+select' => [ 'projectprops.type_id', 'projectprops.value' ],
            '+as'     => [ 'projectprop_type_id', 'projectprop_value' ]
        }
    );

    my @result;
    my %trials = ();

    while ( my $t = $trial_rs->next() ) {
        my $trial_id = $t->project_id();
        if ( $not_trials{$trial_id} ) { next; }
        my $trial_name = $t->name();

        $trials{$trial_name}->{trial_id}          = $t->project_id();
        $trials{$trial_name}->{trial_description} = $t->description();

        my $type_id = $t->get_column('projectprop_type_id');
        my $value   = $t->get_column('projectprop_value');

        print STDERR "READ: $trial_name, $type_id, $value\n";

        if ( $type_id == $location_cvterm_id ) {
            $trials{$trial_name}->{location} = $locations{$value};
        }
        if ( $type_id == $year_cvterm_id ) {
            $trials{$trial_name}->{year} = $value;
        }
        if ( $type_id == $design_cvterm_id ) {
            $trials{$trial_name}->{design} = $value;
        }

        print "$type_id corresponds to project type $trial_types{$type_id}\n";
        $trials{$trial_name}->{trial_type} = $trial_types{$type_id};
        $trials{$trial_name}->{breeding_program} =
          $breeding_programs{$trial_id};
        $trials{$trial_name}->{folder} = $folders{$trial_id};
    }

    foreach my $t ( sort( keys(%trials) ) ) {
        print STDERR "trial location = $trials{$t}->{location} \n";
        next
          unless ( $nd_geolocation eq 'not_provided'
            || $trials{$t}->{location} eq $nd_geolocation );
        print STDERR "matched trial location = $trials{$t}->{location} \n";

        push @result,
          [
"<a href=\"/breeders_toolbox/trial/$trials{$t}->{project_id}\">$t</a>",
            $trials{$t}->{trial_description}, $trials{$t}->{breeding_program},
            $trials{$t}->{folder},            $trials{$t}->{year},
            $trials{$t}->{location},          $trials{$t}->{trial_type},
            $trials{$t}->{design}
          ];
    }

    $c->stash->{rest} = { data => \@result };
}

sub get_project_year_cvterm_id {
    my $self = shift;
    my $c    = shift;

    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $row =
      $schema->resultset("Cv::Cvterm")->find( { name => 'project year' } );

    return $row->cvterm_id();
}

sub get_project_location_cvterm_id {
    my $self = shift;
    my $c    = shift;

    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $row =
      $schema->resultset("Cv::Cvterm")->find( { name => 'project location' } );

    return $row->cvterm_id();
}

sub get_breeding_program_cvterm_id {
    my $self   = shift;
    my $c      = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $row =
      $schema->resultset("Cv::Cvterm")->find( { name => 'breeding_program' } );

    return $row->cvterm_id();
}

sub get_trial_folder_cvterm_id {
    my $self   = shift;
    my $c      = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $row =
      $schema->resultset("Cv::Cvterm")->find( { name => 'trial_folder' } );

    return $row->cvterm_id();
}
