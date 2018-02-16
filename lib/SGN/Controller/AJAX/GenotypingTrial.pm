
package SGN::Controller::AJAX::GenotypingTrial;

use Moose;
use JSON;
use Data::Dumper;
use CXGN::Trial::TrialDesign;
use Try::Tiny;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
);

sub generate_genotype_trial : Path('/ajax/breeders/generategenotypetrial') ActionClass('REST') {}
sub generate_genotype_trial_POST : Args(0) {
    my $self = shift;
    my $c = shift;

    if (!($c->user()->check_roles('curator') || $c->user()->check_roles('submitter'))) {
        $c->stash->{rest} = { error => 'You do not have the required privileges to create a genotyping trial.' };
        $c->detach();
    }

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $plate_info = decode_json $c->req->param("plate_data");
    print STDERR Dumper $plate_info;

    if ( !$plate_info->{elements} || !$plate_info->{genotyping_facility_submit} || !$plate_info->{project_name} || !$plate_info->{description} || !$plate_info->{location} || !$plate_info->{year} || !$plate_info->{name} || !$plate_info->{breeding_program} || !$plate_info->{genotyping_facility} || !$plate_info->{sample_type} || !$plate_info->{plate_format} ) {
        $c->stash->{rest} = { error => "Please provide all parameters" };
        $c->detach();
    }

    if ( $plate_info->{genotyping_facility} eq 'igd' && $plate_info->{genotyping_facility_submit} eq 'yes' && $plate_info->{blank_well} eq ''){
        $c->stash->{rest} = { error => "To submit to Cornell IGD you need to provide the blank well!" };
        $c->detach();
    }

    my $location = $schema->resultset("NaturalDiversity::NdGeolocation")->find( { nd_geolocation_id => $plate_info->{location} } );
    if (!$location) {
        $c->stash->{rest} = { error => "Unknown location" };
        $c->detach();
    }

    my $breeding_program = $schema->resultset("Project::Project")->find( { project_id => $plate_info->{breeding_program} });
    if (!$breeding_program) {
        $c->stash->{rest} = { error => "Unknown breeding program" };
        $c->detach();
    }

    my $td = CXGN::Trial::TrialDesign->new( { schema => $schema });

    $td->set_stock_list($plate_info->{elements});
    $td->set_block_size($plate_info->{plate_format});
    $td->set_blank($plate_info->{blank_well});
    $td->set_trial_name($plate_info->{name});
    $td->set_design_type("genotyping_plate");

    eval {
        $td->calculate_design();
    };

    if ($@) {
        $c->stash->{rest} = { error => "Design failed. Error: $@" };
        print STDERR "Design failed because of $@\n";
        $c->detach();
    }

    my $design = $td->get_design();

    if (exists($design->{error})) {
        $c->stash->{rest} = $design;
        $c->detach();
    }
    print STDERR Dumper($design);

    $c->stash->{rest} = {success => 1, design=>$design};
}


sub store_genotype_trial : Path('/ajax/breeders/storegenotypetrial') ActionClass('REST') {}
sub store_genotype_trial_POST : Args(0) {
    my $self = shift;
    my $c = shift;

    if (!($c->user()->check_roles('curator') || $c->user()->check_roles('submitter'))) {
        $c->stash->{rest} = { error => 'You do not have the required privileges to create a genotyping trial.' };
        $c->detach();
    }

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $plate_info = decode_json $c->req->param("plate_data");
    print STDERR Dumper $plate_info;

    if ( !$plate_info->{elements} || !$plate_info->{genotyping_facility_submit} || !$plate_info->{project_name} || !$plate_info->{description} || !$plate_info->{location} || !$plate_info->{year} || !$plate_info->{name} || !$plate_info->{breeding_program} || !$plate_info->{genotyping_facility} || !$plate_info->{sample_type} || !$plate_info->{plate_format} ) {
        $c->stash->{rest} = { error => "Please provide all parameters" };
        $c->detach();
    }

    my $location = $schema->resultset("NaturalDiversity::NdGeolocation")->find( { nd_geolocation_id => $plate_info->{location} } );
    if (!$location) {
        $c->stash->{rest} = { error => "Unknown location" };
        $c->detach();
    }

    my $breeding_program = $schema->resultset("Project::Project")->find( { project_id => $plate_info->{breeding_program} });
    if (!$breeding_program) {
        $c->stash->{rest} = { error => "Unknown breeding program" };
        $c->detach();
    }

    print STDERR "Creating the trial...\n";

    my $message;
    my $coderef = sub {

        my $ct = CXGN::Trial::TrialCreate->new( {
            chado_schema => $schema,
            dbh => $c->dbc->dbh(),
            user_name => $c->user()->get_object()->get_username(), #not implemented,
            operator => $c->user()->get_object()->get_username(),
            trial_year => $plate_info->{year},
            trial_location => $location->description(),
            program => $breeding_program->name(),
            trial_description => $plate_info->{description},
            design_type => 'genotyping_plate',
            design => $plate_info->{design},
            trial_name => $plate_info->{name},
            is_genotyping => 1,
            genotyping_user_id => $c->user()->get_object()->get_sp_person_id(),
            genotyping_project_name => $plate_info->{project_name},
            genotyping_facility_submitted => $plate_info->{genotyping_facility_submit},
            genotyping_facility => $plate_info->{genotyping_facility},
            genotyping_plate_format => $plate_info->{plate_format},
            genotyping_plate_sample_type => $plate_info->{sample_type},
        });

        $message = $ct->save_trial();
    };

    try {
        $schema->txn_do($coderef);
    } catch {
        print STDERR "Transaction Error: $_\n";
        $c->stash->{rest} = {error => "Error saving genotyping trial in the database: $_"};
        $c->detach;
    };

    my $error;
    if ($message->{'error'}) {
        $error = $message->{'error'};
    }
    if ($error){
        $c->stash->{rest} = {error => "Error saving genotyping trial in the database: $error"};
        $c->detach;
    }
    #print STDERR Dumper(%message);

    $c->stash->{rest} = {
        message => "Successfully stored the genotyping trial.",
        trial_id => $message->{trial_id},
    };
}

sub get_genotypingserver_credentials : Path('/ajax/breeders/genotyping_credentials') Args(0) { 
    my $self = shift;
    my $c = shift;

    if ($c->user && ($c->user->check_roles("submitter") || $c->user->check_roles("curator"))) { 
        $c->stash->{rest} = { 
            host => $c->config->{genotyping_server_host},
            username => $c->config->{genotyping_server_username},
            password => $c->config->{genotyping_server_password}
        };
    }
    else { 
        $c->stash->{rest} = { 
            error => "Insufficient privileges for this operation." 
        };
    }
}

1;
