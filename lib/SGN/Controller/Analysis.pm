
package SGN::Controller::Analysis;

use Moose;
use URI::FromHash 'uri';
use Data::Dumper;

BEGIN { extends 'Catalyst::Controller' };

sub view_analyses :Path('/analyses') Args(0) {
    my $self = shift;
    my $c = shift;

    my $user_id;
    if ($c->user()) {
        $user_id = $c->user->get_object()->get_sp_person_id();
    }
    if (!$user_id) {
        $c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
    }

    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $user_id);

    $c->stash->{template} = '/analyses/index.mas';
}

sub analysis_detail :Path('/analyses') Args(1) {
    my $self = shift;
    my $c = shift;
    my $analysis_id = shift;
    my $user = $c->user();

    my $user_id;
    if ($c->user()) {
        $user_id = $c->user->get_object()->get_sp_person_id();
    }
    if (!$user_id) {
        $c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
        $c->detach();
    }

    my $bcs_schema = $c->dbic_schema("Bio::Chado::Schema", undef, $user_id);
    print STDERR "Viewing analysis with id $analysis_id\n";

    my $a;
    eval {
    $a = CXGN::Analysis->new({
        bcs_schema => $bcs_schema,
        people_schema => $c->dbic_schema("CXGN::People::Schema", undef, $user_id),
        metadata_schema => $c->dbic_schema("CXGN::Metadata::Schema", undef, $user_id),
        phenome_schema => $c->dbic_schema("CXGN::Phenome::Schema", undef, $user_id),
        trial_id => $analysis_id,
    });
    };

    if ($@) {
        $c->stash->{template} = '/generic_message.mas';
        $c->stash->{message} = 'The requested analysis ID does not exist in the database or has been deleted.';
        return;
    }

    $c->stash->{analysis_id} = $analysis_id;
    $c->stash->{analysis_name} = $a->name();
    $c->stash->{analysis_description} = $a->description();
    $c->stash->{breeding_program_name} = $a->get_breeding_program();
    $c->stash->{breeding_program_id} = $bcs_schema->resultset("Project::Project")->find({name=>$a->get_breeding_program()})->project_id();
    $c->stash->{year} = $a->get_year();
    $c->stash->{trial_stock_type} = 'accession';
    $c->stash->{trial_phenotype_stock_type} = 'analysis_instance';
    $c->stash->{has_col_and_row_numbers} = $a->has_col_and_row_numbers();
    $c->stash->{identifier_prefix} = $c->config->{identifier_prefix};
    $c->stash->{analysis_metadata} = $a->metadata();
    $c->stash->{user_can_modify} = $user->check_roles("submitter") || $user->check_roles("curator");
    $c->stash->{template} = '/analyses/detail.mas';
}

sub analysis_model_detail :Path('/analyses_model') Args(1) {
    my $self = shift;
    my $c = shift;
    my $model_id = shift;

    my $user_id;
    if ($c->user()) {
        $user_id = $c->user->get_object()->get_sp_person_id();
    }
    if (!$user_id) {
        $c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
        $c->detach();
    }

    my $bcs_schema = $c->dbic_schema("Bio::Chado::Schema", undef, $user_id);
    print STDERR "Viewing analysis model with id $model_id\n";

    my $m = CXGN::AnalysisModel::GetModel->new({
        bcs_schema=>$bcs_schema,
        metadata_schema=>$c->dbic_schema("CXGN::Metadata::Schema", undef, $user_id),
        phenome_schema=>$c->dbic_schema("CXGN::Phenome::Schema", undef, $user_id),
        nd_protocol_id=>$model_id
    });
    my $saved_model_object = $m->get_model();
    #print STDERR Dumper $saved_model_object;

    if (!$saved_model_object->{model_id}) {
        $c->stash->{template} = '/generic_message.mas';
        $c->stash->{message} = 'The requested model ID does not exist in the database.';
        return;
    }

    $c->stash->{model_id} = $saved_model_object->{model_id};
    $c->stash->{model_name} = $saved_model_object->{model_name};
    $c->stash->{model_description} = $saved_model_object->{model_description};
    $c->stash->{model_properties} = $saved_model_object->{model_properties};
    $c->stash->{model_file_ids} = $saved_model_object->{model_file_ids};
    $c->stash->{model_type_name} = $saved_model_object->{model_type_name};
    $c->stash->{model_files} = $saved_model_object->{model_files};
    $c->stash->{identifier_prefix} = $c->config->{identifier_prefix}."_Model_";
    $c->stash->{template} = '/analyses/model_detail.mas';
}

1;
    
