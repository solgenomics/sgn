#!/usr/bin/perl

=head1

upload_transcriptomics_phenotypes.pl

=head1 SYNOPSIS

upload_transcriptomics_phenotypes.pl -H [dbhost] -D [dbname] -U [dbuser] -P [dbpass] -w [basepath] -ap [archive_path] -tf [tempfiles_subdir] -m [mode] -j [sp_job_id]

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
    its expression values to the database
 -j sp_job_id of the job that submitted this script (required)

=head2 DESCRIPTION

perl bin/upload_transcriptomics_phenotypes.pl -H breedbase_db -D breedbase -U postgres -P postgres -w /home/cxgn/sgn -ap /archive -tf /static/documents/tempfiles -m store -j 17

Reads an already archived transcriptomics spreadsheet, together with the transcript details file
that goes with it, and either checks it or saves the expression values in it.

Both modes read the file the same way. They differ in what happens afterwards: verifying reports on
the values without writing anything, while storing creates the protocol if the uploader described a
new one and saves the values against it.

Everything that describes the upload -- which files, and the protocol details the uploader filled in
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

# Connect to databases. Everything shares one handle so that the expression values, the protocol
# they were read against and the metadata recorded about the file are written in the same
# transaction.
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

my $validate_type = "highdimensionalphenotypes spreadsheet transcriptomics";
my $metadata_file_type = "transcriptomics spreadsheet";

my @success_status;
my @warning_status;
my @error_status;

# The answer the upload dialog is given. Every way out of this script sets it, so that a dialog
# waiting on the job reads exactly what it used to read when the upload ran in the request.
my $result;

# What this upload is: which files, and the protocol details the uploader filled in. Read off the
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

    upload_transcriptomics_phenotypes();
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
        die "Job $sp_job_id does not describe a transcriptomics upload.\n";
    }

    return $upload_params;
}

=head2 upload_transcriptomics_phenotypes()

Reads the uploaded spreadsheet and then either checks the expression values in it or saves them,
depending on the mode.

=cut

sub upload_transcriptomics_phenotypes {
    my $parser = CXGN::Phenotypes::ParseUpload->new();

    my $parsed_file = validate_and_parse($parser);
    if (!$parsed_file) {
        return;
    }

    if ($mode eq 'verify') {
        verify_transcriptomics_phenotypes($parsed_file);
    } else {
        store_transcriptomics_phenotypes($parsed_file);
    }
}

=head2 validate_and_parse($parser)

Checks the uploaded spreadsheet and reads it. Returns what the parser made of it, or nothing if the
file could not be used, in which case what was wrong with it has already been recorded.

=cut

sub validate_and_parse {
    my $parser = shift;

    my $file_path = $params->{archived_filename};
    my $transcripts_file_path = $params->{archived_metadata_filename};
    my $upload_original_name = $params->{upload_original_name};

    my $validate_file = $parser->validate($validate_type, $file_path, undef, $params->{data_level}, $chado_schema, undef, $params->{protocol_id}, $transcripts_file_path);
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

    my $parsed_file = $parser->parse($validate_type, $file_path, undef, $params->{data_level}, $chado_schema, undef, $params->{user_id}, $context, $params->{protocol_id}, $transcripts_file_path);
    if (!$parsed_file) {
        abort("Error parsing file $upload_original_name.");
        return;
    }
    if ($parsed_file->{'error'}) {
        abort($parsed_file->{'error'});
        return;
    }

    push @success_status, "File data successfully parsed.";

    return $parsed_file;
}

=head2 verify_transcriptomics_phenotypes($parsed_file)

Checks the expression values against the database without storing any of them.

=cut

sub verify_transcriptomics_phenotypes {
    my $parsed_file = shift;

    my %parsed_data = %{$parsed_file->{'data'}};
    my @plots = @{$parsed_file->{'units'}};

    my %phenotype_metadata = phenotype_metadata();

    my $store_phenotypes = build_store_phenotypes(\@plots, \%parsed_data, \%phenotype_metadata, 0);

    my ($verified_warning, $verified_error) = $store_phenotypes->verify();
    if ($verified_error) {
        abort($verified_error);
        return;
    }
    if ($verified_warning) {
        push @warning_status, $verified_warning;
    }
    push @success_status, "File data verified. Plot names and trait names are valid.";

    $result = { success => \@success_status, warning => \@warning_status, error => \@error_status };
}

=head2 store_transcriptomics_phenotypes($parsed_file)

Saves the expression values to the database, creating the protocol they were read against if the
uploader described a new one.

=cut

