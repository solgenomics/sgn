#!/usr/bin/perl

=head1

upload_nirs_phenotypes.pl

=head1 SYNOPSIS

upload_nirs_phenotypes.pl -H [dbhost] -D [dbname] -U [dbuser] -P [dbpass] -w [basepath] -ap [archive_path] -tf [tempfiles_subdir] -m [mode] -j [sp_job_id]

=head1 COMMAND-LINE OPTIONS

ARGUMENTS
 -H host name (required) Ex: "breedbase_db"
 -D database name (required) Ex: "breedbase"
 -U database username (required) Ex: "postgres"
 -P database userpass (required) Ex: "postgres"
 -w basepath (required) Ex: /home/production/cxgn/sgn
 -ap archive path (required) Ex: /home/production/volume/archive
 -tf tempfiles subdirectory, relative to the basepath (required) Ex: /static/documents/tempfiles
 -m mode (required), either "verify" to check the file without saving anything, or "store" to save
    its spectra to the database
 -j sp_job_id of the job that submitted this script (required)

=head2 DESCRIPTION

perl bin/upload_nirs_phenotypes.pl -H breedbase_db -D breedbase -U postgres -P postgres -w /home/cxgn/sgn -ap /archive -tf /static/documents/tempfiles -m store -j 17

Reads an already archived NIRS spreadsheet and either checks it or saves the spectra in it.

Either way the spectra are put through the aggregation script first, which averages the repeated
scans of a sample into one spectrum and draws a plot of what it did. The two modes differ in what
happens after that: verifying reports on the aggregated spectra without writing anything, while
storing archives the aggregated file, creates the protocol if the uploader described a new one, and
saves the spectra against it.

Everything that describes the upload -- which file, and the protocol details the uploader filled in
-- is recorded on the submitting job as upload_params before the job is submitted, rather than
being passed as options, since most of it is free text. This script therefore needs a job row that
already exists and cannot be run on its own.

Whatever happened is reported back to the submitting job, so that it reads the same whether the
upload was waited on or left to run in the background. The job also carries the answer the upload
dialog would have been given, so that waiting on the job and running it in the background produce
the same response.

=head1 AUTHOR

Ryan Preble <rsp98@cornell.edu>

=cut

use strict;
use warnings;

use Getopt::Long;
use Pod::Usage;
use Data::Dumper;
use DBI;
use File::Basename;
use File::Path qw | make_path |;
use File::Temp qw | tempfile |;
use JSON;
use Try::Tiny;

use Bio::Chado::Schema;
use CXGN::BreederSearch;
use CXGN::DB::InsertDBH;
use CXGN::Job;
use CXGN::Metadata::Schema;
use CXGN::People::Schema;
use CXGN::Phenome::Schema;
use CXGN::Phenotypes::ParseUpload;
use CXGN::Phenotypes::StorePhenotypes;
use CXGN::UploadFile;
use SGN::Model::Cvterm;
use SGN::ScriptContext;

my ( $help, $dbhost, $dbname, $dbuser, $dbpass, $basepath, $archive_path, $tempfiles_subdir, $mode, $sp_job_id );
GetOptions(
    'dbhost|H=s'        => \$dbhost,
    'dbname|D=s'        => \$dbname,
    'dbuser|U=s'        => \$dbuser,
    'dbpass|P=s'        => \$dbpass,
    'basepath|w=s'      => \$basepath,
    'archive_path|ap=s' => \$archive_path,
    'tempfiles|tf=s'    => \$tempfiles_subdir,
    'mode|m=s'          => \$mode,
    'jobid|j=s'         => \$sp_job_id,
    'help'              => \$help,
);
pod2usage(1) if $help;
if (!$basepath || !$dbname || !$dbhost || !$archive_path || !$tempfiles_subdir || !$mode || !defined($sp_job_id)) {
    pod2usage({ -msg => 'Error. Missing options!', -verbose => 1, -exitval => 1 });
}
if ($mode ne 'verify' && $mode ne 'store') {
    pod2usage({ -msg => "Error. Unknown mode $mode! Use verify or store.", -verbose => 1, -exitval => 1 });
}

