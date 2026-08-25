#!/usr/bin/perl

=head1

upload_phenotypes.pl

=head1 SYNOPSIS

upload_phenotypes.pl -H [dbhost] -D [dbname] -U [dbuser] -P [dbpass] -w [basepath] -ap [archive_path] -tf [tempfiles_subdir] -m [mode] -i [file_id] -iz [image_zipfile_id] -un [username] -t [validate_type] -mt [metadata_file_type] -dl [data_level] -ti [timestamps_included] -ow [overwrite_values] -rv [remove_values] -iw [ignore_warnings] -tt [is_treatment] -j [sp_job_id]

=head1 COMMAND-LINE OPTIONS

ARGUMENTS
 -H host name (required) Ex: "breedbase_db"
 -D database name (required) Ex: "breedbase"
 -U database username (required) Ex: "postgres"
 -P database userpass (required) Ex: "postgres"
 -w basepath (required) Ex: /home/production/cxgn/sgn
 -ap archive path (required) Ex: /home/production/volume/archive
 -tf tempfiles subdirectory, relative to the basepath (required) Ex: static/documents/tempfiles
 -m mode (required), either "verify" to check the file without saving anything, or "store" to save
    its values to the database
 -i archived file id of the uploaded phenotype file (required)
 -iz archived file id of the image zipfile that goes with the phenotype file, if there is one
 -un username of the uploader (required)
 -t validation type (required), the parser plugin the file is read with. Ex: "phenotype spreadsheet"
 -mt metadata file type (required), recorded against the stored values. Ex: "spreadsheet phenotype file"
 -dl data level, the kind of observation unit the file holds values for (default: plots)
 -ti 1 if the file includes timestamps, 0 if it does not
 -ow 1 to overwrite previously stored values, 0 to skip them
 -rv 1 to remove previously stored values that are blank in the file, 0 to leave them alone
 -iw 1 to store the values even though the file raised warnings, 0 to treat warnings as a failure
 -tt 1 if the file holds treatments rather than phenotypes, 0 if it holds phenotypes
 -j sp_job_id of the job that submitted this script (required)

=head2 DESCRIPTION

perl bin/upload_phenotypes.pl -H breedbase_db -D breedbase -U postgres -P postgres -w /home/cxgn/sgn -ap /archive -tf static/documents/tempfiles -m store -i 112 -un janedoe -t "phenotype spreadsheet" -mt "spreadsheet phenotype file" -dl plots -ti 1 -ow 0 -rv 0 -iw 0 -tt 0 -j 17

Reads an already archived phenotype file and either checks it or saves its values to the database.

In "verify" mode the file is parsed and every value in it is checked against the database, but
nothing is written. This is what the upload dialogs and the upload manager use to tell a user what
is wrong with a file before they commit to it, so the same file is expected to be handed back to
this script in "store" mode afterwards.

In "store" mode the values are saved. A file that raises warnings is only stored if the uploader
already saw those warnings and chose to go ahead, which the site records as ignore_warnings.

Whatever happened is reported back to the submitting job, so that it reads the same whether the
upload was waited on or left to run in the background.

=head1 AUTHOR

Ryan Preble <rsp98@cornell.edu>

=cut

use strict;
use warnings;

use Getopt::Long;
use Pod::Usage;
use DateTime;
use DBI;
use File::Basename;
use File::Temp qw | tempfile |;
use Try::Tiny;

use Bio::Chado::Schema;
use CXGN::BreederSearch;
use CXGN::DB::InsertDBH;
use CXGN::File;
use CXGN::Job;
use CXGN::Metadata::Schema;
use CXGN::People::Person;
use CXGN::People::Schema;
use CXGN::Phenome::Schema;
use CXGN::Phenotypes::ParseUpload;
use CXGN::Phenotypes::StorePhenotypes;
use CXGN::Stock;
use SGN::Image;
use SGN::ScriptContext;

