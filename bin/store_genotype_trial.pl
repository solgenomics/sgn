#!/usr/bin/perl

=head1

store_genotype_trial.pl

=head1 SYNOPSIS

store_genotype_trial.pl -H [dbhost] -D [dbname] -U [dbuser] -P [dbpass] -w [basepath] -un [username] -j [sp_job_id]

=head1 COMMAND-LINE OPTIONS

ARGUMENTS
 -H host name (required) Ex: "breedbase_db"
 -D database name (required) Ex: "breedbase"
 -U database username (required) Ex: "postgres"
 -P database userpass (required) Ex: "postgres"
 -w basepath (required) Ex: /home/production/cxgn/sgn
 -un username of the uploader (required)
 -j sp_job_id of the job that submitted this script (required)

=head2 DESCRIPTION

perl bin/store_genotype_trial.pl -H breedbase_db -D breedbase -U postgres -P postgres -w /home/cxgn/sgn -un janedoe -j 17

Saves a genotyping plate to the database. The plate is described by a design, which either came out
of an uploaded layout file or was laid out on the site, together with the plate information the
uploader filled in.

Unlike the other upload scripts, this one is not given a file to read. The plate it is to store is
recorded on the submitting job as plate_data before the job is submitted, so this script needs a job
row that already exists and cannot be run on its own.

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
use CXGN::BreedersToolbox::Projects;
use CXGN::DB::InsertDBH;
use CXGN::Job;
use CXGN::People::Person;
use CXGN::People::Schema;
use CXGN::Trial;
use CXGN::Trial::TrialCreate;
use CXGN::Trial::TrialLayout;
use SGN::Model::Cvterm;

my ( $help, $dbhost, $dbname, $dbuser, $dbpass, $basepath, $username, $sp_job_id );
GetOptions(
    'dbhost|H=s'   => \$dbhost,
    'dbname|D=s'   => \$dbname,
    'dbuser|U=s'   => \$dbuser,
    'dbpass|P=s'   => \$dbpass,
    'basepath|w=s' => \$basepath,
    'user|un=s'    => \$username,
    'jobid|j=s'    => \$sp_job_id,
    'help'         => \$help,
);
pod2usage(1) if $help;
if (!$username || !$basepath || !$dbname || !$dbhost || !defined($sp_job_id)) {
    pod2usage({ -msg => 'Error. Missing options!', -verbose => 1, -exitval => 1 });
}

# Connect to databases. Everything shares one handle so that the plate and its samples are written
# in the same transaction.
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
my $people_schema = CXGN::People::Schema->connect( sub { $dbh }, { on_connect_do => ['SET search_path TO public, sgn, sgn_people;'] } );

my @success_messages;
my @error_messages;
my $trial_id;
my $brapi_plate_data;

# Any uncaught failure below would otherwise leave the job looking successful, because the finish
# timestamp is recorded whether or not this script exits cleanly.
try {
    store_genotype_trial();
} catch {
    push @error_messages, $_;
};

finish();

=head2 store_genotype_trial()

Saves the plate the submitting job describes.

=cut

sub store_genotype_trial {
    my $sp_person_id = CXGN::People::Person->get_person_by_username($dbh, $username);
    if (!$sp_person_id) {
        die "User not found in the database for username $username.\n";
    }

    my $plate_info = plate_info();

    my $genotyping_project_id = $plate_info->{genotyping_project_id};
    my $project = CXGN::Trial->new({ bcs_schema => $chado_schema, trial_id => $genotyping_project_id });
    my $location_data = $project->get_location();
    my $location_name = $location_data->[1];

    # A plate that was given no description of its own is described the same way the genotyping
    # project it belongs to is.
    my $description = $plate_info->{description} ? $plate_info->{description} : $project->get_description();

    my $program_object = CXGN::BreedersToolbox::Projects->new({ schema => $chado_schema });
    my $breeding_program_data = $program_object->get_breeding_programs_by_trial($genotyping_project_id);
    my $breeding_program_name = $breeding_program_data->[0]->[1];

    my $field_trial_ids = field_trial_ids($plate_info->{design});

    print STDERR "Creating the genotyping plate...\n";

    my $message;
    my $coderef = sub {
        my $ct = CXGN::Trial::TrialCreate->new( {
            chado_schema => $chado_schema,
            dbh => $dbh,
            owner_id => $sp_person_id,
            operator => $username,
            trial_year => $project->get_year(),
            trial_location => $location_name,
            program => $breeding_program_name,
            trial_description => $description,
            design_type => 'genotyping_plate',
            design => $plate_info->{design},
            trial_name => $plate_info->{name},
            is_genotyping => 1,
            genotyping_user_id => $sp_person_id,
            genotyping_project_id => $genotyping_project_id,
            genotyping_facility_submitted => $plate_info->{genotyping_facility_submit},
            genotyping_facility => $project->get_genotyping_facility(),
            genotyping_plate_format => $plate_info->{plate_format},
            genotyping_plate_sample_type => $plate_info->{sample_type},
            genotyping_trial_from_field_trial => $field_trial_ids,
        });

        $message = $ct->save_trial();
    };

    try {
        $chado_schema->txn_do($coderef);
    } catch {
        print STDERR "Transaction Error: $_\n";
        die "Error saving genotyping plate in the database: $_";
    };

    if ($message->{'error'}) {
        die "Error saving genotyping plate in the database: ".$message->{'error'};
    }

#    my $bs = CXGN::BreederSearch->new( { dbh=>$dbh, dbname=>$dbname, } );
#    my $refresh = $bs->refresh_matviews($dbhost, $dbname, $dbuser, $dbpass, 'stockprop', 'concurrent', $basepath);

    $trial_id = $message->{trial_id};
    $brapi_plate_data = build_brapi_plate_data($plate_info, $trial_id);

    push @success_messages, "Successfully stored the genotyping plate.";
}

