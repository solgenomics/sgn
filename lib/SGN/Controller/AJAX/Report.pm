package SGN::Controller::AJAX::Report;

use Moose;
use strict;
use warnings;
use JSON;
use File::Slurp;
use Path::Tiny;
use File::Path qw(make_path);
use File::Spec;
use Data::Dumper;
use CXGN::Tools::Run;
use CXGN::Job;
use Excel::Writer::XLSX;
use POSIX qw(strftime);
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default    => 'application/json',
    stash_key  => 'rest',
    map        => { 'application/json' => 'JSON' }
);


# Assume $c is available from Catalyst.

sub write_json_to_excel {
    my ($excel_directory, $excel_name, $decoded_json) = @_;
    
    my $full_path = $excel_directory . $excel_name;
    
    # Create a new Excel workbook and add a worksheet.
    my $workbook  = Excel::Writer::XLSX->new($full_path);
    my $worksheet = $workbook->add_worksheet();
    
    # If the decoded JSON is an array of hashes, use its keys as column headers.
    if (ref($decoded_json) eq 'ARRAY' && @$decoded_json) {
        # Get the headers from the first element. You can adjust the order as needed.
        my @headers = sort keys %{ $decoded_json->[0] };
        my $col = 0;
        foreach my $header (@headers) {
            $worksheet->write(0, $col++, $header);
        }
        
        # Write each data row.
        my $row = 1;
        foreach my $row_data (@$decoded_json) {
            $col = 0;
            foreach my $header (@headers) {
                $worksheet->write($row, $col++, $row_data->{$header});
            }
            $row++;
        }
    }
    else {
        # If the structure is not what we expect, write an error message.
        $worksheet->write(0, 0, "No data available or unexpected data structure");
    }
    
    $workbook->close();
    
    return $full_path;
}

sub convert_ui_date_to_sql_timestamp {
    my ($ui_date, $is_start) = @_;

    return unless $ui_date;

    # Match dd/mm/yyyy format
    if ($ui_date =~ m{^(\d{2})/(\d{2})/(\d{4})$}) {
        my ($dd, $mm, $yyyy) = ($1, $2, $3);
        return "$yyyy-$mm-$dd";
    }

    return;  # Invalid format
}





sub generatereport_POST :Path('generatereport') :Args(0) {
    my ($self, $c) = @_;

    ## checking the user role
    my @user_roles = $c->user ? $c->user->roles : ();
    my $curator = (grep { $_ eq 'curator' } @user_roles) ? 'curator' : undef;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $people_schema = $c->dbic_schema("CXGN::People::Schema", undef, $sp_person_id);
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado", $sp_person_id);

    unless ($curator) {
        $c->stash->{rest} = {
            success => JSON::false,
            error   => "This is a curator tool, please contact the datase responsible to generate a report for you",
        };
        $c->detach;
    }


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
    
    # Putting dates in sql format
    my $start_date = convert_ui_date_to_sql_timestamp($start_raw, 1);  # 1 = start of day
    my $end_date   = convert_ui_date_to_sql_timestamp($end_raw,   0);  # 0 = end of day


    my $emails          = $data->{emails}        // [];
    my $report_scripts  = $data->{report_scripts} // [];

    ##Creating directory ###
    make_path($out_directory);

    my @excel_files_to_zip;  # <--- to collect all xlsx files
    my $zip_date = strftime("%Y-%m-%d_%H-%M-%S", localtime);
    
    print Dumper \$report_scripts;
    foreach my $script (@$report_scripts) {
        my $script_date = strftime("%Y-%m-%d_%H-%M-%S", localtime);  # one time

        my $json_filename   = "${script}_${script_date}.json";
        my $excel_filename  = "${script}_${script_date}.xlsx";
        
        my $script_cmd = "perl ${basepath}${reports_dir}${script}.pl -U $dbuser -H $dbhost -P $dbpass -D $dbname -o '$out_directory' -f '$json_filename' -s '$start_date' -e '$end_date'";
        

        # my $report_job = CXGN::Job->new({
        #     schema => $schema,
        #     people_schema => $people_schema,
        #     sp_person_id => $sp_person_id,
        #     name => $json_filename." report generation",
        #     cmd => $script_cmd,
        #     job_type => 'report',
        #     finish_logfile => $c->config->{job_finish_log}
        # });

        # # Start or enqueue the job
        # $report_job->submit();
        
        print "Waiting for JSON file to be generated...\n";
        system($script_cmd);
        if ($? != 0) {
            die "Report script failed with exit code " . ($? >> 8);
        }
        
        print("Starting command $script_cmd \n");
        print("Path to json $out_directory \n");
        print("json file $json_filename \n");
        print("excel file $excel_filename \n");
        
        my $json_file = File::Spec->catfile($out_directory, $json_filename);
        print("Reading output from file: $json_file \n");

        my $json_text = '';
        if (-e $json_file) {
            $json_text = path($json_file)->slurp_utf8;
        } else {
            warn "JSON file $json_file does not exist.";
        }

        my $decoded_json;
        eval {
            $decoded_json = decode_json($json_text);
        };
        if ($@) {
            warn "Failed to decode JSON from script $script: $@";
            $decoded_json = {};
        }

        my $excel_file = write_json_to_excel($out_directory, $excel_filename, $decoded_json);
        push @excel_files_to_zip, $excel_filename;

        print "Excel file created: $excel_file\n";
    }


    my $zip_filename = "report_${zip_date}.zip";
    my $zip_path = $out_directory . $zip_filename;
    zip_excel_reports($out_directory, \@excel_files_to_zip, $zip_path);

    print "All Excel files zipped into: $zip_path\n";

    send_report_zip_to_emails($emails, $zip_path, $zip_filename);
    $c->stash->{rest} = {
        success => JSON::true,
        message => "Your request was successfully processed. Please check selected emails for the results.",
    };
}


sub zip_excel_reports {
    my ($excel_dir, $excel_filenames, $zip_output_path) = @_;

    my $zip = Archive::Zip->new();

    foreach my $file (@$excel_filenames) {
        my $full_path = File::Spec->catfile($excel_dir, $file);
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
        next unless $email;  # skip blank entries

        my $subject = "Breedbase Report: $report_name";
        my $body    = "Dear user,\n\nAttached is your generated report ZIP file: $report_name\n\nBest regards,\nThe Breedbase Team";

        CXGN::Contact::send_email($subject, $body, $email, 'noreply@breedbase.org', $zip_file_path);
        print STDERR "Sent report ZIP to: $email\n";
    }
}


1;