# Connect to databases. Everything shares one handle so that the spectra, the protocol they were
# read against and the metadata recorded about the file are written in the same transaction.
my $dbh;
if ($dbpass && $dbuser) {
    $dbh = DBI->connect(
        "dbi:Pg:database=$dbname;host=$dbhost",
        $dbuser,
        $dbpass,
        {AutoCommit => 1, RaiseError => 1}
    );
}
else {
    $dbh = CXGN::DB::InsertDBH->new({
        dbhost => $dbhost,
        dbname => $dbname,
        dbargs => {AutoCommit => 1, RaiseError => 1}
    });
}

my $chado_schema = Bio::Chado::Schema->connect( sub { $dbh }, { on_connect_do => ['SET search_path TO public, sgn, metadata, phenome;'] } );
my $metadata_schema = CXGN::Metadata::Schema->connect( sub { $dbh }, { on_connect_do => ['SET search_path TO public, metadata;'] } );
my $phenome_schema = CXGN::Phenome::Schema->connect( sub { $dbh }, { on_connect_do => ['SET search_path TO public, phenome;'] } );
my $people_schema = CXGN::People::Schema->connect( sub { $dbh }, { on_connect_do => ['SET search_path TO public, sgn, sgn_people;'] } );

my $validate_type = "spreadsheet nirs";
my $metadata_file_type = "nirs spreadsheet";
my $subdirectory = "spreadsheet_phenotype_upload";

my @success_status;
my @warning_status;
my @error_status;

# Where the plot of the spectra was written, as a path the browser can ask for.
my $figure;

# The answer the upload dialog is given. Every way out of this script sets it, so that a dialog
# waiting on the job reads exactly what it used to read when the upload ran in the request.
my $result;

# What this upload is: which file, and the protocol details the uploader filled in. Read off the
# submitting job rather than passed as options.
my $params;
my $context;

# Any uncaught failure below would otherwise leave the job looking successful, because the finish
# timestamp is recorded whether or not this script exits cleanly.
try {
    $params = upload_params();

    # Archiving happened before this script started, and what it had to say belongs in front of
    # whatever this script has to add.
    @success_status = @{$params->{success_messages} || []};

    # Parsing was written to run inside a web request and ask the Catalyst context for site
    # settings. This is a shim for that.
    $context = SGN::ScriptContext->new({
        basepath => $basepath,
        username => $params->{user_name},
        schemas => {
            'Bio::Chado::Schema' => $chado_schema,
            'CXGN::Metadata::Schema' => $metadata_schema,
            'CXGN::Phenome::Schema' => $phenome_schema,
            'CXGN::People::Schema' => $people_schema
        }
    });

    upload_nirs_phenotypes();
} catch {
    push @error_status, $_;
    $result = { success => \@success_status, error => \@error_status };
};

finish();

=head2 upload_params()

Reads what this script is to upload off the submitting job. Dies if it is not there, since there is
nothing to upload without it.

=cut

sub upload_params {
    my $job = CXGN::Job->new({
        sp_job_id => $sp_job_id,
        schema => $chado_schema,
        people_schema => $people_schema
    });

    my $job_args = $job->additional_args() || {};
    my $upload_params = $job_args->{upload_params};
    if (!$upload_params) {
        die "Job $sp_job_id does not describe a NIRS upload.\n";
    }

    return $upload_params;
}

=head2 upload_nirs_phenotypes()

Reads the uploaded spreadsheet, aggregates the spectra in it, and then either checks the result or
saves it, depending on the mode.

=cut

sub upload_nirs_phenotypes {
    my $file_path = $params->{archived_filename};
    my $upload_original_name = $params->{upload_original_name};

    my $parser = CXGN::Phenotypes::ParseUpload->new();

    my $parsed_data = validate_and_parse($parser, $file_path, $upload_original_name);
    if (!$parsed_data) {
        return;
    }

    my $output_csv_filepath = run_filter_aggregate($parsed_data);

    if ($mode eq 'verify') {
        verify_nirs_phenotypes($parser, $file_path, $output_csv_filepath);
    } else {
        store_nirs_phenotypes($parser, $file_path, $output_csv_filepath);
    }
}

