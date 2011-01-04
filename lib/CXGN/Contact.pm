
=head1 NAME

CXGN::Contact

=head1 DESCRIPTION

Allows scripts to send emails to the development team.

=head1 FUNCTIONS

=cut 

package CXGN::Contact;
use strict;

use Mail::Sendmail;

use CXGN::Apache::Request;
use CXGN::Tools::Text;

use SGN::Context;

=head2 send_email

  Usage:
  Desc : Sends an email to the development team.
  Args : - subject,
         - message body,
         - email address or conf key name that should contain an email
           address to send to
         - replyto address to include in the email
  Ret  : nothing meaningful
  Side Effects: dies on error
  Example:

    CXGN::Contact::send_email($subject,$body,$mailto);#goes to wherever you say it should go
    CXGN::Contact::send_email($subject,$body,'email');#goes to email found in conf object
    CXGN::Contact::send_email($subject,$body,'bugs_email');#goes to bugs_email found in conf object
    CXGN::Contact::send_email($subject,$body);#goes to this script's default of bugs_email
    CXGN::Contact::send_email($subject,$body,$mailto,$replyto);#sends an email with a reply-to different from the sender (the sender is the apache user from the conf object, usually www-data)

=cut

sub send_email {
    my ( $subject, $body, $mailto, $replyto ) = @_;
    my $request_info = "";
    my $vhost_conf   = SGN::Context->new;
    my $hostname     = `hostname`;
    chomp($hostname);
    #my $dnsdomainname = `dnsdomainname`;
    #chomp($dnsdomainname);
    my $mailfrom = $vhost_conf->get_conf('www_user') . '@' . $hostname;

#if we are specifying a mailto as a vhost configuration variable (such as 'bugs_email'), then use that variable's value, and append the request info.
#mailto can also be specified normally (such as 'John Binns <zombieite@gmail.com>').
    if ( $mailto and eval{ $vhost_conf->get_conf($mailto)} ) {
        $mailto = $vhost_conf->get_conf($mailto);
        ##$request_info .= CXGN::Apache::Request::as_verbose_string();
    }

#if we have no one specified to mail to, send it to bugs, and append the request info.
    unless ($mailto) {
        $mailto = $vhost_conf->get_conf('bugs_email')
          ; #for all emails that do not specify email address, send them to our bugs_email
        ##$request_info .= CXGN::Apache::Request::as_verbose_string()
          ; #append request info to all emails that do not specify email address
    }

    $subject ||= 'No subject specified';
    $body    ||= 'No message body specified';
    $mailto  ||= 'sgn-bugs@sgn.cornell.edu';

    $body .= $request_info;
    print STDERR "$subject\n\n$body";
    if ( $vhost_conf->get_conf('production_server') ) {
        if ( $vhost_conf->get_conf('disable_emails') ) {
            print STDERR
"CXGN::Contact: Configured as production server, but not configured to send emails; no email sent from $mailfrom to $mailto.\n";
        }
        else {
            my %mail = (
                To      => $mailto,
                From    => $mailfrom,
                Subject => $subject,
                Body    => $body,
            );
            $mail{'Reply-To'} = $replyto;
            if ( sendmail(%mail) ) {
                print STDERR
"CXGN::Contact: Email notification sent from $mailfrom to $mailto.\n";
            }
            else {
                print STDERR "CXGN::Contact: UNABLE TO SEND EMAIL NOTIFICATION\n";
            }
        }
    }
    else {
        print STDERR
"CXGN::Contact: Not configured as production server; no email sent from $mailfrom to $mailto.\n";
    }
}


=head1 AUTHOR

john binns - John Binns <zombieite@gmail.com>

=cut

###
1;#do not remove
###