my ( $help, $dbhost, $dbname, $dbuser, $dbpass, $basepath, $archive_path, $tempfiles_subdir, $mode, $file_id, $image_zipfile_id, $username, $validate_type, $metadata_file_type, $data_level, $timestamps_included, $overwrite_values, $remove_values, $ignore_warnings, $is_treatment, $sp_job_id );
GetOptions(
    'dbhost|H=s'             => \$dbhost,
    'dbname|D=s'             => \$dbname,
    'dbuser|U=s'             => \$dbuser,
    'dbpass|P=s'             => \$dbpass,
    'basepath|w=s'           => \$basepath,
    'archive_path|ap=s'      => \$archive_path,
    'tempfiles|tf=s'         => \$tempfiles_subdir,
    'mode|m=s'               => \$mode,
    'i=s'                    => \$file_id,
    'image_zipfile|iz=s'     => \$image_zipfile_id,
    'user|un=s'              => \$username,
    'validate_type|t=s'      => \$validate_type,
    'metadata_type|mt=s'     => \$metadata_file_type,
    'data_level|dl=s'        => \$data_level,
    'timestamps|ti=s'        => \$timestamps_included,
    'overwrite|ow=s'         => \$overwrite_values,
    'remove|rv=s'            => \$remove_values,
    'ignore_warnings|iw=s'   => \$ignore_warnings,
    'treatment|tt=s'         => \$is_treatment,
    'jobid|j=s'              => \$sp_job_id,
    'help'                   => \$help,
);
pod2usage(1) if $help;
if (!$file_id || !$username || !$basepath || !$dbname || !$dbhost || !$archive_path || !$tempfiles_subdir || !$mode || !$validate_type || !$metadata_file_type || !defined($sp_job_id)) {
    pod2usage({ -msg => 'Error. Missing options!', -verbose => 1, -exitval => 1 });
}
if ($mode ne 'verify' && $mode ne 'store') {
    pod2usage({ -msg => "Error. Unknown mode $mode! Use verify or store.", -verbose => 1, -exitval => 1 });
}

$data_level ||= 'plots';
$timestamps_included = $timestamps_included ? 1 : 0;
$overwrite_values = $overwrite_values ? 1 : 0;
$remove_values = $remove_values ? 1 : 0;
$ignore_warnings = $ignore_warnings ? 1 : 0;
$is_treatment = $is_treatment ? 1 : 0;

# Connect to databases. Everything shares one handle so that the phenotype values and the metadata
# recorded against them are written in the same transaction.
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

# Parsing and image handling were written to run inside a web request and ask the Catalyst context
# for site settings, schemas and the name of the uploader. This is a shim for that.
my $context = SGN::ScriptContext->new({
    basepath => $basepath,
    username => $username,
    schemas => {
        'Bio::Chado::Schema' => $chado_schema,
        'CXGN::Metadata::Schema' => $metadata_schema,
        'CXGN::Phenome::Schema' => $phenome_schema,
        'CXGN::People::Schema' => $people_schema
    }
});

my @success_messages;
my @warning_messages;
my @error_messages;

# Any uncaught failure below would otherwise leave the job looking successful, because the finish
# timestamp is recorded whether or not this script exits cleanly.
try {
    upload_phenotypes();
} catch {
    push @error_messages, $_;
};

finish();

=head2 upload_phenotypes()

Reads the uploaded file and either checks its values or saves them, depending on the mode.

=cut

sub upload_phenotypes {
    my $sp_person_id = CXGN::People::Person->get_person_by_username($dbh, $username);
    if (!$sp_person_id) {
        die "User not found in the database for username $username.\n";
    }

    my $file_path = archived_file_path($file_id, "The uploaded file");
    my $image_zipfile_path = $image_zipfile_id ? archived_file_path($image_zipfile_id, "The uploaded image zipfile") : undef;
    my $display_filename = basename($file_path);

    my $parser = CXGN::Phenotypes::ParseUpload->new();

    # The file is checked before it is read, so that a file that is not what it claims to be is
    # reported as such instead of failing somewhere inside the parser.
    my $validate_file = $parser->validate($validate_type, $file_path, $timestamps_included, $data_level, $chado_schema, $image_zipfile_path, undef);
    if (!$validate_file) {
        die "Archived file not valid: $display_filename.\n";
    }
    if (!ref($validate_file) && $validate_file == 1) {
        push @success_messages, "File valid: $display_filename.";
    } else {
        # The parser reported on the file rather than passing it. Anything it has to say is the
        # reason the file cannot be used, so there is nothing further to do with it.
        if (ref($validate_file) eq 'HASH' && $validate_file->{'error'}) {
            push @error_messages, $validate_file->{'error'};
        }
        return;
    }

    my $time = DateTime->now();
    my $phenotype_metadata = {
        archived_file => $file_path,
        archived_file_id => $file_id,
        archived_file_type => $metadata_file_type,
        operator => $username,
        date => $time->ymd()."_".$time->hms()
    };

    my $parsed_file = $parser->parse($validate_type, $file_path, $timestamps_included, $data_level, $chado_schema, $image_zipfile_path, $sp_person_id, $context, undef);
    if (!$parsed_file) {
        die "Error parsing file $display_filename.\n";
    }
    if ($parsed_file->{'error'}) {
        push @error_messages, $parsed_file->{'error'};
        return;
    }

    my $parsed_data = $parsed_file->{'data'};
    my @plots = @{$parsed_file->{'units'}};
    my @traits = @{$parsed_file->{'variables'}};
    push @success_messages, "File data successfully parsed.";

    if ($is_treatment) {
        propagate_treatments_to_child_stocks($parsed_data, \@plots, \@traits);
    }

    if ($mode eq 'verify') {
        verify_phenotypes($sp_person_id, $parsed_data, \@plots, \@traits, $phenotype_metadata, $image_zipfile_path);
    } else {
        store_phenotypes($sp_person_id, $parsed_data, \@plots, \@traits, $phenotype_metadata, $image_zipfile_path);
    }
}