=head2 validate_and_parse($parser, $file_path, $upload_original_name)

Checks the uploaded spreadsheet and reads it. Returns the spectra it holds, or nothing if the file
could not be used, in which case what was wrong with it has already been recorded.

=cut

sub validate_and_parse {
    my $parser = shift;
    my $file_path = shift;
    my $upload_original_name = shift;

    my $validate_file = $parser->validate($validate_type, $file_path, undef, $params->{data_level}, $chado_schema, undef, $params->{protocol_id}, undef);
    if (!$validate_file) {
        abort("Archived file not valid: $upload_original_name.");
        return;
    }
    if ($validate_file == 1) {
        push @success_status, "File valid: $upload_original_name.";
    } else {
        abort($validate_file->{'error'});
        return;
    }

    my $parsed_file = $parser->parse($validate_type, $file_path, undef, $params->{data_level}, $chado_schema, undef, $params->{user_id}, $context, $params->{protocol_id}, undef);
    if (!$parsed_file) {
        abort("Error parsing file $upload_original_name.");
        return;
    }
    if ($parsed_file->{'error'}) {
        abort($parsed_file->{'error'});
        return;
    }

    push @success_status, "File data successfully parsed.";

    return $parsed_file->{'data'};
}

=head2 run_filter_aggregate($parsed_data)

Puts the spectra through the aggregation script, which averages the repeated scans of each sample
into a single spectrum, writes the result out as a CSV and draws a plot of it. Returns the CSV.

=cut

sub run_filter_aggregate {
    my $parsed_data = shift;

    my @filter_input;
    while (my ($stock_name, $o) = each %$parsed_data) {
        my $device_id = $o->{nirs}->{device_id};
        my $comments = $o->{nirs}->{comments};
        my $spectras = $o->{nirs}->{spectra};
        foreach my $spectra (@$spectras) {
            push @filter_input, {
                "observationUnitId" => $stock_name,
                "device_type" => $params->{protocol_device_type},
                "nirs_spectra" => $spectra,
            };
        }
    }

    my $tempfile_uri = tempfile_uri('nirs_files', 'fileXXXX');
    my $filter_json_filepath = $basepath.$tempfile_uri."_input_json";
    my $output_csv_filepath = $basepath.$tempfile_uri."_output.csv";
    my $output_raw_csv_filepath = $basepath.$tempfile_uri."_output_raw.csv";
    my $output_outliers_filepath = $basepath.$tempfile_uri."_output_outliers.csv";

    # Storing names its plot from a temporary name of its own rather than sharing the one the
    # aggregation files are named from.
    my $plot_uri = $mode eq 'store' ? tempfile_uri('nirs_files', 'fileXXXX') : $tempfile_uri;
    $figure = $plot_uri."_output_plot.png";
    my $output_plot_filepath = $basepath.$figure;

    my $json = JSON->new->utf8->canonical();
    my $filter_data_input_json = $json->encode(\@filter_input);
    open(my $F, '>', $filter_json_filepath);
        print STDERR Dumper $filter_json_filepath;
        print $F $filter_data_input_json;
    close($F);

    my $cmd_s = "Rscript ".$basepath."/R/Nirs/nirs_upload_filter_aggregate.R '$filter_json_filepath' '$output_csv_filepath' '$output_raw_csv_filepath' '$output_plot_filepath' '$output_outliers_filepath' ";
    print STDERR $cmd_s;
    my $cmd_status = system($cmd_s);

    return $output_csv_filepath;
}

=head2 verify_nirs_phenotypes($parser, $file_path, $output_csv_filepath)

Checks the aggregated spectra against the database without storing any of them.

=cut

