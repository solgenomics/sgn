
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
use CXGN::MixedModels;
use SGN::Controller::AJAX::Dataset;
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
        while (my ($project_name, $project_location, $validated_trait ) = $sth_trial->fetchrow_array) {
            # Store each row's data in a hash reference
            my $project_data = {
                name => $project_name,
                project_location => $project_location,
                validated_trait => $validated_trait,
            };
            # Push the hash reference into the array
            push @validated_projects, $project_data;
        }

        print STDERR Dumper \@validated_projects;

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



1;
