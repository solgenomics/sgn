
=head1 NAME

SGN::Controller::AJAX::Contact - a REST controller class to provide the
functions for posting the contact form as an issue on github

=head1 DESCRIPTION

When the contact form is submitted it is posted as an issue to github

=head1 AUTHOR

Nicolas Morales <nm529@cornell.edu>

=cut

package SGN::Controller::AJAX::Contact;

use Moose;
use Data::Dumper;
use LWP::UserAgent;
use JSON;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
   );

sub submit_contact_form : Path('/ajax/contact/submit') : ActionClass('REST') { }

sub submit_contact_form_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $title = $c->req->param('title');
    my $body = $c->req->param('body');
    my $security_answer = $c->req->param('security_answer');
    my $security_attempt = $c->req->param('security_attempt');

    if (!$security_attempt || !$security_answer || $security_answer ne $security_attempt){
        $c->stash->{rest} = {error => "You must be a clever bot"};
        $c->detach;
    }

    my $github_access_token = $c->config->{github_access_token};
    my $website_name = $c->config->{project_name};
    my $ua = LWP::UserAgent->new;

    my $server_endpoint = "https://api.github.com/repos/solgenomics/contactform/issues?access_token=$github_access_token";
    my $req = HTTP::Request->new(POST => $server_endpoint);
    $req->header('content-type' => 'application/json', 'Authorization' => "token $github_access_token");
    
    $body .= "\n\nSent from website: $website_name";
    $body .= "\n\nPlease remember to include the contact person's email in any replies which are directed to them. Please include the github.reply email address as a recipient in all messages, so that they are logged with the open ticket.";
    my $post_data = { "title"=>$title, "body"=> $body, "labels"=>[$website_name] };
    $req->content( encode_json $post_data);

    my $resp = $ua->request($req);
    if ($resp->is_success) {
        my $message = $resp->decoded_content;
        my $message_hash = decode_json $message;
        #print STDERR Dumper $message_hash;
        if ($message_hash->{id}){
            $c->stash->{rest} = {success => 1};
        } else {
            $c->stash->{rest} = {error => 'The message was not posted to github correctly. Please try again.'};
        }
    } else {
        $c->stash->{rest} = {error => "There was an error submitting the message. Please try again."};
    }
}

1;
