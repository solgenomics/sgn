
package SGN::Controller::ImageAnalysis;

use Moose;
use JSON;
use URI::FromHash 'uri';

BEGIN { extends 'Catalyst::Controller' };

sub home : Path('/tools/image_analysis') Args(0) { 
    my $self = shift;
    my $c = shift;
    if (!$c->user()) {
        $c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
        return;
    }
    
    my $services_json = $c->config->{image_analysis_services}  || {};

    chomp($services_json);
    
    my $services = decode_json($services_json);

    $c->stash->{services} = $services;
   
    $c->stash->{template} = 'tools/image_analysis.mas';
}

sub image_analysis_run_info : Path('/image_analysis/run') : Args(1) {
    my ($self, $c, $run_project_id) = @_;

    my $schema         = $c->dbic_schema("Bio::Chado::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");

    # Check login
    if (!$c->user()) {
        $c->res->redirect('/user/login');
        $c->detach();
    }

    my $user_can_modify = ($c->user()->roles() =~ /curator|submitter/) ? 1 : 0;

    # Get run project
    my $run_project = $schema->resultset('Project::Project')->find({
        project_id => $run_project_id
    });

    unless ($run_project) {
        $c->stash->{template} = '/generic_message.mas';
        $c->stash->{message}  = "Run project $run_project_id not found.";
        $c->detach();
    }

    my $run_name = $run_project->name();

    # Get projectprops
    my $service_name       = '';
    my $run_date           = '';
    my $analysis_info_json = '{}';

    my $analysis_run_type_cvterm_id =
        SGN::Model::Cvterm->get_cvterm_row(
            $schema, 'image_analysis_run_project_type', 'project_property'
        )->cvterm_id();

    my $project_start_date_type_id =
        SGN::Model::Cvterm->get_cvterm_row(
            $schema, 'project_start_date', 'project_property'
        )->cvterm_id();

    my $analysis_run_params_cvterm_id =
        SGN::Model::Cvterm->get_cvterm_row(
            $schema, 'image_analysis_run_parameters_json', 'project_property'
        )->cvterm_id();

    my $props_rs = $schema->resultset('Project::Projectprop')->search({
        project_id => $run_project_id
    });

    while (my $prop = $props_rs->next()) {
        my $type_id = $prop->type_id();
        if ($type_id == $analysis_run_type_cvterm_id) {
            $service_name = $prop->value();
        } elsif ($type_id == $project_start_date_type_id) {
            $run_date = $prop->value();
        } elsif ($type_id == $analysis_run_params_cvterm_id) {
            $analysis_info_json = $prop->value();
        }
    }

    # Get parent trial via project_relationship
    my $analysis_run_on_trial_rel_cvterm_id =
        SGN::Model::Cvterm->get_cvterm_row(
            $schema, 'image_analysis_run_on_field_trial', 'project_relationship'
        )->cvterm_id();

    my $trial_id   = undef;
    my $trial_name = '';

    my $rel_rs = $schema->resultset('Project::ProjectRelationship')->find({
        subject_project_id => $run_project_id,
        type_id            => $analysis_run_on_trial_rel_cvterm_id,
    });

    if ($rel_rs) {
        $trial_id = $rel_rs->object_project_id();
        my $trial_project = $schema->resultset('Project::Project')->find({
            project_id => $trial_id
        });
        $trial_name = $trial_project->name() if $trial_project;
    }

    my $source_image_type_id =
        SGN::Model::Cvterm->get_cvterm_row(
            $schema, 'image_analysis_source_image', 'project_md_image'
        )->cvterm_id();

    my $overlay_image_type_id =
        SGN::Model::Cvterm->get_cvterm_row(
            $schema, 'image_analysis_result_overlay', 'project_md_image'
        )->cvterm_id();

    my $source_image_id  = undef;
    my $overlay_image_id = undef;
    my $overlay_image_url = undef;

    my $pmi_rs = $phenome_schema->resultset('ProjectMdImage')->search({
        project_id => $run_project_id
    });

    while (my $pmi = $pmi_rs->next()) {
        if ($pmi->type_id() == $source_image_type_id) {
            $source_image_id = $pmi->image_id();
        } elsif ($pmi->type_id() == $overlay_image_type_id) {
            $overlay_image_id = $pmi->image_id();
        }
    }

    if ($overlay_image_id) {
        my $image = SGN::Image->new(
            $schema->storage->dbh(), $overlay_image_id, $c
        );
        $overlay_image_url = $image->get_image_url('large');
    }

    $c->stash(
        run_project_id    => $run_project_id,
        run_name          => $run_name,
        service_name      => $service_name,
        run_date          => $run_date,
        trial_id          => $trial_id,
        trial_name        => $trial_name,
        analysis_info_json => $analysis_info_json,
        overlay_image_id  => $overlay_image_id,
        overlay_image_url => $overlay_image_url,
        source_image_id   => $source_image_id,
        user_can_modify   => $user_can_modify,
        template          => '/breeders_toolbox/image_analysis_run.mas',
    );
}

1;
