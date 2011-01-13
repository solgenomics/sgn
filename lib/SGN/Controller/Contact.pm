=head1 NAME

SGN::Controller::Contact - controller for contact page

=cut

package SGN::Controller::Contact;
use Moose;
use namespace::autoclean;

has 'reference' => (
    is => "rw",
    isa => 'Str',
    required => 0,
    default => '',
);

BEGIN { extends 'Catalyst::Controller' }

use CXGN::DB::Connection;
use CXGN::Login;
use CXGN::People;
use CXGN::Contact;

sub form :Path('/contact/form') :Args(0) {
    my ($self, $c) = @_;
    my ($username, $useremail) = _load_user();
    _build_form_page($self, $c, $username, $useremail); 
}

sub _load_user {
    my $dbh   = CXGN::DB::Connection->new();
    my $login = CXGN::Login->new($dbh);
    my $username;
    my $useremail;
    if ( my $user_id = $login->has_session() ) 
    {
       my $user = CXGN::People::Person->new( $dbh, $user_id );
       $username  = $user->get_first_name() . " " . $user->get_last_name();
       $useremail = $user->get_private_email();
    }
    $username  ||= '';
    $useremail ||= '';
    return ($username, $useremail);
}

sub _build_form_page {
    my ($self, $c, $name, $email, $subject, $body) = @_;
    $c->stash->{name} = $name if $name;
    $c->stash->{email} = $email if $email;
    $c->stash->{subject} = $subject if $subject;
    $c->stash->{body} = $body if $body;
    $c->stash->{email_address_to_display} = 'sgn-feedback@solgenomics.net';
    $c->stash->{template} = '/help/contact.mas';
}

sub submit :Path('/contact/submit') :Args(0)
{
    my ($self, $c) = @_;
    my $name = $c->request->param('name');
    my $email =$c->request->param('email'); 
    my $subject = $c->request->param('subject');
    my $body = $c->request->param('body');
    if ($name and $email and $subject and $body) 
    {
       $body = <<END_HEREDOC;
From:
$name <$email>

Subject:
$subject

Body:
$body

Referred from:
$self->reference

END_HEREDOC
       print STDERR "Before it is sent";
       CXGN::Contact::send_email( "[contact.pl] $subject", $body, 'email',
                                        $email );
       print STDERR "After it is sent";
       $c->stash->{message} = "Thank you. Your message has been sent.";
       $c->stash->{template} = "/gen_pages/message.mas";
    }
    else
    {
       my @fields = ("name", "email", "subject", "body");
       my %infoInFields = ("name" => $name,
                             "email" => $email,
                               "subject" => $subject,
                                      "body" => $body);
       foreach my $category (@fields)
       {
         $c->stash->{filled}->{$category} = $infoInFields{$category};
       }
       _build_form_page($self, $c, $name, $email, $subject, $body);
    }
}

__PACKAGE__->meta->make_immutable;
1;
