package SGN::Controller::KinaseClones;

use Moose;
use namespace::autoclean;
use CXGN::People;

BEGIN { extends 'Catalyst::Controller' }

=head1 NAME

SGN::Controller::KinaseClones - controller to request kinase clones

=cut

#Creates a blank form
sub form :Path('/kinases/clones/form') :Args(0) {
    my ($self, $c) = @_;
   
    $c->stash->{contact_form_human_question}       = $c->config->{contact_form_human_question};
    $c->stash->{contact_form_human_answer_correct} = 1;  # do not show warning on initial screen
    $c->stash->{template} = '/kinases/clones/order.mas';
}


sub submit :Path('/kinases/clones/submit') :Args(0) {
    my ($self, $c) = @_;
    my ($name, $email, $body, $address, $organization, $contact_form_human_answer) = map { $c->request->param($_) } qw/name email body address organization contact_form_human_answer /;
    
    if ($contact_form_human_answer eq $c->config->{contact_form_human_answer} and $name and $email and $address and $organization and $body || $ENV{SGN_TEST_MODE}) {

	my $host = $c->request->hostname();
	my $client_ip = $c->request->address();

        $body = <<END_HEREDOC;

This message was sent from SGN TOKN Clones Request form

From:
$name <$email>

Address:
$address

Organization:
$organization

Message:
$body


END_HEREDOC

# add the client IP address so we can block abusers
#

       $c->stash->{email} = {
        to      => $c->config->{tokn_email},
        from    => $c->config->{tokn_email},
        subject => "TOKN Clone Request via SGN",
        body    => $body,
       };

       $c->forward('View::Email');

       $c->stash->{message} = "Thank you. Your message has been sent.";
       $c->stash->{template} = "/generic_message.mas";
    } else {

       my %info_fields = (
	   name    => $name,
	   email   => $email,
	   address => $address,
	   subject => "TOKN Clone Request via SGN",
	   organization => $organization,
	   body    => $body
       );
       foreach my $category (keys %info_fields) {
           $c->stash->{filled}->{$category} = $info_fields{$category};
       }

       $c->stash->{name} = $name;
       $c->stash->{email} = $email;
       $c->stash->{address} = $address;
       $c->stash->{subject} = "TOKN Clone Request via SGN";
       $c->stash->{organization} = $organization;
       $c->stash->{body} = $body;
       $c->stash->{contact_form_human_question} = $c->config->{contact_form_human_question};
       $c->stash->{contact_form_human_answer}  = $contact_form_human_answer;
       $c->stash->{template} = '/kinases/clones/order.mas';

       #_build_form_page($self, $c, $name, $email, $c->config->{contact_form_human_question}, $contact_form_human_answer, 0, $subject, $body);
    }
}

__PACKAGE__->meta->make_immutable;
1;
