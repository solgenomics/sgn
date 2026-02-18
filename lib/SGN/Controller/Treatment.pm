package SGN::Controller::Treatment;

use Moose;
use CXGN::Cvterm;
use CXGN::Onto;

BEGIN { extends 'Catalyst::Controller'; }

sub treatment_design_page : Path('/treatments/design/') Args(0) {
    my $self = shift;
    my $c = shift;

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    if (! $c->config->{allow_treatment_edits}) {
        $c->stash->{template} = '/site/error/permission_denied.mas';
    } else {

        if ($c->user() && $c->user->check_roles('curator')) {
            my $ontology_obj = CXGN::Onto->new({
			    schema => $schema
            });
            my @root_nodes = $ontology_obj->get_root_nodes('experiment_treatment_ontology');

            my $root_term_name = $root_nodes[0]->[1] =~ s/\w+:\d+ //r;
            my $db_name = $root_nodes[0]->[1] =~ s/:.*//r;

            my $cvterm_id = $schema->resultset("Cv::Cvterm")->find({
                name => $root_term_name,
                cv_id => $root_nodes[0]->[0]
            })->cvterm_id();
            my $cvterm = CXGN::Cvterm->new({ schema=>$schema, cvterm_id => $cvterm_id } );
            $c->stash(
                template => '/tools/treatment_designer.mas',
                exp_treatment_root => $cvterm,
                db_name => $db_name
            );
        } else {
            $c->stash->{template} = '/site/error/permission_denied.mas';
        }

    }

}

1;