sub verify_nirs_phenotypes {
    my $parser = shift;
    my $file_path = shift;
    my $output_csv_filepath = shift;

    my $parsed_file_agg = $parser->parse($validate_type, $output_csv_filepath, undef, $params->{data_level}, $chado_schema, undef, $params->{user_id}, $context, $params->{protocol_id}, undef);
    if (!$parsed_file_agg) {
        abort("Error parsing aggregated file.");
        return;
    }
    if ($parsed_file_agg->{'error'}) {
        abort($parsed_file_agg->{'error'});
        return;
    }
    my %parsed_data_agg = %{$parsed_file_agg->{'data'}};
    my @plots_agg = @{$parsed_file_agg->{'units'}};
    push @success_status, "Aggregated file data successfully parsed.";

    my %phenotype_metadata = (
        archived_file => $file_path,
        archived_file_id => $params->{archived_file_id},
        archived_file_type => $metadata_file_type,
        operator => $params->{user_name},
        date => $params->{timestamp}
    );

    my $store_phenotypes = build_store_phenotypes(\@plots_agg, \%parsed_data_agg, \%phenotype_metadata, 0);

    my ($verified_warning, $verified_error) = $store_phenotypes->verify();
    if ($verified_error) {
        abort($verified_error);
        return;
    }
    if ($verified_warning) {
        push @warning_status, $verified_warning;
    }
    push @success_status, "Aggregated file data verified. Plot names and trait names are valid.";

    $result = { success => \@success_status, warning => \@warning_status, error => \@error_status, figure => $figure };
}

=head2 store_nirs_phenotypes($parser, $file_path, $output_csv_filepath)

Archives the aggregated spectra and saves them to the database, creating the protocol they were read
against if the uploader described a new one.

=cut

sub store_nirs_phenotypes {
    my $parser = shift;
    my $file_path = shift;
    my $output_csv_filepath = shift;

    my $agg_file_name = basename($output_csv_filepath);

    my $uploader_agg = CXGN::UploadFile->new({
        tempfile => $output_csv_filepath,
        subdirectory => $subdirectory,
        archive_path => $archive_path,
        archive_filename => $agg_file_name,
        timestamp => $params->{timestamp},
        user_id => $params->{user_id},
        user_role => $params->{user_role},
        file_type => 'nirs',
        metadata_schema => $metadata_schema
    });
    my (undef, $archived_agg_filename_with_path) = $uploader_agg->archive();
    my $md5_agg = $uploader_agg->get_md5($archived_agg_filename_with_path);
    if (!$archived_agg_filename_with_path) {
        abort("Could not save file $agg_file_name in archive.");
        return;
    } else {
        push @success_status, "File $agg_file_name saved in archive.";
    }
    unlink $output_csv_filepath;

    # Using aggregated spectra:
    my $parsed_file_agg = $parser->parse($validate_type, $archived_agg_filename_with_path, undef, $params->{data_level}, $chado_schema, undef, $params->{user_id}, $context, $params->{protocol_id}, undef);
    if (!$parsed_file_agg) {
        abort("Error parsing aggregated file.");
        return;
    }
    if ($parsed_file_agg->{'error'}) {
        abort($parsed_file_agg->{'error'});
        return;
    }
    my %parsed_data_agg = %{$parsed_file_agg->{'data'}};
    my @plots_agg = @{$parsed_file_agg->{'units'}};
    my @wavelengths_agg = @{$parsed_file_agg->{'variables'}};
    push @success_status, "Aggregated file data successfully parsed.";

    my $protocol_id = $params->{protocol_id};
    if (!$protocol_id) {
        $protocol_id = create_protocol(\@wavelengths_agg);
    }

    my %parsed_data_agg_coalesced;
    while (my ($stock_name, $o) = each %parsed_data_agg) {
        my $device_id = $o->{nirs}->{device_id};
        my $comments = $o->{nirs}->{comments};
        my $spectras = $o->{nirs}->{spectra};
        $parsed_data_agg_coalesced{$stock_name}->{nirs}->{protocol_id} = $protocol_id;
        $parsed_data_agg_coalesced{$stock_name}->{nirs}->{device_type} = $params->{protocol_device_type};
        $parsed_data_agg_coalesced{$stock_name}->{nirs}->{device_id} = $device_id;
        $parsed_data_agg_coalesced{$stock_name}->{nirs}->{comments} = $comments;
        $parsed_data_agg_coalesced{$stock_name}->{nirs}->{spectra} = $spectras->[0];
    }

    my %phenotype_metadata = (
        archived_file => $archived_agg_filename_with_path,
        archived_file_type => $metadata_file_type,
        operator => $params->{user_name},
        date => $params->{timestamp}
    );

    my $store_phenotypes = build_store_phenotypes(\@plots_agg, \%parsed_data_agg_coalesced, \%phenotype_metadata, 1);

    my ($verified_warning, $verified_error) = $store_phenotypes->verify();
    if ($verified_error) {
        abort($verified_error);
        return;
    }
    if ($verified_warning) {
        push @warning_status, $verified_warning;
    }
    push @success_status, "Aggregated file data verified. Plot names and trait names are valid.";

    my ($stored_phenotype_error, $stored_phenotype_success) = $store_phenotypes->store();
    if ($stored_phenotype_error) {
        abort($stored_phenotype_error);
        return;
    }
    if ($stored_phenotype_success) {
        push @success_status, $stored_phenotype_success;
    }

    push @success_status, "Metadata saved for archived file.";
    my $bs = CXGN::BreederSearch->new( { dbh=>$dbh, dbname=>$dbname, } );
    my $refresh = $bs->refresh_matviews($dbhost, $dbname, $dbuser, $dbpass, 'fullview', 'concurrent', $basepath);

    $result = { success => \@success_status, warning => \@warning_status, error => \@error_status, figure => $figure, nd_protocol_id => $protocol_id };
}

