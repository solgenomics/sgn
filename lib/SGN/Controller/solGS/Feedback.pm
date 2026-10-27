
package SGN::Controller::solGS::Feedback;

use Moose;
use namespace::autoclean;
use SGN::I18N ();

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
    my SGN::I18N $i18n = SGN::I18N::translate($c);

    $job_type =~ s/[_|-]/ /g;
    $job_type = lc($job_type);

    my $user_id  = $c->user()->get_object()->get_sp_person_id();
    my $profile_link = "<a href=\"/solpeople/profile/$user_id\">" . SGN::I18N::translate($i18n, "solgs.feedback.your_profile_page", "your profile page") . "</a>";

    my $referer  = $c->req->referer;
    my $back_link = "<a href=\"$referer\">" . SGN::I18N::translate($i18n, "solgs.feedback.go_back", "[ Go back ]") . "</a>";
    
    my $msg = "<p>" . SGN::I18N::translate($i18n, "solgs.feedback.your_job_type_job_is_submitted", "Your %{job_type} job is submitted.", {job_type => "" . ($job_type // "")}) . "</p>"
      . "<p>" . SGN::I18N::translate($i18n, "solgs.feedback.you_will_receive_an_email_when_it_is_completed_which_may_take_up_to_a_few_hours_if_the_email_is_not_in_your_inbox_please_check_also_your_spam_folder", "You will receive an email when it is completed,  which may take up to a few hours. If the email is not in your inbox, please check also your spam folder.") . "</p>"
      . "<p>" . SGN::I18N::translate($i18n, "solgs.feedback.alternatively_you_can_also_check_the_status_of_the_job_in", "Alternatively, you can also check the status of the job in ") . $profile_link . "."
      . "<p>$back_link</p>";

    return $msg;

}

1;