=head2 archived_file_path($archived_file_id, $description)

Returns where an archived file is on disk. Dies with the reason if it is not there.

=cut

sub archived_file_path {
    my $archived_file_id = shift;
    my $description = shift;

    my $archived_file = CXGN::File->new({
        file_id => $archived_file_id,
        metadata_schema => $metadata_schema,
        archive_path => $archive_path
    });

    my $file_path = $archived_file->get_path();
    if (! -e $file_path) {
        die "$description could not be found at $file_path.\n";
    }

    return $file_path;
}

=head2 propagate_treatments_to_child_stocks($parsed_data, $plots, $traits)

A treatment applied to an observation unit applies to everything below it as well, so the values
read from the file are copied down to each child stock. Accessions are left out, since a treatment
is applied to a stock in a trial rather than to the accession it was planted from.

=cut

sub propagate_treatments_to_child_stocks {
    my $parsed_data = shift;
    my $plots = shift;
    my $traits = shift;

    foreach my $plot (@$plots) {
        my $plot_obj = CXGN::Stock->new({
            schema => $chado_schema,
            uniquename => $plot
        });
        my $child_stocks = $plot_obj->get_child_stocks_flat_list();
        foreach my $child (@{$child_stocks}) {
            next if ($child->{type} eq "accession");
            push @$plots, $child->{name};
            foreach my $trait (@$traits) {
                $parsed_data->{$child->{name}}->{$trait} = $parsed_data->{$plot}->{$trait};
            }
        }
    }
}

=head2 verify_phenotypes($sp_person_id, $parsed_data, $plots, $traits, $phenotype_metadata, $image_zipfile_path)

Checks the values in the file against the database without storing any of them.

=cut

sub verify_phenotypes {
    my $sp_person_id = shift;
    my $parsed_data = shift;
    my $plots = shift;
    my $traits = shift;
    my $phenotype_metadata = shift;
    my $image_zipfile_path = shift;

    my $store_phenotypes = build_store_phenotypes($sp_person_id, $parsed_data, $plots, $traits, $phenotype_metadata, $image_zipfile_path, 0);

    my ($verified_warning, $verified_error);
    try {
        ($verified_warning, $verified_error) = $store_phenotypes->verify();
    } catch {
        $verified_error = $_;
    };

    if ($verified_error) {
        push @error_messages, $verified_error;
        return;
    }
    if ($verified_warning) {
        push @warning_messages, $verified_warning;
    }

    push @success_messages, "File data verified. Plot names and trait names are valid.";
}

=head2 store_phenotypes($sp_person_id, $parsed_data, $plots, $traits, $phenotype_metadata, $image_zipfile_path)

Saves the values in the file to the database, along with the images that go with them, and refreshes
the materialized views so the new values show up in searches.

=cut

sub store_phenotypes {
    my $sp_person_id = shift;
    my $parsed_data = shift;
    my $plots = shift;
    my $traits = shift;
    my $phenotype_metadata = shift;
    my $image_zipfile_path = shift;

    my $store_phenotypes = build_store_phenotypes($sp_person_id, $parsed_data, $plots, $traits, $phenotype_metadata, $image_zipfile_path, 1);

    my ($stored_phenotype_error, $stored_phenotype_success);
    try {
        ($stored_phenotype_error, $stored_phenotype_success) = $store_phenotypes->store();
    } catch {
        $stored_phenotype_error = $_;
    };

    if ($stored_phenotype_error) {
        push @error_messages, $stored_phenotype_error;
        return;
    }
    if ($stored_phenotype_success) {
        push @success_messages, $stored_phenotype_success;
    }

    # A field book upload carries its photos in a zipfile, which is stored once the values those
    # photos belong to are in the database.
    if ($validate_type eq 'field book' && $image_zipfile_path) {
        my $image = SGN::Image->new( $dbh, undef, $context );
        my $image_error = $image->upload_fieldbook_zipfile($image_zipfile_path, $sp_person_id);
        if ($image_error) {
            push @error_messages, $image_error;
        }
    }

    push @success_messages, "Metadata saved for archived file.";

    my $bs = CXGN::BreederSearch->new({ dbh => $dbh, dbname => $dbname });
    $bs->refresh_matviews($dbhost, $dbname, $dbuser, $dbpass, 'phenotypes', 'concurrent', $basepath);
}

