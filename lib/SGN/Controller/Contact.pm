package SGN::Controller::Contact;

use Moose;
use namespace::autoclean;
use CXGN::People;
use Captcha::reCAPTCHA;

BEGIN { extends 'Catalyst::Controller' }

=head1 NAME

SGN::Controller::Contact - controller for contact page

=cut

#Creates a blank form
sub form :Path('/contact/form') :Args(0) {
    my ($self, $c) = @_;
    my ($username, $useremail) = _load_user($c);

   
    $c->stash->{website_name} = $c->config->{project_name};
    $c->stash->{contact_form_human_question}       = $c->config->{contact_form_human_question};
    $c->stash->{contact_form_human_answer_correct} = 1;  # do not show warning on initial screen
    $c->stash->{captcha_public_key}       = $c->config->{captcha_public_key};
    $c->stash->{email_address_to_display} = $useremail;
    $c->stash->{name} = $username;
    $c->stash->{email_address_to_display} = $c->config->{feedback_email};
    
     $c->stash->{template} = '/help/contact.mas';

#    _build_form_page($self, $c, undef, undef, undef, undef, 1, undef, undef); #, $username, $useremail, $c->config->{contact_form_human_question}, $answer, $check, $c->req->param("subject"), $c->req->param("body") );
}

#Loads the user if he has an account
sub _load_user {
    my ($c) = @_;
    my $dbh = $c->dbc->dbh;
    my $user = $c->user_exists ? $c->user->get_object : CXGN::People::Person->new( $dbh, undef );

    my $username  = join ' ', grep defined, $user->get_first_name, $user->get_last_name;
    my $useremail = $user->get_private_email;

    return ($username, $useremail);
}

sub submit :Path('/contact/submit') :Args(0) {
    my ($self, $c) = @_;
    my ($name, $email, $subject, $body, $challenge, $response, $contact_form_human_answer) =
        map { $c->request->param($_) } qw/name email subject body recaptcha_challenge_field recaptcha_response_field contact_form_human_answer /;
    
    my $captcha = Captcha::reCAPTCHA->new;

    my $result = $captcha->check_answer(
        $c->config->{captcha_private_key}, $c->request->address(),
        $challenge, $response
    );

    my $project = $c->config->{project_name};

    if ($contact_form_human_answer eq $c->config->{contact_form_human_answer} and $name and $email and $subject and $body and ($result->{is_valid} || $ENV{SGN_TEST_MODE})) {

my $host = $c->request->hostname();
my $client_ip = $c->request->address();

       $body .= <<END_HEREDOC;

This message sent from $project contact form

From:
$name <$email>

(email sent from host $host, client ip $client_ip)

Subject:
$subject

Body:
$body



END_HEREDOC

# add the client IP address so we can block abusers
#


       $c->stash->{email} = {
        to      => $c->config->{feedback_email},
        from    => $c->config->{feedback_email},
        subject => "[".$c->config->{name}."][contact] $subject",
        body    => $body,
       };

       $c->forward('View::Email');

       $c->stash->{message} = "Thank you. Your message has been sent.";
       $c->stash->{template} = "/generic_message.mas";
    } else {
    my %info_fields = (
	name    => $name,
	email   => $email,
	subject => $subject,
	body    => $body
    );
foreach my $category (keys %info_fields) {
    $c->stash->{filled}->{$category} = $info_fields{$category};
}

$c->stash->{name} = $name;
$c->stash->{email} = $email;
$c->stash->{subject} = $subject;
$c->stash->{body} = $body;
$c->stash->{email_address_to_display} = $c->config->{feedback_email};
$c->stash->{website_name} = $c->config->{project_name};
$c->stash->{captcha_public_key} = $c->config->{captcha_public_key};
$c->stash->{contact_form_human_question} = $c->config->{contact_form_human_question};
$c->stash->{contact_form_human_answer}  = $contact_form_human_answer;
$c->stash->{template} = '/help/contact.mas';

#_build_form_page($self, $c, $name, $email, $c->config->{contact_form_human_question}, $contact_form_human_answer, 0, $subject, $body);
}
}

__PACKAGE__->meta->make_immutable;
1;
