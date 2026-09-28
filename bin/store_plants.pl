#!/usr/bin/perl

=head1

store_plants.pl

=head1 SYNOPSIS

store_plants.pl -H [dbhost] -D [dbname] -U [dbuser] -P [dbpass] -w [basepath] -ap [archive_path] -tf [tempfiles_subdir] -i [file_id] -un [username] -t [upload_type] -tr [trial_id] -n [number_of_plants] -j [sp_job_id]

=head1 COMMAND-LINE OPTIONS

ARGUMENTS
 -H host name (required) Ex: "breedbase_db"
 -D database name (required) Ex: "breedbase"
 -U database username (required) Ex: "postgres"
 -P database userpass (required) Ex: "postgres"
 -w basepath (required) Ex: /home/production/cxgn/sgn
 -ap archive path (required) Ex: /home/production/volume/archive
 -tf tempfiles subdirectory, relative to the basepath (required) Ex: static/documents/tempfiles
 -i archived file id of the uploaded spreadsheet (required)
 -un username of the uploader (required)
 -t upload type (required), one of: plants_by_name, plants_by_index, plants_per_plot,
    subplot_plants_by_name, subplot_plants_by_index, plants_per_subplot
 -tr trial id the plants belong to (required)
 -n number of plants per plot or per subplot (required)
 -j sp_job_id of the job that submitted this script (required)

=head2 DESCRIPTION

perl bin/store_plants.pl -H breedbase_db -D breedbase -U postgres -P postgres -w /home/cxgn/sgn -ap /archive -tf static/documents/tempfiles -i 112 -un janedoe -t plants_by_name -tr 42 -n 4 -j 17

Adds plant entries to a trial from an already archived spreadsheet. Plants are attached either to the
plots of the trial or to its subplots, depending on the upload type, and the trial layout cache is
regenerated afterwards so the trial page reflects the new entries.

The whole spreadsheet is stored as a unit. A file that cannot be parsed, or that fails partway
through saving, leaves the trial as it was, since a trial holding only some of its plants would be
worse than one holding none. Whatever went wrong is reported back to the submitting job.

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
use CXGN::DB::InsertDBH;
use CXGN::File;
use CXGN::Job;
use CXGN::Metadata::Schema;
use CXGN::People::Person;
use CXGN::People::Schema;
use CXGN::Phenome::Schema;
use CXGN::Trial;
use CXGN::Trial::ParseUpload;
use CXGN::Trial::TrialLayout;

# What each upload type means: which spreadsheet plugin reads it, whether the plants hang off plots
# or off subplots, and whether the file assigns each plant an index number within its parent.
my %upload_types = (
    plants_by_name          => { plugin => 'TrialPlantsXLS',                          parent => 'plot',    index_numbers => 0 },
    plants_by_index         => { plugin => 'TrialPlantsWithPlantNumberXLS',           parent => 'plot',    index_numbers => 1 },
    plants_per_plot         => { plugin => 'TrialPlantsWithNumberOfPlantsXLS',        parent => 'plot',    index_numbers => 1 },
    subplot_plants_by_name  => { plugin => 'TrialPlantsSubplotXLS',                   parent => 'subplot', index_numbers => 0 },
    subplot_plants_by_index => { plugin => 'TrialPlantsSubplotWithPlantNumberXLS',    parent => 'subplot', index_numbers => 1 },
    plants_per_subplot      => { plugin => 'TrialPlantsSubplotWithNumberOfPlantsXLS', parent => 'subplot', index_numbers => 1 }
);

