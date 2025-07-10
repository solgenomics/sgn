package SGN::Controller::AJAX::Report;

use Moose;
use strict;
use warnings;
use JSON; # For API response only
use File::Slurp;
use Path::Tiny;
use File::Path qw(make_path);
use File::Spec;
use Data::Dumper;
use CXGN::Tools::Run;
use CXGN::Job;
use Excel::Writer::XLSX;
use POSIX qw(strftime);
use Archive::Zip qw(:ERROR_CODES :CONSTANTS);
use CXGN::Contact;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' }
);

# Convert UI date to SQL timestamp
sub convert_ui_date_to_sql_timestamp {
    my ($ui_date, $is_start) = @_;
    return unless $ui_date;

    if ($ui_date =~ m{^(\d{2})/(\d{2})/(\d{4})$}) {
        my ($dd, $mm, $yyyy) = ($1, $2, $3);
        return "$yyyy-$mm-$dd";
    }

    return; # Invalid format
}

sub generatereport_POST :Path('generatereport') :Args(0) {
    my ($self, $c) = @_;

    # Check role
    my @user_roles = $c->user ? $c->user->roles : ();
    my $curator = (grep { $_ eq 'curator' } @user_roles) ? 'curator' : undef;
    unless ($curator) {
        $c->stash->{rest} = {
            success => JSON::false,
            error   => "This is a curator tool. Please contact the database responsible to generate a report for you.",
        };
        $c->detach;
    }

    my $sp_person_id = $c->user ? $c->user->get_object->get_sp_person_id : undef;
    my $people_schema = $c->dbic_schema("CXGN::People::Schema", undef, $sp_person_id);
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado", $sp_person_id);

    my $data = decode_json($c->req->param('reportData'));

    my $dbname          = $c->config->{dbname};
    my $dbhost          = $c->config->{dbhost};
    my $dbuser          = $c->config->{dbuser};
    my $dbpass          = $c->config->{dbpass};
    my $basepath        = $c->config->{basepath};
    my $tempfiles_path  = $c->config->{tempfiles_base};
    my $out_directory   = "$tempfiles_path/reports/";
    my $reports_dir     = '/bin/Reports/';

    my $start_raw = $data->{start_date} // '';
    my $end_raw   = $data->{end_date}   // '';

    my $start_date = convert_ui_date_to_sql_timestamp($start_raw, 1);
    my $end_date   = convert_ui_date_to_sql_timestamp($end_raw, 0);

    my $emails = join(",", @{ $data->{emails} // [] });
    my $report_scripts = $data->{report_scripts} // [];

    make_path($out_directory);

    foreach my $script (@$report_scripts) {
        my $script_date = strftime("%Y-%m-%d_%H-%M-%S", localtime);
        my $file_basename = "${script}_${script_date}";

        my $script_cmd = "perl ${basepath}${reports_dir}${script}.pl "
            . "-U $dbuser -H $dbhost -P $dbpass -D $dbname "
            . "-o '$out_directory' -f '$file_basename' "
            . "-s '$start_date' -e '$end_date'";

        my $pid = fork();
        if (!defined $pid) {
            die "Cannot fork: $!";
        }
        elsif ($pid == 0) {
            # Child process
            print STDERR "Child PID $$ started for report: $file_basename\n";

            my $report_job_record = CXGN::Job->new({
                schema => $schema,
                people_schema => $people_schema,
                sp_person_id => $sp_person_id,
                name => $file_basename." report generation",
                cmd => $script_cmd,
                job_type => 'report',
                finish_logfile => $c->config->{job_finish_log}
            });

            # Start or enqueue the job
            print("Starting command $script_cmd \n");
            print("Files directory $out_directory \n");
            
            system($script_cmd);
            $report_job_record->update_status("submitted");
            
            my $exit_code = $? >> 8;

            opendir(my $dh, $out_directory) or die "Cannot open dir $out_directory: $!";
            my @files = grep { /^$file_basename/ && -f "$out_directory/$_" } readdir($dh);
            closedir($dh);

            if ($exit_code != 0) {
                $report_job_record->update_status("failed");
                foreach my $to (split /,/, $emails) {
                    CXGN::Contact::send_email(
                        "Report FAILED: $file_basename",
                        "Dear user,\n\nThe report failed.\nExit code: $exit_code\n\n",
                        $to,
                        'noreply@breedbase.org'
                    );
                    print STDERR "Sent failure notice to: $to\n";
                }
                exit(1);
            }
            
            $report_job_record->update_status("finished");
            
            my $zip_filename = "$file_basename.zip";
            my $zip_path = "$out_directory/$zip_filename";
            my $zip = Archive::Zip->new();
            $zip->addFile("$out_directory/$_", $_) for @files;
            unless ($zip->writeToFileNamed($zip_path) == AZ_OK) {
                foreach my $to (split /,/, $emails) {
                    CXGN::Contact::send_email(
                        "Report FAILED: $file_basename",
                        "Dear user,\n\nThe report was generated but creating the ZIP archive failed.\n",
                        $to,
                        'noreply@breedbase.org'
                    );
                    print STDERR "Sent failure notice to: $to\n";
                }
                exit(1);
            }

            foreach my $to (split /,/, $emails) {
                my $subject = "Report ready: $file_basename";
                my $body    = "Dear user,\n\nAttached is your generated report.\n\nBest regards,\nThe Breedbase Team";

                CXGN::Contact::send_email($subject, $body, $to, 'noreply@breedbase.org', $zip_path);
                print STDERR "Sent report ZIP to: $to\n";
            }

            exit(0);
        }
        # Parent continues
    }

    # Respond immediately
    $c->stash->{rest} = {
        success => JSON::true,
        message => "Your report(s) are being generated and will be emailed when ready. Feel free to navigate to other pages!",
    };
}

1;