=head2 build_store_phenotypes($sp_person_id, $parsed_data, $plots, $traits, $phenotype_metadata, $image_zipfile_path, $for_storing)

Builds the object that checks and saves phenotype values. Checking a file does not need to know what
the uploader chose to do about values that are already stored, so those choices are only set when
the values are actually being saved.

=cut

sub build_store_phenotypes {
    my $sp_person_id = shift;
    my $parsed_data = shift;
    my $plots = shift;
    my $traits = shift;
    my $phenotype_metadata = shift;
    my $image_zipfile_path = shift;
    my $for_storing = shift;

    my %args = (
        basepath => $basepath,
        dbhost => $dbhost,
        dbname => $dbname,
        dbuser => $dbuser,
        dbpass => $dbpass,
        temp_file_nd_experiment_id => nd_experiment_tempfile(),
        bcs_schema => $chado_schema,
        metadata_schema => $metadata_schema,
        phenome_schema => $phenome_schema,
        user_id => $sp_person_id,
        stock_list => $plots,
        trait_list => $traits,
        values_hash => $parsed_data,
        has_timestamps => $timestamps_included,
        metadata_hash => $phenotype_metadata,
        image_zipfile_path => $image_zipfile_path,
        composable_validation_check_name => $context->config->{composable_validation_check_name}
    );

    if ($for_storing) {
        $args{overwrite_values} = $overwrite_values;
        $args{remove_values} = $remove_values;
        $args{allow_repeat_measures} = $context->config->{allow_repeat_measures};
    }

    return CXGN::Phenotypes::StorePhenotypes->new(%args);
}

=head2 nd_experiment_tempfile()

Returns a file for recording the experiment ids that have to be cleaned up if storing goes wrong
partway through.

=cut

sub nd_experiment_tempfile {
    my $temp_basedir = "$basepath/$tempfiles_subdir";
    if (! -d "$temp_basedir/delete_nd_experiment_ids/") {
        mkdir("$temp_basedir/delete_nd_experiment_ids/");
    }
    my (undef, $tempfile) = tempfile("$temp_basedir/delete_nd_experiment_ids/fileXXXX");

    return $tempfile;
}

=head2 finish()

Reports what happened back to the submitting job and exits.

A file that raised warnings has not been dealt with yet, even though nothing actually went wrong
with it, so the job is left failed until the uploader either fixes the file or says to go ahead
anyway. Only errors are treated as failures once they have.

=cut

sub finish {
    foreach (@success_messages) {
        print STDOUT "SUCCESS: $_\n";
    }
    foreach (@warning_messages) {
        print STDERR "WARNING: $_\n";
    }
    foreach (@error_messages) {
        print STDERR "ERROR: $_\n";
    }

    my $failed = scalar(@error_messages) > 0 || (scalar(@warning_messages) > 0 && !$ignore_warnings);

    try {
        my $job = CXGN::Job->new({
            sp_job_id => $sp_job_id,
            schema => $chado_schema,
            people_schema => $people_schema
        });

        if (!$job->additional_args()) {
            $job->additional_args({});
        }

        # The submitting page records what it did with the file before handing it over, and those
        # messages belong in front of the ones from here.
        my $already_reported = $job->additional_args->{success_messages};
        my @all_success_messages = $already_reported ? ($already_reported, @success_messages) : @success_messages;

        if (scalar(@all_success_messages) > 0) {
            $job->additional_args->{success_messages} = join("<br>", @all_success_messages);
        }
        if (scalar(@warning_messages) > 0) {
            $job->additional_args->{warning_messages} = join("<br>", @warning_messages);
        }
        if (scalar(@error_messages) > 0) {
            $job->additional_args->{error_messages} = join("<br>", @error_messages);
        }

        $job->update_status($failed ? "failed" : "finished");
    } catch {
        print STDERR "Could not report the results of this upload to job $sp_job_id: $_\n";
    };

    exit(scalar(@error_messages) > 0 ? 1 : 0);
}

1;