=head2 create_protocol($wavelengths)

Saves the protocol the uploader described, and returns its id. The wavelengths the file turned out
to hold are recorded on it, so that later uploads can be checked against them.

=cut

sub create_protocol {
    my $wavelengths = shift;

    my $high_dim_nirs_protocol_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'high_dimensional_phenotype_nirs_protocol', 'protocol_type')->cvterm_id();
    my $high_dim_nirs_protocol_prop_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'high_dimensional_phenotype_protocol_properties', 'protocol_property')->cvterm_id();

    my %nirs_protocol_prop = (
        device_type => $params->{protocol_device_type},
        header_column_names => $wavelengths,
        header_column_details => {}
    );

    my $protocol = $chado_schema->resultset('NaturalDiversity::NdProtocol')->create({
        name => $params->{protocol_name},
        type_id => $high_dim_nirs_protocol_cvterm_id,
        nd_protocolprops => [{type_id => $high_dim_nirs_protocol_prop_cvterm_id, value => encode_json \%nirs_protocol_prop}]
    });
    my $protocol_id = $protocol->nd_protocol_id();

    my $desc_q = "UPDATE nd_protocol SET description=? WHERE nd_protocol_id=?;";
    my $sth = $chado_schema->storage->dbh()->prepare($desc_q);
    $sth->execute($params->{protocol_desc}, $protocol_id);

    return $protocol_id;
}

=head2 build_store_phenotypes($plots, $values, $phenotype_metadata, $for_storing)

Builds the object that checks and saves the spectra. Checking a file does not need to know what the
uploader chose to do about values that are already stored, so that is only set when the spectra are
actually being saved.

=cut

sub build_store_phenotypes {
    my $plots = shift;
    my $values = shift;
    my $phenotype_metadata = shift;
    my $for_storing = shift;

    my %args = (
        basepath=>$basepath,
        dbhost=>$dbhost,
        dbname=>$dbname,
        dbuser=>$dbuser,
        dbpass=>$dbpass,
        temp_file_nd_experiment_id=>nd_experiment_tempfile(),
        bcs_schema=>$chado_schema,
        metadata_schema=>$metadata_schema,
        phenome_schema=>$phenome_schema,
        user_id=>$params->{user_id},
        stock_list=>$plots,
        trait_list=>[],
        values_hash=>$values,
        has_timestamps=>0,
        metadata_hash=>$phenotype_metadata,
        composable_validation_check_name=>$context->config->{composable_validation_check_name}
    );

    if ($for_storing) {
        $args{allow_repeat_measures} = $context->config->{allow_repeat_measures};
    }

    return CXGN::Phenotypes::StorePhenotypes->new(\%args);
}

