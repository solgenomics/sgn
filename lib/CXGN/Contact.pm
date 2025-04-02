package CXGN::Contact;

use strict;
use warnings;

use Mail::Sendmail;
use Email::Send::SMTP::Gmail;
use Data::Dumper;

use CXGN::Apache::Request;
use CXGN::Tools::Text;
use SGN::Context;

=head1 AUTHOR

john binns - John Binns <zombieite@gmail.com>

=cut

=head2 send_email

  Usage:
  CXGN::Contact::send_email($subject, $body, $mailto, $replyto, $attachment_file);

  - $subject:         Email subject line
  - $body:            Email body text
  - $mailto:          Email address or SGN config key
  - $replyto:         Optional reply-to address
  - $attachment_file: Optional full path to file to attach (e.g., ZIP file)

=cut

sub send_email {
    my ( $subject, $body, $mailto, $replyto, $attachment_file ) = @_;

    my $request_info = "";
    my $vhost_conf   = SGN::Context->new;

    my @main_production_site_url = split "\:\/\/", $vhost_conf->get_conf('main_production_site_url');
    my $hostname = $main_production_site_url[1];
    chomp($hostname);
    my $mailfrom = $vhost_conf->get_conf('www_user') . '@' . $hostname;

    if ( $mailto and eval { $vhost_conf->get_conf($mailto) } ) {
        $mailto = $vhost_conf->get_conf($mailto);
    }

    unless ($mailto) {
        $mailto = $vhost_conf->get_conf('bugs_email');
    }

    $subject ||= 'No subject specified';
    $body    ||= 'No message body specified';
    $mailto  ||= 'sgn-bugs@sgn.cornell.edu';

    $body .= $request_info;
    print STDERR "$subject\n\n$body";

    if ( $vhost_conf->get_conf('disable_emails') ) {
        print STDERR "CXGN::Contact: Email disabled in config; no email sent from $mailfrom to $mailto.\n";
        return;
    }

    my $smtp_server = $vhost_conf->get_conf('smtp_server');
    my $smtp_layer  = $vhost_conf->get_conf('smtp_layer');
    my $smtp_port   = $vhost_conf->get_conf('smtp_port');
    my $smtp_login  = $vhost_conf->get_conf('smtp_login');
    my $smtp_pass   = $vhost_conf->get_conf('smtp_pass');
    my $smtp_auth   = $vhost_conf->get_conf('smtp_auth');
    my $smtp_from   = $vhost_conf->get_conf('smtp_from') || $mailfrom;

    if ( $smtp_server && $smtp_login && $smtp_pass ) {

        my ($mail, $error) = Email::Send::SMTP::Gmail->new(
            -smtp  => $smtp_server,
            -layer => $smtp_layer,
            -port  => $smtp_port,
            -login => $smtp_login,
            -pass  => $smtp_pass,
            -auth  => $smtp_auth
        );

        if ($mail == -1) {
            print STDERR "CXGN::Contact: SMTP error: $error\n";
            return;
        }

        if ($attachment_file && -e $attachment_file) {
            $mail->send(
                -from        => $smtp_from,
                -to          => $mailto,
                -subject     => $subject,
                -body        => $body,
                -attachments => $attachment_file
            );
        } else {
            $mail->send(
                -from    => $smtp_from,
                -to      => $mailto,
                -subject => $subject,
                -body    => $body
            );
        }

    } elsif ( $smtp_server ) {

        my ($mail, $error) = Email::Send::SMTP::Gmail->new(
            -smtp  => $smtp_server,
            -layer => $smtp_layer,
            -port  => $smtp_port,
            -auth  => 'none'
        );

        if ($mail == -1) {
            print STDERR "CXGN::Contact: SMTP error: $error\n";
            return;
        }

        if ($attachment_file && -e $attachment_file) {
            $mail->send(
                -from        => $smtp_from,
                -to          => $mailto,
                -subject     => $subject,
                -body        => $body,
                -attachments => $attachment_file
            );
        } else {
            $mail->send(
                -from    => $smtp_from,
                -to      => $mailto,
                -subject => $subject,
                -body    => $body
            );
        }

    } else {
        # Local sendmail fallback
        my %mail = (
            To      => $mailto,
            From    => $mailfrom,
            Subject => $subject,
            Body    => $body,
        );

        $mail{'Reply-To'} = $replyto if $replyto;

        if ($attachment_file && -e $attachment_file) {
            $mail{content_type} = 'multipart/mixed';
            $mail{body} = {
                text => $body,
                file => $attachment_file,
            };
        }

        print STDERR "MAIL = " . Dumper(\%mail);

        if ( sendmail(%mail) ) {
            print STDERR "CXGN::Contact: Email notification sent from $mailfrom to $mailto.\n";
        } else {
            print STDERR "CXGN::Contact: UNABLE TO SEND EMAIL NOTIFICATION\n";
        }
    }
}


1;
