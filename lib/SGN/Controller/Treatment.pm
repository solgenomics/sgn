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

    if (!($c->user() && $c->user->check_roles('curator'))) {
        $c->stash->{template} = '/site/error/permission_denied.mas';
        return;
    }

    my $editable_ontologies_str = $c->config->{allow_trait_edits}; #this can be 1 or a list of dbnames

    if ($editable_ontologies_str == 1) { #shorthand for first trait ontology only - not treatments
        $c->stash->{template} = '/site/error/permission_denied.mas';
    } else { #need to actually check if treatment ontology is editable
        my @editable_ontologies = split(",", $editable_ontologies_str);

        if (grep {$_ eq "EXPERIMENT_TREATMENT"} @editable_ontologies) {
            $c->stash(
                template => '/tools/treatment_designer.mas',
                db_name => "EXPERIMENT_TREATMENT"
            );
        } else {
            $c->stash->{template} = '/site/error/permission_denied.mas';
        }
    }
}

1;