sub store_transcriptomics_phenotypes {
    my $parsed_file = shift;

    my %parsed_data = %{$parsed_file->{'data'}};
    my @plots = @{$parsed_file->{'units'}};
    my @transcripts = @{$parsed_file->{'variables'}};
    my %transcripts_details = %{$parsed_file->{'variables_desc'}};

    my $protocol_id = $params->{protocol_id};
    if (!$protocol_id) {
        $protocol_id = create_protocol(\@transcripts, \%transcripts_details);
    }

    my %parsed_data_agg_coalesced;
    while (my ($stock_name, $o) = each %parsed_data) {
        my $device_id = $o->{transcriptomics}->{device_id};
        my $comments = $o->{transcriptomics}->{comments};
        my $spectras = $o->{transcriptomics}->{transcripts};
        $parsed_data_agg_coalesced{$stock_name}->{transcriptomics} = $spectras->[0];
        $parsed_data_agg_coalesced{$stock_name}->{transcriptomics}->{protocol_id} = $protocol_id;
        $parsed_data_agg_coalesced{$stock_name}->{transcriptomics}->{device_id} = $device_id;
        $parsed_data_agg_coalesced{$stock_name}->{transcriptomics}->{comments} = $comments;
    }

    my %phenotype_metadata = phenotype_metadata();

    my $store_phenotypes = build_store_phenotypes(\@plots, \%parsed_data_agg_coalesced, \%phenotype_metadata, 1);

    my ($verified_warning, $verified_error) = $store_phenotypes->verify();
    if ($verified_error) {
        abort($verified_error);
        return;
    }
    if ($verified_warning) {
        push @warning_status, $verified_warning;
    }
    push @success_status, "File data verified. Plot names and trait names are valid.";

    my ($stored_phenotype_error, $stored_phenotype_success) = $store_phenotypes->store();
    if ($stored_phenotype_error) {
        abort($stored_phenotype_error);
        return;
    }
    if ($stored_phenotype_success) {
        push @success_status, $stored_phenotype_success;
    }

    push @success_status, "Metadata saved for archived file.";
    my $bs = CXGN::BreederSearch->new({ dbh=>$dbh, dbname=>$dbname });
    my $refresh = $bs->refresh_matviews($dbhost, $dbname, $dbuser, $dbpass, 'fullview', 'concurrent', $basepath);

    $result = { success => \@success_status, warning => \@warning_status, error => \@error_status, nd_protocol_id => $protocol_id };
}

=head2 create_protocol($transcripts, $transcripts_details)

Saves the protocol the uploader described, and returns its id. The transcripts the file turned out
to hold are recorded on it, so that later uploads can be checked against them.

=cut

sub create_protocol {
    my $transcripts = shift;
    my $transcripts_details = shift;

    my $high_dim_transcriptomics_protocol_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'high_dimensional_phenotype_transcriptomics_protocol', 'protocol_type')->cvterm_id();
    my $high_dim_transcriptomics_protocol_prop_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'high_dimensional_phenotype_protocol_properties', 'protocol_property')->cvterm_id();

    my %transcriptomics_protocol_prop = (
        expression_unit => $params->{protocol_unit},
        genome_version => $params->{protocol_genome_version},
        annotation_version => $params->{protocol_genome_annotation_version},
        instrument_model => $params->{protocol_instrument_model},
        layout => $params->{protocol_layout},
        library_method => $params->{protocol_library_method},
        library_comments => $params->{protocol_library_comments},
        mapping_software => $params->{protocol_mapping_software},
        sequencing_center => $params->{protocol_sequencing_center},
        sequencing_platform => $params->{protocol_sequencing_platform},
        read_length => $params->{protocol_read_length},
        nucleic_acid_extraction_method => $params->{protocol_nucleic_acid_extraction_method},
        header_column_names => $transcripts,
        header_column_details => $transcripts_details
    );

    my $protocol = $chado_schema->resultset('NaturalDiversity::NdProtocol')->create({
        name => $params->{protocol_name},
        type_id => $high_dim_transcriptomics_protocol_cvterm_id,
        nd_protocolprops => [{type_id => $high_dim_transcriptomics_protocol_prop_cvterm_id, value => encode_json \%transcriptomics_protocol_prop}]
    });
    my $protocol_id = $protocol->nd_protocol_id();

    my $desc_q = "UPDATE nd_protocol SET description=? WHERE nd_protocol_id=?;";
    my $sth = $chado_schema->storage->dbh()->prepare($desc_q);
    $sth->execute($params->{protocol_desc}, $protocol_id);

    return $protocol_id;
}

=head2 phenotype_metadata()

Describes the file the values came out of, which is recorded alongside them.

=cut

sub phenotype_metadata {
    return (
        archived_file => $params->{archived_filename},
        archived_file_type => $metadata_file_type,
        operator => $params->{user_name},
        date => $params->{timestamp}
    );
}

=head2 build_store_phenotypes($plots, $values, $phenotype_metadata, $for_storing)

Builds the object that checks and saves the expression values. Checking a file does not need to know
what the uploader chose to do about values that are already stored, so that is only set when the
values are actually being saved.

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
    my $dir = "$basepath$tempfiles_subdir/delete_nd_experiment_ids";
    if (! -d $dir) {
        make_path($dir);
    }
    my (undef, $tempfile) = tempfile("$dir/fileXXXX");

    return $tempfile;
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