my ( $help, $dbhost, $dbname, $dbuser, $dbpass, $basepath, $archive_path, $tempfiles_subdir, $file_id, $username, $upload_type, $trial_id, $plants_per_parent, $sp_job_id );
GetOptions(
    'dbhost|H=s'           => \$dbhost,
    'dbname|D=s'           => \$dbname,
    'dbuser|U=s'           => \$dbuser,
    'dbpass|P=s'           => \$dbpass,
    'basepath|w=s'         => \$basepath,
    'archive_path|ap=s'    => \$archive_path,
    'tempfiles|tf=s'       => \$tempfiles_subdir,
    'i=s'                  => \$file_id,
    'user|un=s'            => \$username,
    'upload_type|t=s'      => \$upload_type,
    'trial|tr=s'           => \$trial_id,
    'number|n=s'           => \$plants_per_parent,
    'jobid|j=s'            => \$sp_job_id,
    'help'                 => \$help,
);
pod2usage(1) if $help;
if (!$file_id || !$username || !$basepath || !$dbname || !$dbhost || !$archive_path || !$tempfiles_subdir || !$upload_type || !$trial_id || !defined($sp_job_id)) {
    pod2usage({ -msg => 'Error. Missing options!', -verbose => 1, -exitval => 1 });
}
if (!$upload_types{$upload_type}) {
    pod2usage({ -msg => "Error. Unknown plant upload type $upload_type!", -verbose => 1, -exitval => 1 });
}

# Connect to databases. Everything shares one handle so that the plant entries and the treatments
# inherited from their parents are written in the same transaction.
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

my @success_messages;
my @warning_messages;
my @error_messages;

# Any uncaught failure below would otherwise leave the job looking successful, because the finish
# timestamp is recorded whether or not this script exits cleanly.
try {
    store_plants();
} catch {
    push @error_messages, $_;
};

finish();

=head2 store_plants()

Reads the uploaded spreadsheet and saves its plants to the trial.

=cut

sub store_plants {
    my $sp_person_id = CXGN::People::Person->get_person_by_username($dbh, $username);
    if (!$sp_person_id) {
        die "User not found in the database for username $username.\n";
    }

    my $archived_file = CXGN::File->new({
        file_id => $file_id,
        metadata_schema => $metadata_schema,
        archive_path => $archive_path
    });

    my $file_path = $archived_file->get_path();
    if (! -e $file_path) {
        die "The uploaded file could not be found at $file_path.\n";
    }

    my $parsed_entries = parse_file($file_path);
    my $plant_hash = build_plant_hash($parsed_entries);

    my $trial = CXGN::Trial->new({
        bcs_schema => $chado_schema,
        phenome_schema => $phenome_schema,
        metadata_schema => $metadata_schema,
        trial_id => $trial_id
    });

    save_plants($trial, $plant_hash, $sp_person_id);

    my $plant_count = 0;
    foreach my $parent_id (keys %$plant_hash) {
        $plant_count += scalar(@{$plant_hash->{$parent_id}->{plant_names}});
    }
    my $parent_type = $upload_types{$upload_type}->{parent};
    push @success_messages, "Stored $plant_count plants in ".scalar(keys %$plant_hash)." ".$parent_type."s of trial ".$trial->get_name().".";

    # The trial page reads its layout from a cache, so it would keep showing the trial without its
    # new plants until something else refreshed it. The plants are saved by this point, so a cache
    # that could not be rebuilt is not worth failing the upload over.
    try {
        my $layout = CXGN::Trial::TrialLayout->new({
            schema => $chado_schema,
            trial_id => $trial_id,
            experiment_type => 'field_layout'
        });
        $layout->generate_and_cache_layout();
    } catch {
        push @warning_messages, "The plants were stored, but the trial layout could not be regenerated: $_";
    };
}

=head2 parse_file($file_path)

Parses the uploaded spreadsheet with the plugin for this upload type. Dies with the reasons the
file could not be read.

=cut

sub parse_file {
    my $file_path = shift;

    my $parser = CXGN::Trial::ParseUpload->new(chado_schema => $chado_schema, filename => $file_path);
    $parser->load_plugin($upload_types{$upload_type}->{plugin});
    my $parsed_data = $parser->parse();

    if (!$parsed_data) {
        if (!$parser->has_parse_errors()) {
            die "The uploaded file could not be parsed, and no parsing errors were reported.\n";
        }
        my $parse_errors = $parser->get_parse_errors();
        my $error_string = '';
        foreach my $error_message (@{$parse_errors->{'error_messages'}}) {
            $error_string .= $error_message."<br>";
        }
        die $error_string;
    }

    return $parsed_data->{data};
}

=head2 build_plant_hash($parsed_entries)

Groups the parsed plants by the plot or subplot they belong to, in the shape the save methods
expect.

=cut

