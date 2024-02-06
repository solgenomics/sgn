package trial Data:: upload
use MooseX;
use namespace::autoclean;
use DateTime;
use strict;
use warnings;
use Data::Dumper;
use Email::Sender::Simple qw /sendmail/;
use Email::Simple;
use Email::Simple::Creator;
use JSON::XS;
use Storable qW/ nstore retrieve /;

with 'MooseX::Getopt';
with 'Moosex::Runnable';

has 'output_detials_file' => (
    is => 'ro',
    isa => 'Str',
    required => 1,
    documentation => 'The output details file',
);

sub upload_status {
    my ( $self, $trial_upload) = @_;

    my $args = $trial_upload->{ }->{arguments};
    my $json = JSON::XS->new();
    $args = $json->decode($args);
    my $first_name = $args->{first_name};

    my $trial_upload_status = $self->email_body($trial_upload);
    my $closing =
        "If you have any concerns or questions, please contact us:\n"
        . $trial_upload->{contact_page} . "\n\n"
        . "Thank you,\n"

    my $body = "Dear $first_name,\n\n"
        . $trial_upload_status
        . $closing;

    my $email_adds = $self->email_adds($trial_upload);
    my $analysis = $trial_upload->{analysis};

    my $email = Email::Simple->create(
        header => [
            From    => $email_adds->{email_from},
            To      => $email_adds->{email_to},
            cc      => $email_adds->{email_cc},
            Subject => "Trial Upload Status: $analysis",
        ],
        body => $body,
    );

    sendmail($email);

}

sub email_addresses {
    my ( $self, $trial_upload ) = @_;

    my $trial_upload_status = $output_details -> {analysis_profile}->{arguments};
    my $json = JSON::XS->new();
    $trial_upload_status = $json->decode($trial_upload_status);
    my $first_name = $trial_upload_status->{first_name};

    my $user_email = $trial_upload_status->{user_email};
    my $user_name = $trial_upload_status->{user_name};  

    my $email_from;
    my $email_to;
    my $email_cc;

    if ( $trial_upload_status->{host} =~ /localhost/) {
        my $uid = getpwuid($<);
        $email_from = $uid . '@localhost.localdomain>';
        $email_to = $uid . '@localhost.localdomain>';
    }
    else {
        my $mail_list   = $trial_upload_status ->{mailing_list};
        $email_from     = 'trial upload <' . $mail_list . '>';
        $email_cc       = 'trial upload <' . $mail_list . '>';
        $email_to       = $user_name . '<' . $user_email . '>';

    }

    return {    
        email_from  => $email_from,
        email_to    => $email_to,
        email_cc    => $email_cc,
    } 

}     
 
sub email_body {
        my ( $self, $trial_upload ) = @_;

        my $trial_upload_status = $output_details -> {analysis_profile};
        my $trial_upload_status = $trial_upload_status->{analysis_type};

        my $msg;

        if ( $analysis_type =~ /single_trial_uplaod/ ) {
            $msg =  $self->single_trial_uplaod($output_details);
        }
        elsif ( $analysis_type =~ /multi_trial_uplaod/ ) {
            $msg =  $self->multi_trial_uplaod($output_details);
        }

        return $msg;

    }

sub single_trial_design_message {
    my ($self, $output_details) = @_;

    my $message;

    foreach my $k (keys %{$output_details}) {
        if ($k =~ /single_trial_design/) {

            my $output_page = $output_details->{$k}->{output_page};

            if ($output_details->{$k}->{success}) {

                $message =
                    'Your single trial design is done. You can access the result here:'
                  . "\n\n$output_page\n\n";
            }
            else {
                no warnings 'uninitialized';
                my $fail_message = $output_details->{$k}->{failure_reason};

                $message = "The single trial design failed.\n";
                $message .= "\nPossible causes are:\n$fail_message\n";
                $message .= 'Referring page: ' . $output_page . "\n\n";
                $message .=
"We will troubleshoot the cause and contact you when we find out more.\n\n";
            }
        }
    }

    return $message;
}

sub multiple_trial_design_message {
    my ($self, $output_details) = @_;

    my $message;

    foreach my $k (keys %{$output_details}) {
        if ($k =~ /multiple_trial_design/) {

            my $output_page = $output_details->{$k}->{output_page};

            if ($output_details->{$k}->{success}) {

                $message =
                    'Your multiple trial design is done. You can access the result here:'
                  . "\n\n$output_page\n\n";
            }
            else {
                no warnings 'uninitialized';
                my $fail_message = $output_details->{$k}->{failure_reason};

                $message = "The multiple trial design failed.\n";
                $message .= "\nPossible causes are:\n$fail_message\n";
                $message .= 'Referring page: ' . $output_page . "\n\n";
                $message .=
"We will troubleshoot the cause and contact you when we find out more.\n\n";
            }
        }
    }

    return $message;
}

sub upload_trial_status {
    my ($self, $output_details) = @_;

    my $log_file = $output_details->{trial_log_file};

    my $trial_profile = $output_details->{trial_profile};
    my $trial_name    = $trial_profile->{trial_name};

    my $status = $output_details->{status};

    my @contents = read_file($log_file, { binmode => ':utf8' });
    
    map {
        $contents[$_] =~ m/$trial_name\s+-*/
            ? $contents[$_] =~ s/error|submitted/$status/ig
            : $contents[$_]
    } 0 .. $#contents;

    write_file($log_file, { binmode => ':utf8' }, @contents);
}


sub end_status_check {
    my $self = shift;

    my $end_after = $self->status_check_duration;

    my $now_time = DateTime->now;
    my $dur      = $START_TIME->delta_ms($now_time);

    my $du_mins = $dur->in_units('minutes');
    my $end_process = $dur_mins >= $end_after ? 1 : 0;

    return $end_process;
}

__PACKAGE__->meta->make_immutable;

####
1; #
####