
package SGN::Controller::solGS::Feedback;

use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }


sub submission_feedback : Path('/solgs/submission/feedback/') Args() {
    my ( $self, $c ) = @_;

    my $job_type = $c->req->param('job');
    my $msg = $self->message_content($c, $job_type);

    $c->stash->{message} = $msg;
    $c->stash->{template} = "/generic_message.mas";

}


sub message_content {
    my ($self, $c, $job_type) = @_;

    my $job_type =~ s/[_|-]/ /g;
    $job_type = lc($job_type);

    my $user_id  = $c->user()->get_object()->get_sp_person_id();
    my $referer  = $c->req->referer;

    my $msg =
        "<p>$job_type</p>"
      . "<p>You will receive an email when it is completed. "
      . "You can also check the status of the job in "
      . "<a href=\"/solpeople/profile/$user_id\">your profile page</a>"
      . "<p><a href=\"$referer\">[ Go back ]</a></p>";

    
    $msg = "Your $job job is submitted.";

    return $msg;

}

sub begin : Private {
    my ( $self, $c ) = @_;

    $c->controller('solGS::Files')->get_solgs_dirs($c);

}

1;