sub build_plant_hash {
    my $parsed_entries = shift;

    my $parent_type = $upload_types{$upload_type}->{parent};
    my $parent_id_key = $parent_type."_stock_id";
    my $parent_name_key = $parent_type."_name";

    my %plant_hash;
    foreach my $entry (@$parsed_entries) {
        my $parent_id = $entry->{$parent_id_key};

        $plant_hash{$parent_id}->{$parent_name_key} = $entry->{$parent_name_key};
        push @{$plant_hash{$parent_id}->{plant_names}}, $entry->{plant_name};

        if ($upload_types{$upload_type}->{index_numbers}) {
            push @{$plant_hash{$parent_id}->{plant_index_numbers}}, $entry->{plant_index_number};
        }
        if ($entry->{row_num} && $entry->{col_num}) {
            push @{$plant_hash{$parent_id}->{plant_coords}}, $entry->{row_num}.",".$entry->{col_num};
        }
    }

    return \%plant_hash;
}

=head2 save_plants($trial, $plant_hash, $sp_person_id)

Saves the plants to the trial. Dies with the reason if they could not be saved.

=cut

sub save_plants {
    my $trial = shift;
    my $plant_hash = shift;
    my $sp_person_id = shift;

    # Plants always inherit the treatments of the plot or subplot they belong to. The upload dialogs
    # show this as a checkbox, but it is disabled and always checked.
    my $inherits_plot_treatments = 1;

    my $additional_plants = $trial->has_plant_entries();
    my $phenotype_store_config = build_phenotype_store_config($sp_person_id);

    if ($upload_types{$upload_type}->{parent} eq 'subplot') {
        if (!$trial->save_plant_subplot_entries($plant_hash, $plants_per_parent, $inherits_plot_treatments, $sp_person_id, $username, $phenotype_store_config, $additional_plants)) {
            die "An error occurred saving the plant entries. Check the site log for details.\n";
        }
        return;
    }

    # Unlike the other save methods, this one reports back what went wrong instead of just failing.
    my $result = $trial->save_plant_entries($plant_hash, $plants_per_parent, $inherits_plot_treatments, $sp_person_id, $phenotype_store_config, $additional_plants);
    if ($result->{error}) {
        die $result->{error}."\n";
    }
}

=head2 build_phenotype_store_config($sp_person_id)

Builds the configuration the save methods use to record the treatments that new plants inherit from
their plot or subplot.

=cut

sub build_phenotype_store_config {
    my $sp_person_id = shift;

    my $temp_basedir = "$basepath/$tempfiles_subdir";
    if (! -d "$temp_basedir/delete_nd_experiment_ids/") {
        mkdir("$temp_basedir/delete_nd_experiment_ids/");
    }
    my (undef, $tempfile) = tempfile("$temp_basedir/delete_nd_experiment_ids/fileXXXX");

    my $time = DateTime->now();

    return {
        basepath => $temp_basedir,
        dbhost => $dbhost,
        dbuser => $dbuser,
        dbname => $dbname,
        dbpass => $dbpass,
        temp_file_nd_experiment_id => $tempfile,
        user_id => $sp_person_id,
        metadata_hash => {
            archived_file => 'none',
            archived_file_type => 'new stock treatment auto inheritance',
            operator => $username,
            date => $time->ymd()."_".$time->hms()
        }
    };
}

=head2 finish()

Reports what happened back to the submitting job and exits.

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

    try {
        my $job = CXGN::Job->new({
            sp_job_id => $sp_job_id,
            schema => $chado_schema,
            people_schema => $people_schema
        });

        if (!$job->additional_args()) {
            $job->additional_args({});
        }

        if (scalar(@success_messages) > 0) {
            $job->additional_args->{success_messages} = join("<br>", @success_messages);
        }
        if (scalar(@warning_messages) > 0) {
            $job->additional_args->{warning_messages} = join("<br>", @warning_messages);
        }
        if (scalar(@error_messages) > 0) {
            $job->additional_args->{error_messages} = join("<br>", @error_messages);
        }

        $job->update_status(scalar(@error_messages) > 0 ? "failed" : "finished");
    } catch {
        print STDERR "Could not report the results of this upload to job $sp_job_id: $_\n";
    };

    exit(scalar(@error_messages) > 0 ? 1 : 0);
}

1;
