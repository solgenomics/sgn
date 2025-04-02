package SGN::Controller::AJAX::Report;

use Moose;
use strict;
use warnings;
use File::Slurp 'read_file';
use File::Path qw(make_path);
use JSON qw(decode_json);
use Data::Dumper;
use CXGN::Tools::Run;
use Excel::Writer::XLSX;
use POSIX qw(strftime);

BEGIN { extends 'Catalyst::Controller::REST' };

__PACKAGE__->config(
    default => 'application/json',
    stash_key => 'rest',
    map => { 'application/json' => 'JSON' },
   );

# Assume $c is available from Catalyst.

sub write_json_to_excel {
    my ($excel_directory, $script, $decoded_json) = @_;
    
    # Ensure the directory exists; create if not.
    unless (-d $excel_directory) {
        make_path($excel_directory) or die "Failed to create directory $excel_directory: $!";
    }
    
    # Get current date as YYYY-MM-DD
    my $date_str = strftime("%Y-%m-%d", localtime);
    
    # Build the filename: <script>_<date>.xlsx
    my $filename = $script . "_" . $date_str . ".xlsx";
    my $full_path = $excel_directory . $filename;
    
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

sub generatereport_POST :Path('generatereport') :Args(0) {
    my ($self, $c) = @_;

    # Retrieve the incoming JSON data from the AJAX call
    my $data = $c->req->param('reportData');
    $data = decode_json($data);


    $c->log->debug("Received report generation data: " . Dumper($data));

    # Extract parameters from the JSON payload
    my $dbname    = $c->config->{dbname};
    my $dbhost    = $c->config->{dbhost};
    my $dbuser    = $c->config->{dbuser};
    my $dbpass    = $c->config->{dbpass};
    my $start_date    = $data->{start_date}    // '';
    my $end_date      = $data->{end_date}      // '';
    my $emails        = $data->{emails}        // [];
    my $report_scripts = $data->{report_scripts} // [];
    my $basepath = $c->config->{basepath};
    my $tempfiles_path = $c->config->{tempfiles_base};
    my $excel_directory = $tempfiles_path . "/reports/";

    
    my $reports_dir = '/bin/Reports/';
    my @script_results;
    my $run_script;

    foreach my $script (@$report_scripts) {

        # Build the full script command; pipe the dbuser and dbpass as input.
        my $script_cmd = "script -q /dev/null -c \"perl ${basepath}${reports_dir}${script}.pl -U $dbuser -H $dbhost -P $dbpass -D $dbname\"";
        
        print("Starting command $script_cmd \n");

        # Create a new run object and run the script
        my $run_script = CXGN::Tools::Run->new();
        my $result_hash = $run_script->run($script_cmd);

        my $out_file = $run_script->{out_file};
        print("Reading output from file: $out_file \n");

        my $json_text = '';
        if (-e $out_file) {
            my @lines = read_file($out_file, chomp => 1);

            # Keep only likely JSON lines (start of object/array or key-value lines)
            my @json_lines = grep {
                /^\s*[{[]/         ||   # Opening of JSON object/array
                /^\s*"[^"]+"\s*:/  ||   # JSON key-value line
                /^\s*}[,]?\s*$/    ||   # Closing brace
                /^\s*][,]?\s*$/    ||   # Closing bracket
                /^\s*$/                 # Blank lines (optional)
            } @lines;

            if (!@json_lines) {
                warn "No JSON content found in $out_file for $script.";
            }

            $json_text = join("\n", @json_lines);
        } else {
            warn "Output file $out_file does not exist.";
        }

        # Attempt to decode the JSON from the file's content
        my $decoded_json;
        eval {
            $decoded_json = decode_json($json_text);
        };
        if ($@) {
            warn "Failed to decode JSON from script $script: $@";
            $decoded_json = {};
        }

        # Write the decoded JSON into an Excel file within the specified directory
        my $excel_file = write_json_to_excel($excel_directory, $script, $decoded_json);
        print "Excel file created: $excel_file\n";

        push @script_results, {
            script    => $script,
            output    => $json_text,
            json_data => $decoded_json,
        };
    }



    # Here you can add your logic to generate the report based on the provided data.
    # For demonstration purposes, we simply return the captured data.

    $c->stash->{rest} = {
        success  => JSON::true,
        message  => 'Report generation data received.',
        data     => {
            start_date    => $start_date,
            end_date      => $end_date,
            emails        => $emails,
            report_scripts => $report_scripts,
        },
    };
}


1;
