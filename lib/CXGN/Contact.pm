
=head1 NAME

CXGN::Contact

=head1 DESCRIPTION

Allows scripts to send emails to the development team.

=head1 FUNCTIONS

=cut

package CXGN::Contact;
use strict;

use Mail::Sendmail;
use Email::Send::SMTP::Gmail;

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
    my @main_production_site_url = split "\:\/\/", $vhost_conf->get_conf('main_production_site_url');
    my $hostname = $main_production_site_url[1];
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
    #if ( $vhost_conf->get_conf('production_server') ) {
        if ( $vhost_conf->get_conf('disable_emails') ) {
            print STDERR "CXGN::Contact: Configured as production server, but not configured to send emails; no email sent from $mailfrom to $mailto.\n";
        }
        else {
            my $smtp_server = $vhost_conf->get_conf('smtp_server');
            my $smtp_layer = $vhost_conf->get_conf('smtp_layer');
            my $smtp_port = $vhost_conf->get_conf('smtp_port');
            my $smtp_login = $vhost_conf->get_conf('smtp_login');
            my $smtp_pass = $vhost_conf->get_conf('smtp_pass');
            my $smtp_auth = $vhost_conf->get_conf('smtp_auth');
            my $smtp_from = $vhost_conf->get_conf('smtp_from') || $mailfrom;

            # If SMTP config values are found use external SMTP server
            if ( $smtp_server and $smtp_login and $smtp_pass ) {

              my ($mail,$error) = Email::Send::SMTP::Gmail->new(
                  -smtp  => $smtp_server,
                  -layer => $smtp_layer,
                  -port  => $smtp_port,
                  -login => $smtp_login,
                  -pass  => $smtp_pass,
                  -auth  => $smtp_auth
              );

              if ($mail == -1) {
                print STDERR "CXGN::Contact: SMTP error: $error\n";
              };

              $mail->send(
                  -from       => $smtp_from,
                  -to         => $mailto,
                  -subject    => $subject,
                  -body       => $body
              );

            } elsif ( $smtp_server ) {

              my ($mail,$error) = Email::Send::SMTP::Gmail->new(
                  -smtp  => $smtp_server,
                  -layer => $smtp_layer,
                  -port  => $smtp_port,
                  -auth  => 'none'
              );

              if ($mail == -1) {
                print STDERR "CXGN::Contact: SMTP error: $error\n";
              };

              $mail->send(
                  -from       => $smtp_from,
                  -to         => $mailto,
                  -subject    => $subject,
                  -body       => $body
              );
              
            } else {

              my %mail = (
                  To      => $mailto,
                  From    => $mailfrom,
                  Subject => $subject,
                  Body    => $body,
              );
              $mail{'Reply-To'} = $replyto;

              if ( sendmail(%mail) ) {
                  print STDERR "CXGN::Contact: Email notification sent from $mailfrom to $mailto.\n";
              }
              else {
                  print STDERR "CXGN::Contact: UNABLE TO SEND EMAIL NOTIFICATION\n";
              }

            }
        }
   # }
    #else {
     #   print STDERR "CXGN::Contact: Not configured as production server; no email sent from $mailfrom to $mailto.\n";
    #}
}


=head1 AUTHOR

john binns - John Binns <zombieite@gmail.com>

=cut

###
1;#do not remove
###
