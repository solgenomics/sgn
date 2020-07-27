
package SGN::Controller::Analysis;

use Moose;
use URI::FromHash 'uri';


BEGIN { extends 'Catalyst::Controller' };

sub view_analyses :Path('/analyses') Args(0) {
    my $self = shift;
    my $c = shift;

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $user_id;
    if ($c->user()) {
	$user_id = $c->user->get_object()->get_sp_person_id();
    }
    if (!$user_id) {
	$c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
    }

    
    $c->stash->{template} = '/analyses/index.mas';
}

sub analysis_detail :Path('/analyses') Args(1) {
    my $self = shift;
    my $c = shift;
    my $analysis_id = shift;
    my $bcs_schema = $c->dbic_schema("Bio::Chado::Schema");

    print STDERR "Viewing analysis with id $analysis_id\n";

    my $a = CXGN::Analysis->new({
        bcs_schema => $bcs_schema,
        people_schema => $c->dbic_schema("CXGN::People::Schema"),
        metadata_schema => $c->dbic_schema("CXGN::Metadata::Schema"),
        phenome_schema => $c->dbic_schema("CXGN::Phenome::Schema"),
        trial_id => $analysis_id,
    });

    if (! $a) {
        $c->stash->{template} = '/generic_message.mas';
        $c->stash->{message} = 'The requested analysis ID does not exist in the database.';
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
    $c->stash->{template} = '/analyses/detail.mas';
}

1;
    
