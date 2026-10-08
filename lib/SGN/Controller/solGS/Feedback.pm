
package SGN::Controller::solGS::Feedback;

use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }


sub submission_feedback : Path('/solgs/submission/feedback/') Args() {
    my ( $self, $c ) = @_;
    
    if ($c->user) {
        my $job_type = $c->req->param('job');
        my $msg = $self->message_content($c, $job_type);
        $c->stash->{message} = $msg;
        $c->stash->{template} = "/generic_message.mas";
    } else {
        $c->controller('solGS::Utils')->require_login($c);
    }

}

sub message_content {
    my ($self, $c, $job_type) = @_;

    $job_type =~ s/[_|-]/ /g;
    $job_type = lc($job_type);

    my $user_id  = $c->user()->get_object()->get_sp_person_id();
    my $profile_link = "<a href=\"/solpeople/profile/$user_id\">your profile page</a>";

    my $referer  = $c->req->referer;
    my $back_link = "<a href=\"$referer\">[ Go back ]</a>";
    
    my $msg = "<p>Your $job_type job is submitted.</p>"
      . "<p>You will receive an email when it is completed,  " 
      . "which may take up to a few hours. If the email is not in your inbox, "
      . "please check also your spam folder.</p>"
      . "<p>Alternatively, you can also check the status of the job in $profile_link."
      . "<p>$back_link</p>";

    return $msg;

}

1;