=head2 plate_info()

Reads the plate this script is to store off the submitting job. Dies if it is not there, since
there is nothing to store without it.

=cut

sub plate_info {
    my $job = CXGN::Job->new({
        sp_job_id => $sp_job_id,
        schema => $chado_schema,
        people_schema => $people_schema
    });

    my $job_args = $job->additional_args() || {};
    my $plate_info = $job_args->{plate_data};
    if (!$plate_info) {
        die "Job $sp_job_id does not describe a genotyping plate to store.\n";
    }

    return $plate_info;
}

=head2 field_trial_ids($design)

Returns the field trials the plate was sampled from, worked out from the stocks the design names.

A plate is normally made from accessions, which say nothing about where they were grown. When it is
made from plots, subplots, plants or tissue samples instead, those belong to a trial, and the link
between the plate and that trial is worth saving.

=cut

sub field_trial_ids {
    my $design = shift;

    my $field_nd_experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'field_layout', 'experiment_type')->cvterm_id();
    my $tissue_sample_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'tissue_sample', 'stock_type')->cvterm_id;
    my $plant_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plant', 'stock_type')->cvterm_id;
    my $plot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plot', 'stock_type')->cvterm_id;
    my $subplot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'subplot', 'stock_type')->cvterm_id;

    my %source_stock_names;
    foreach (values %$design) {
        $source_stock_names{$_->{stock_name}}++;
    }
    my @source_stock_names = keys %source_stock_names;

    my %field_trial_ids;
    my $plant_rs = $chado_schema->resultset('Stock::Stock')->search({'me.uniquename' => {-in => \@source_stock_names}, 'me.type_id' => {-in => [$plot_cvterm_id, $subplot_cvterm_id, $plant_cvterm_id, $tissue_sample_cvterm_id]}, 'nd_experiment_stocks.type_id'=>$field_nd_experiment_type_id, 'nd_experiment.type_id'=>$field_nd_experiment_type_id}, {'join' => {'nd_experiment_stocks' => {'nd_experiment' => 'nd_experiment_projects'}}, '+select'=>['nd_experiment_projects.project_id'], '+as'=>['trial_id']});
    while (my $r = $plant_rs->next) {
        $field_trial_ids{$r->get_column('trial_id')}++;
    }

    return [ keys %field_trial_ids ];
}

=head2 build_brapi_plate_data($plate_info, $trial_id)

Describes the saved plate the way the genotyping facility submission expects it. The samples are
read back out of the stored layout rather than off the design, because only the stored layout knows
the ids the samples were saved under.

=cut

sub build_brapi_plate_data {
    my $plate_info = shift;
    my $trial_id = shift;

    my $saved_layout = CXGN::Trial::TrialLayout->new({schema => $chado_schema, trial_id => $trial_id, experiment_type => 'genotyping_layout'});
    my $saved_design = $saved_layout->get_design();

    my @brapi_samples;
    foreach (values %$saved_design) {
        push @brapi_samples, {
            sampleDbId => $_->{plot_id},
            sampleName => $_->{plot_name},
            well => $_->{plot_number},
            row => $_->{row_number},
            column => $_->{col_number},
            concentration => $_->{concentration},
            volume => $_->{volume},
            tissueType => $_->{tissue_type},
            taxonId => {
                sourceName => 'NCBI',
                taxonId => $_->{ncbi_taxonomy_id}
            }
        };
    }

    return {
        vendorProjectDbId => $plate_info->{project_name},
        clientPlateDbId => $trial_id,
        clientPlateName => $plate_info->{name},
        plateFormat => $plate_info->{plate_format},
        sampleType => $plate_info->{sample_type},
        samples => \@brapi_samples
    };
}

=head2 finish()

Reports what happened back to the submitting job and exits.

The plate that was saved goes back on the job as well as the messages, since the upload dialog hands
it on to the genotyping facility when the uploader asked for that.

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

        if ($trial_id) {
            $job->additional_args->{trial_id} = $trial_id;
        }
        if ($brapi_plate_data) {
            $job->additional_args->{brapi_plate_data} = $brapi_plate_data;
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
