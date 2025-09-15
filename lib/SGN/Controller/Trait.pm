package SGN::Controller::Trait;

use Moose;
use Data::Dumper;
use CXGN::Onto;
use CXGN::Cvterm;

BEGIN { extends 'Catalyst::Controller'; }

sub treatment_design_page : Path('/traits/design/') Args(0) {
    my $self = shift;
    my $c = shift;

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    if (! $c->config->{allow_trait_edits}) {
        $c->stash->{template} = '/site/error/permission_denied.mas';
    } else {

        if ($c->user() && $c->user->check_roles('curator')) {
            my $ontology_obj = CXGN::Onto->new({
			    schema => $schema
            });
            my @root_nodes = $ontology_obj->get_root_nodes('trait_ontology');

            my $root_term_name = $root_nodes[0]->[1] =~ s/\w+:\d+ //r;
            my $db_name = $root_nodes[0]->[1] =~ s/:.*//r;

            my $cvterm_id = $schema->resultset("Cv::Cvterm")->find({
                name => $root_term_name,
                cv_id => $root_nodes[0]->[0]
            })->cvterm_id();

            my $cvterm = CXGN::Cvterm->new({ schema=>$schema, cvterm_id => $cvterm_id } );
            $c->stash(
                template => '/tools/trait_designer.mas',
                trait_root => $cvterm,
                db_name => $db_name
            );
        } else {
            $c->stash->{template} = '/site/error/permission_denied.mas';
        }
    }
}

1;