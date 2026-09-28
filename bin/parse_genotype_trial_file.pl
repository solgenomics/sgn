#!/usr/bin/perl

=head1

parse_genotype_trial_file.pl

=head1 SYNOPSIS

parse_genotype_trial_file.pl -H [dbhost] -D [dbname] -U [dbuser] -P [dbpass] -w [basepath] -ap [archive_path] -i [file_id] -t [plugin] -fi [facility_identifiers_included] -j [sp_job_id]

=head1 COMMAND-LINE OPTIONS

ARGUMENTS
 -H host name (required) Ex: "breedbase_db"
 -D database name (required) Ex: "breedbase"
 -U database username (required) Ex: "postgres"
 -P database userpass (required) Ex: "postgres"
 -w basepath (required) Ex: /home/production/cxgn/sgn
 -ap archive path (required) Ex: /home/production/volume/archive
 -i archived file id of the uploaded plate layout file (required)
 -t the CXGN::Trial::ParseUpload plugin the file is read with (required), one of:
    GenotypeTrialXLS, GenotypeTrialCoordinate, GenotypeTrialCoordinateTemplate
 -fi 1 if the file includes facility identifiers, 0 if it does not
 -j sp_job_id of the job that submitted this script (required)

=head2 DESCRIPTION

perl bin/parse_genotype_trial_file.pl -H breedbase_db -D breedbase -U postgres -P postgres -w /home/cxgn/sgn -ap /archive -i 112 -t GenotypeTrialXLS -fi 0 -j 17

Reads an already archived genotyping plate layout file and turns it into the plate design that
storing the plate needs. Nothing is written to the database here: the design is recorded on the
submitting job, so that the store step can pick it up without reading the file again.

The name of the plate is read off the submitting job rather than passed as an option, since a plate
name is whatever the uploader typed and does not belong on a command line. This script therefore
needs a job row that already exists and cannot be run on its own.

Whatever happened is reported back to the submitting job, so that it reads the same whether the
upload was waited on or left to run in the background.

=head1 AUTHOR

Ryan Preble <rsp98@cornell.edu>

=cut

use strict;
use warnings;

use Getopt::Long;
use Pod::Usage;
use DBI;
use Try::Tiny;

use Bio::Chado::Schema;
use CXGN::DB::InsertDBH;
use CXGN::File;
use CXGN::Job;
use CXGN::Metadata::Schema;
use CXGN::People::Schema;
use CXGN::Trial::ParseUpload;

# The plugins that read a genotyping plate layout. The site picks one of these from the kind of
# file that was uploaded, so anything else is a mistake rather than a file the uploader can fix.
my %plate_layout_plugins = map { $_ => 1 } qw(
    GenotypeTrialXLS
    GenotypeTrialCoordinate
    GenotypeTrialCoordinateTemplate
);

my ( $help, $dbhost, $dbname, $dbuser, $dbpass, $basepath, $archive_path, $file_id, $plugin, $include_facility_identifiers, $sp_job_id );
GetOptions(
    'dbhost|H=s'                 => \$dbhost,
    'dbname|D=s'                 => \$dbname,
    'dbuser|U=s'                 => \$dbuser,
    'dbpass|P=s'                 => \$dbpass,
    'basepath|w=s'               => \$basepath,
    'archive_path|ap=s'          => \$archive_path,
    'i=s'                        => \$file_id,
    'plugin|t=s'                 => \$plugin,
    'facility_identifiers|fi=s'  => \$include_facility_identifiers,
    'jobid|j=s'                  => \$sp_job_id,
    'help'                       => \$help,
);
pod2usage(1) if $help;
if (!$file_id || !$basepath || !$dbname || !$dbhost || !$archive_path || !$plugin || !defined($sp_job_id)) {
    pod2usage({ -msg => 'Error. Missing options!', -verbose => 1, -exitval => 1 });
}
if (!$plate_layout_plugins{$plugin}) {
    pod2usage({ -msg => "Error. Unknown genotyping plate layout plugin $plugin!", -verbose => 1, -exitval => 1 });
}

$include_facility_identifiers = $include_facility_identifiers ? 1 : 0;

# Connect to databases.
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
my $people_schema = CXGN::People::Schema->connect( sub { $dbh }, { on_connect_do => ['SET search_path TO public, sgn, sgn_people;'] } );

