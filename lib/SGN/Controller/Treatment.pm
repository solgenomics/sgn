package SGN::Controller::Treatment;

use Moose;
use CXGN::Cvterm;

BEGIN { extends 'Catalyst::Controller'; }

sub treatment_design_page : Path('/treatments/design/') Args(0) {
    my $self = shift;
    my $c = shift;

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    if (! $c->config->{allow_treatment_design}) {
        $c->stash->{template} = '/site/error/permission_denied.mas';
    } else {

        if ($c->user() && $c->user->check_roles('curator')) {
            my $experiment_treatment_cv = $schema->resultset("Cv::Cv")->find({ name => 'experiment_treatment'});
            my $experiment_treatment_cv_id;
            if ($experiment_treatment_cv) {
                $experiment_treatment_cv_id = $experiment_treatment_cv->cv_id ;
            } else {
                die "No experiment_treatment CV found. Has DB patch been run?\n";
            }
            my $experiment_treatment_root = $schema->resultset("Cv::Cvterm")->find({ name => 'Experimental treatment ontology'  , cv_id => $experiment_treatment_cv_id });
            my $cvterm_id = $experiment_treatment_root->cvterm_id();
            my $cvterm = CXGN::Cvterm->new({ schema=>$schema, cvterm_id => $cvterm_id } );
            $c->stash(
                template => '/tools/treatment_designer.mas',
                exp_treatment_root => $cvterm
            );
        } else {
            $c->stash->{template} = '/site/error/permission_denied.mas';
        }

    }

}

1;