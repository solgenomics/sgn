package SGN::Controller::AJAX::Report;

use Moose;
use strict;
use warnings;
use JSON; # This stays for API response only
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

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default    => 'application/json',
    stash_key  => 'rest',
    map        => { 'application/json' => 'JSON' }
);


# Convert UI date to SQL timestamp
sub convert_ui_date_to_sql_timestamp {
    my ($ui_date, $is_start) = @_;

    return unless $ui_date;

    if ($ui_date =~ m{^(\d{2})/(\d{2})/(\d{4})$}) {
        my ($dd, $mm, $yyyy) = ($1, $2, $3);
        return "$yyyy-$mm-$dd";
    }

    return;  # Invalid format
}

sub generatereport_POST :Path('generatereport') :Args(0) {
    my ($self, $c) = @_;

    # Check user role
    my @user_roles = $c->user ? $c->user->roles : ();
    my $curator = (grep { $_ eq 'curator' } @user_roles) ? 'curator' : undef;
    my $sp_person_id = $c->user ? $c->user->get_object->get_sp_person_id : undef;
    my $people_schema = $c->dbic_schema("CXGN::People::Schema", undef, $sp_person_id);
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado", $sp_person_id);

    unless ($curator) {
        $c->stash->{rest} = {
            success => JSON::false,
            error   => "This is a curator tool. Please contact the database responsible to generate a report for you.",
        };
        $c->detach;
    }

    # Decode JSON data
    my $data = decode_json($c->req->param('reportData'));
    $c->log->debug("Received report generation data: " . Dumper($data));

    # Extract parameters
    my $dbname          = $c->config->{dbname};
    my $dbhost          = $c->config->{dbhost};
    my $dbuser          = $c->config->{dbuser};
    my $dbpass          = $c->config->{dbpass};
    my $basepath        = $c->config->{basepath};
    my $tempfiles_path  = $c->config->{tempfiles_base};
    my $out_directory   = "$tempfiles_path/reports/";
    my $reports_dir     = '/bin/Reports/';

    my $start_raw      = $data->{start_date}    // '';
    my $end_raw        = $data->{end_date}      // '';

    # Convert dates
    my $start_date = convert_ui_date_to_sql_timestamp($start_raw, 1);
    my $end_date   = convert_ui_date_to_sql_timestamp($end_raw, 0);

    my $emails          = $data->{emails}        // [];
    my $report_scripts  = $data->{report_scripts} // [];

    # Create output directory
    make_path($out_directory);

    my $zip_date = strftime("%Y-%m-%d_%H-%M-%S", localtime);

    my @all_files_to_zip;

    foreach my $script (@$report_scripts) {
        my $script_date = strftime("%Y-%m-%d_%H-%M-%S", localtime);

        # Use a consistent base name for all files
        my $file_basename = "${script}_${script_date}";

        # Build the script command
        my $script_cmd = "perl ${basepath}${reports_dir}${script}.pl "
                       . "-U $dbuser -H $dbhost -P $dbpass -D $dbname "
                       . "-o '$out_directory' -f '$file_basename' "
                       . "-s '$start_date' -e '$end_date'";

        print "Running command: $script_cmd\n";
        system($script_cmd);
        if ($? != 0) {
            die "Report script failed with exit code " . ($? >> 8);
        }

        # Grab all files starting with that basename
        opendir(my $dh, $out_directory) or die "Cannot open directory $out_directory: $!";
        my @matching_files = grep { /^$file_basename/ && -f "$out_directory/$_" } readdir($dh);
        closedir($dh);

        foreach my $f (@matching_files) {
            print "Adding file to zip list: $f\n";
        }

        push @all_files_to_zip, @matching_files;
    }

    # Build zip filename
    my $zip_filename = "report_${zip_date}.zip";
    my $zip_path = $out_directory . $zip_filename;

    # Zip all matching files
    zip_files($out_directory, \@all_files_to_zip, $zip_path);

    print "All files zipped into: $zip_path\n";

    # Send email
    send_report_zip_to_emails($emails, $zip_path, $zip_filename);

    $c->stash->{rest} = {
        success => JSON::true,
        message => "Your request was successfully processed. Please check selected emails for the results.",
    };
}



sub zip_files {
    my ($dir, $filenames, $zip_output_path) = @_;

    my $zip = Archive::Zip->new();

    foreach my $file (@$filenames) {
        my $full_path = File::Spec->catfile($dir, $file);
        unless (-e $full_path) {
            warn "File not found, skipping: $full_path";
            next;
        }
        my $member = $zip->addFile($full_path, $file);
        unless ($member) {
            warn "Could not add $file to zip";
        }
    }

    unless ($zip->writeToFileNamed($zip_output_path) == AZ_OK) {
        die "Failed to write zip archive to $zip_output_path";
    }

    print STDERR "ZIP archive created: $zip_output_path\n";
    return $zip_output_path;
}


sub send_report_zip_to_emails {
    my ($emails_ref, $zip_file_path, $report_name) = @_;

    return unless $zip_file_path && -e $zip_file_path;
    return unless $emails_ref && ref($emails_ref) eq 'ARRAY';

    foreach my $email (@$emails_ref) {
        next unless $email;

        my $subject = "Breedbase Report: $report_name";
        my $body    = "Dear user,\n\nAttached is your generated report ZIP file: $report_name\n\nBest regards,\nThe Breedbase Team";

        CXGN::Contact::send_email($subject, $body, $email, 'noreply@breedbase.org', $zip_file_path);
        print STDERR "Sent report ZIP to: $email\n";
    }
}

1;