my @success_messages;
my @error_messages;
my $design;
my $missing_accessions;

# Any uncaught failure below would otherwise leave the job looking successful, because the finish
# timestamp is recorded whether or not this script exits cleanly.
try {
    parse_genotype_trial_file();
} catch {
    push @error_messages, $_;
};

finish();

=head2 parse_genotype_trial_file()

Reads the uploaded layout file and builds the plate design out of it.

=cut

sub parse_genotype_trial_file {
    my $genotyping_plate_name = plate_name();

    my $archived_file = CXGN::File->new({
        file_id => $file_id,
        metadata_schema => $metadata_schema,
        archive_path => $archive_path
    });

    my $file_path = $archived_file->get_path();
    if (! -e $file_path) {
        die "The uploaded file could not be found at $file_path.\n";
    }

    my $parser = CXGN::Trial::ParseUpload->new(
        chado_schema => $chado_schema,
        filename => $file_path,
        facility_identifiers_included => $include_facility_identifiers
    );
    $parser->load_plugin($plugin);

    # Parsing a coordinate template file requires the plate name, because a unique sample name is
    # made by putting the plate name in front of the well position.
    my $parsed_data = $parser->parse({ genotyping_plate_id => $genotyping_plate_name });

    if (!$parsed_data) {
        if (!$parser->has_parse_errors()) {
            push @error_messages, "Could not get parsing errors";
            return;
        }

        my $parse_errors = $parser->get_parse_errors();
        my $error_string = '';
        foreach my $error_message (@{$parse_errors->{'error_messages'}}) {
            $error_string = $error_string.$error_message."<br>";
        }
        push @error_messages, $error_string;

        # The upload dialog offers to add accessions that the plate refers to but the database does
        # not have yet, so which ones those were has to travel back with the errors.
        $missing_accessions = $parse_errors->{'missing_accessions'};
        return;
    }

    $design = build_design($parsed_data);
    push @success_messages, "Genotyping plate file parsed successfully.";
}

=head2 plate_name()

Reads the name of the plate this file describes off the submitting job. Dies if it is not there,
since a coordinate template file cannot be read without it.

=cut

sub plate_name {
    my $job = CXGN::Job->new({
        sp_job_id => $sp_job_id,
        schema => $chado_schema,
        people_schema => $people_schema
    });

    my $job_args = $job->additional_args() || {};
    my $genotyping_plate_name = $job_args->{genotyping_plate_name};
    if (!$genotyping_plate_name) {
        die "Job $sp_job_id does not name the genotyping plate this file describes.\n";
    }

    return $genotyping_plate_name;
}

=head2 build_design($parsed_data)

Turns the parsed wells into the design that CXGN::Trial::TrialCreate takes, which is the same shape
a plate laid out on the site rather than uploaded arrives in.

=cut

sub build_design {
    my $parsed_data = shift;

    my %design;
    foreach (sort keys %$parsed_data) {
        my $val = $parsed_data->{$_};
        $design{$val->{well}} = {
            plot_name => $val->{sample_id},
            stock_name => $val->{source_stock_uniquename},
            plot_number => $val->{well},
            row_number => $val->{row},
            col_number => $val->{column},
            is_blank => $val->{is_blank},
            concentration => $val->{concentration},
            volume => $val->{volume},
            tissue_type => $val->{tissue_type},
            dna_person => $val->{dna_person},
            extraction => $val->{extraction},
            acquisition_date => $val->{date},
            notes => $val->{notes},
            ncbi_taxonomy_id => $val->{ncbi_taxonomy_id},
            facility_identifier => $val->{facility_identifier}
        };
    }

    return \%design;
}

=head2 finish()

Reports what happened back to the submitting job and exits.

The design goes back on the job as well as the messages, since the store step reads it from there
rather than parsing the file a second time.

=cut

sub finish {
    foreach (@success_messages) {
        print STDOUT "SUCCESS: $_\n";
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

        if ($design) {
            $job->additional_args->{design} = $design;
        }
        if ($missing_accessions) {
            $job->additional_args->{missing_accessions} = $missing_accessions;
        }
        if (scalar(@success_messages) > 0) {
            $job->additional_args->{success_messages} = join("<br>", @success_messages);
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
