package SGN::Controller::Contact;

use Moose;
use namespace::autoclean;
use CXGN::People;

BEGIN { extends 'Catalyst::Controller' }

=head1 NAME

SGN::Controller::Contact - controller for contact page

=cut

#Creates a blank form
sub form :Path('/contact/form') :Args(0) {
    my ($self, $c) = @_;
    my ($username, $useremail) = _load_user($c);

    my $val_1 = int rand(20);
    my $val_2 = int rand(20);
    my $question = "$val_1 + $val_2";
    my $answer = $val_1 + $val_2;

    $c->stash->{website_name} = $c->config->{project_name};
    #$c->stash->{captcha_public_key} = $c->config->{captcha_public_key};
    #$c->stash->{captcha_private_key} = $c->config->{captcha_private_key};
    $c->stash->{contact_form_human_question} = $question;
    $c->stash->{contact_form_human_answer} = $answer;
    $c->stash->{email_address_to_display} = $c->config->{feedback_email};
    $c->stash->{github_access_token} = $c->config->{github_access_token};
    
     $c->stash->{template} = '/help/contact.mas';
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


__PACKAGE__->meta->make_immutable;
1;