=head2 nd_experiment_tempfile()

Returns a file for recording the experiment ids that have to be cleaned up if storing goes wrong
partway through.

=cut

sub nd_experiment_tempfile {
    return $basepath.tempfile_uri('delete_nd_experiment_ids', 'fileXXXX');
}

=head2 tempfile_uri($subdirectory, $template)

Returns a new temporary file as a path relative to the site root, which is what the site hands to a
browser for anything it is expected to fetch back. Prefixing the basepath to it gives the file on
disk. The subdirectory is created if this is the first upload to need it.

=cut

sub tempfile_uri {
    my $subdirectory = shift;
    my $template = shift;

    my $dir = "$basepath$tempfiles_subdir/$subdirectory";
    if (! -d $dir) {
        make_path($dir);
        hand_dir_to_web_server($dir);
    }
    my (undef, $tempfile) = tempfile("$dir/$template");

    return "$tempfiles_subdir/$subdirectory/".basename($tempfile);
}

=head2 hand_dir_to_web_server($dir)

Gives a newly created temporary directory to the web server group, the same way the site does when
it makes one of these itself. The plot of the spectra is written in one of them and then fetched
back by the browser, so a directory this script kept to itself would leave the upload looking like
it worked with nothing to show for it.

=cut

sub hand_dir_to_web_server {
    my $dir = shift;

    # Sticky group bit, so that what the site writes in here afterwards stays in the same group.
    chmod 02775, $dir;

    # Only root can give a directory away, and a site whose jobs already run as the web user has
    # nothing to do here.
    if ($< != 0) {
        return;
    }

    my $www_uid = (getpwnam($context->config->{www_user} || ''))[2];
    my $www_gid = (getgrnam($context->config->{www_group} || ''))[2];
    if (defined $www_uid && defined $www_gid) {
        chown $www_uid, $www_gid, $dir;
    }
}

=head2 abort($message)

Records why the upload cannot go on, and the answer the upload dialog gets when it does not. What
was collected before things went wrong is reported along with it, the same way it used to be.

=cut

sub abort {
    my $message = shift;

    if (defined $message) {
        push @error_status, $message;
    }
    $result = { success => \@success_status, error => \@error_status };
}

=head2 finish()

Reports what happened back to the submitting job and exits.

A file that raised warnings has not been dealt with yet, even though nothing actually went wrong
with it, so the job is left failed until the uploader either fixes the file or says to go ahead
anyway. Only errors are treated as failures once they have.

=cut

sub finish {
    foreach (@success_status) {
        print STDOUT "SUCCESS: $_\n";
    }
    foreach (@warning_status) {
        print STDERR "WARNING: $_\n";
    }
    foreach (@error_status) {
        print STDERR "ERROR: $_\n";
    }

    my $failed = scalar(@error_status) > 0 || (scalar(@warning_status) > 0 && !$params->{ignore_warnings});

    try {
        my $job = CXGN::Job->new({
            sp_job_id => $sp_job_id,
            schema => $chado_schema,
            people_schema => $people_schema
        });

        if (!$job->additional_args()) {
            $job->additional_args({});
        }

        if ($result) {
            $job->additional_args->{result} = $result;
        }
        if (scalar(@success_status) > 0) {
            $job->additional_args->{success_messages} = join("<br>", @success_status);
        }
        if (scalar(@warning_status) > 0) {
            $job->additional_args->{warning_messages} = join("<br>", @warning_status);
        }
        if (scalar(@error_status) > 0) {
            $job->additional_args->{error_messages} = join("<br>", @error_status);
        }

        $job->update_status($failed ? "failed" : "finished");
    } catch {
        print STDERR "Could not report the results of this upload to job $sp_job_id: $_\n";
    };

    exit(scalar(@error_status) > 0 ? 1 : 0);
}

1;
