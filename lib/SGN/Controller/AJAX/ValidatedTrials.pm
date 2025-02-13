
package SGN::Controller::AJAX::ValidatedTrials;

use Moose;

use Data::Dumper;
use File::Slurp;
use File::Spec qw | catfile |;
use File::Path qw(rmtree);
use JSON::Any;
use File::Basename qw | basename |;
use DateTime;
use Bio::Chado::Schema;
use CXGN::Dataset::File;
use CXGN::Phenotypes::File;
use CXGN::Phenotypes::PhenotypeMatrix;
use SGN::Controller::AJAX::Dataset;
use CXGN::BreedersToolbox::Projects;
use JSON;


BEGIN { extends 'Catalyst::Controller::REST' };

__PACKAGE__->config(
    default => 'application/json',
    stash_key => 'rest',
    map => { 'application/json' => 'JSON' },
   );



sub grab_data :Path('/ajax/validatedtrials/grabdata') Args(0) {
    my $self = shift;
    my $c = shift;
    my $dbh = $c->dbc->dbh();
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    

    my $trials_sql = qq{
        SELECT project."name", 
            nd_geolocation.description as location,
            validated_prop.value AS trait_name
        FROM project
        JOIN projectprop AS validated_prop ON validated_prop.project_id = project.project_id
        JOIN projectprop AS location_prop ON location_prop.project_id = project.project_id
        JOIN nd_geolocation ON nd_geolocation.nd_geolocation_id = location_prop.value::integer
        WHERE validated_prop.type_id = (SELECT cvterm_id FROM cvterm WHERE name = 'validated_phenotype')
          AND location_prop.type_id = (SELECT cvterm_id FROM cvterm WHERE name = 'project location')
         GROUP BY project."name",location, trait_name;
    };

    my @validated_projects;
    eval {
        # Prepare and execute the query
        my $sth_trial = $dbh->prepare($trials_sql);
        $sth_trial->execute();

        # Collect project names from the query result
        while (my ($project_name, $project_location, $validated_trait) = $sth_trial->fetchrow_array) {
            # Split the validated_trait into two parts using '|' as the separator
            my ($trait, $username) = split(/\|/, $validated_trait, 2);

            # Store each row's data in a hash reference
            my $project_data = {
                name => $project_name,
                project_location => $project_location,
                validated_trait => $trait,  # First part
                username => $username,     # Second part
            };

            # Push the hash reference into the array
            push @validated_projects, $project_data;
        }
        
        # print STDERR Dumper \@validated_projects;

    };

    my $json = JSON->new;
    $c->stash->{rest} = { data => \@validated_projects };

    # Explicitly encode the response as JSON
    my $encoded_response = $json->encode({ data => \@validated_projects });
    $c->response->body($encoded_response);

    if ($@) {
        $c->response->body("Failed to search data: $@");
            return;
    }
}

sub get_coordinate :Path('/ajax/validatedtrials/getcoordinates') Args(0) {
    
    my ($self, $c) = @_;
    
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $dbh = $c->dbc->dbh();
    

    # Parse the input JSON to get the list of location names
    my $locations_json = $c->req->param('locNames');
    my $location_names = decode_json($locations_json);

    # Escape the location names for SQL query
    my $placeholders = join(", ", ("?") x @$location_names);

    # Prepare and execute the SQL query
    my $sql = "
        SELECT DISTINCT p.name, p.project_id, ng.latitude, ng.longitude
        FROM project p
        JOIN nd_experiment_project nep ON nep.project_id = p.project_id
        JOIN nd_experiment ne ON ne.nd_experiment_id = nep.nd_experiment_id
        JOIN nd_geolocation ng ON ng.nd_geolocation_id = ne.nd_geolocation_id
        WHERE p.name IN ($placeholders)
    ";
    
    
    eval{
        my $sth = $dbh->prepare($sql);
        $sth->execute(@{$location_names});
        
        my @locations_with_coordinates;
        while (my ($name, $project_id, $latitude, $longitude) = $sth->fetchrow_array) {
            push @locations_with_coordinates, { name => $name, trial_id => $project_id, latitude => $latitude, longitude => $longitude };
        }
        # Return the results as JSON
        $c->res->content_type('application/json');
        $c->res->body(encode_json(\@locations_with_coordinates));
    };

    if ($@) {
        $c->res->status(500);
        $c->res->body(encode_json({ error => "Database error: $_" }));
    };

}

sub get_phenotype :Path('/ajax/validatedtrials/getphenotype') Args(0){

    my ($self, $c) = @_;
    
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $dbh = $c->dbc->dbh();

    # Parse the input JSON to get the list of trial and trait pairs
    my $projects_json = $c->req->param('projectTrait');
    my $projects_names = decode_json($projects_json);

    # Array to hold final results
    my @data;

    foreach my $project (@$projects_names) {
        my $trial_name = $project->{name};             
        my $trait_name = $project->{validated_trait};

        # Skip if either trial or trait is missing
        next unless $trial_name && $trait_name;

        # Fetch phenotype data for this trial–trait pair, excluding outliers
        my $sql_phenotypes = "
            select p.name as location_name, s.uniquename as plot_name, s2.uniquename as accession, cvterm.name as trait, phenotype.value 
            from phenotype 
            join nd_experiment_phenotype nep ON nep.phenotype_id = phenotype.phenotype_id 
            join nd_experiment_project nep2 on nep2.nd_experiment_id = nep.nd_experiment_id
            join nd_experiment_stock nes on nes.nd_experiment_id = nep.nd_experiment_id
            join phenotype p2 ON p2.phenotype_id = nep.phenotype_id 
            join project p on p.project_id = nep2.project_id
            join cvterm on p2.cvalue_id = cvterm.cvterm_id 
            join stock s on s.stock_id = nes.stock_id
            join stock_relationship sr on sr.subject_id = nes.stock_id
            join stock s2 on s2.stock_id = sr.object_id 
            where p.name = ?
            and cvterm.name = ?
            and phenotype.phenotype_id not in ( select phenotype_id from phenotypeprop p3 WHERE p3.type_id = ( select cvterm_id from cvterm where name = 'phenotype_outlier'));
        ";

        eval {
            my $sth = $dbh->prepare($sql_phenotypes);
            $sth->execute($trial_name, $trait_name);

            while (my ($location, $plot, $accession, $trait, $value) = $sth->fetchrow_array) {
                push @data, {
                    trial => $location,
                    plot => $plot,
                    accession => $accession,
                    trait => $trait,
                    value => $value,
                };
            }
        };

        # Handle errors
        if ($@) {
            warn "Error fetching phenotype data for trial '$trial_name' and trait '$trait_name': $@";
        }
    }

    # Return the combined results as JSON
    $c->res->content_type('application/json');
    $c->res->body(encode_json(\@data));

    # Debugging: Print results
    # print Dumper \@data;
}


1;
