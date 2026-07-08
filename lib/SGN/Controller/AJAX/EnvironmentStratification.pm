use strict;

package SGN::Controller::AJAX::EnvironmentStratification;

use Moose;
use File::Temp qw | tempfile |;
use File::Slurp qw | read_file |;
use File::Basename qw | basename |;
use File::Copy;
use File::Spec qw | catfile |;
use CXGN::Dataset;
use CXGN::Dataset::File;
use CXGN::Job;
use JSON::Any;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
);

sub shared_phenotypes : Path('/ajax/environment_stratification/shared_phenotypes') : {
    my $self = shift;
    my $c = shift;
    my $dataset_id = $c->req->param('dataset_id');
    my $exclude_outliers = $c->req->param('dataset_trait_outliers') || 0;

    if (!$dataset_id) {
        $c->stash->{rest} = { error => 'Dataset id is required.' };
        return;
    }

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $people_schema = $c->dbic_schema("CXGN::People::Schema", undef, $sp_person_id);
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado", $sp_person_id);

    my $ds = CXGN::Dataset->new(
        people_schema => $people_schema,
        schema => $schema,
        sp_dataset_id => $dataset_id,
    );
    my $traits = $ds->retrieve_traits();

    $c->tempfiles_subdir("environment_stratification_files");
    my ($fh, $tempfile) = $c->tempfile(TEMPLATE => "environment_stratification_files/trait_XXXXX");
    my $temppath = $c->config->{basepath} . "/" . $tempfile;

    my $ds_file = CXGN::Dataset::File->new(
        people_schema => $people_schema,
        schema => $schema,
        sp_dataset_id => $dataset_id,
        exclude_dataset_outliers => $exclude_outliers,
        exclude_phenotype_outlier => $exclude_outliers,
        file_name => $temppath,
        quotes => 0,
    );
    $ds_file->retrieve_phenotypes();

    $c->stash->{rest} = {
        options => $traits,
        tempfile => $tempfile . "_phenotype.txt",
    };
}

sub extract_trait_data : Path('/ajax/environment_stratification/getdata') Args(0) {
    my $self = shift;
    my $c = shift;

    my $file = basename($c->req->param("file") || '');
    my $trait = $c->req->param("trait");

    if (!$file) {
        $c->stash->{rest} = { error => "Phenotype file is required." };
        return;
    }

    my $temppath = File::Spec->catfile($c->config->{basepath}, "static/documents/tempfiles/environment_stratification_files/" . $file);
    my $F;
    if (!open($F, "<", $temppath)) {
        $c->stash->{rest} = { error => "Can't find data." };
        return;
    }

    my $header = <$F>;
    chomp($header);
    my @keys = split("\t", $header);
    for (my $n = 0; $n < @keys; $n++) {
        $keys[$n] =~ s/\|CO_.*// if $keys[$n] =~ /\|CO_/;
    }

    my @data;
    while (<$F>) {
        chomp;
        my @fields = split "\t";
        my %line;
        for (my $n = 0; $n < @keys; $n++) {
            $line{$keys[$n]} = $fields[$n] if exists($fields[$n]) && defined($fields[$n]);
        }
        push @data, \%line;
    }

    $c->stash->{rest} = { data => \@data, trait => $trait };
}

sub generate_results : Path('/ajax/environment_stratification/generate_results') : {
    my $self = shift;
    my $c = shift;

    my $dataset_id = $c->req->param('dataset_id');
    my $trait_id = $c->req->param('trait_id');
    my $alpha = $c->req->param('alpha') || 0.05;
    my $exclude_outliers = $c->req->param('dataset_trait_outliers') || 0;

    if (!$dataset_id || !$trait_id) {
        $c->stash->{rest} = { error => 'Dataset and trait are required.' };
        return;
    }
    if ($alpha !~ /^\d*\.?\d+$/ || $alpha <= 0 || $alpha >= 1) {
        $c->stash->{rest} = { error => 'Alpha must be a number between 0 and 1.' };
        return;
    }

    $c->tempfiles_subdir("environment_stratification_files");
    my $tmp_output_dir = $c->config->{cluster_shared_tempdir} . "/environment_stratification_files";
    mkdir $tmp_output_dir if !-d $tmp_output_dir;

    my ($tmp_fh, $tempfile) = tempfile(
        "environment_stratification_XXXXX",
        DIR => $tmp_output_dir,
    );

    my $pheno_filepath = $tempfile . "_phenotype.txt";
    my $pairwise_file = $tempfile . "_pairwise.json";
    my $group_summary_file = $tempfile . "_group_summary.json";
    my $group_membership_file = $tempfile . "_group_membership.json";
    my $ungrouped_file = $tempfile . "_ungrouped.json";
    my $summary_file = $tempfile . "_summary.json";
    my $anova_file = $tempfile . "_anova.json";
    my $message_file = $tempfile . "_message.txt";

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $people_schema = $c->dbic_schema("CXGN::People::Schema", undef, $sp_person_id);
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado", $sp_person_id);

    my $ds = CXGN::Dataset::File->new(
        people_schema => $people_schema,
        schema => $schema,
        sp_dataset_id => $dataset_id,
        exclude_dataset_outliers => $exclude_outliers,
        exclude_phenotype_outlier => $exclude_outliers,
        file_name => $tempfile,
        quotes => 0,
    );
    $ds->retrieve_phenotypes($pheno_filepath);

    my $r_trait = $trait_id;
    $r_trait =~ tr/ /\./;
    $r_trait =~ tr/\//\./;

    my $cxgn_tools_run_config = {
        backend => $c->config->{backend},
        submit_host => $c->config->{cluster_host},
        temp_base => $tmp_output_dir,
        queue => $c->config->{'web_cluster_queue'},
        do_cleanup => 0,
        max_cluster_jobs => 1_000_000_000,
    };

    my $cmd_str = join(" ", (
        "Rscript",
        map { _shell_quote($_) } (
            $c->config->{basepath} . "/R/environment_stratification.R",
            $pheno_filepath,
            $r_trait,
            $alpha,
            $pairwise_file,
            $group_summary_file,
            $group_membership_file,
            $ungrouped_file,
            $summary_file,
            $anova_file,
            $message_file,
        )
    ));

    my $user = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $job = CXGN::Job->new({
        schema => $schema,
        people_schema => $people_schema,
        sp_person_id => $user,
        name => $ds->name() . " environment stratification",
        job_type => 'environment_stratification',
        cmd => $cmd_str,
        cxgn_tools_run_config => $cxgn_tools_run_config,
        finish_logfile => $c->config->{job_finish_log},
    });

    $job->submit();
    while ($job->alive()) {
        sleep(1);
    }

    my $finished = $job->read_finish_timestamp();
    if (!$finished) {
        $job->update_status("failed");
        my $message = -e $message_file ? read_file($message_file) : 'Environment stratification failed before producing results.';
        $c->stash->{rest} = { error => $message };
        return;
    }
    $job->update_status("finished");

    my $public_dir = $c->config->{basepath} . "/static/documents/tempfiles/environment_stratification_files";
    mkdir $public_dir if !-d $public_dir;

    foreach my $file ($pairwise_file, $group_summary_file, $group_membership_file, $ungrouped_file, $summary_file, $anova_file, $message_file) {
        copy($file, $public_dir) if -e $file;
    }

    my $json = JSON::Any->new;
    my $message = -e $message_file ? read_file($message_file) : 'Analysis finished.';

    my $pairwise = _read_json_file($json, $pairwise_file);
    my $group_summary = _read_json_file($json, $group_summary_file);
    my $group_membership = _read_json_file($json, $group_membership_file);
    my $ungrouped = _read_json_file($json, $ungrouped_file);
    my $summary = _read_json_file($json, $summary_file);
    my $anova = _read_json_file($json, $anova_file);

    $c->stash->{rest} = {
        message => $message,
        pairwise => $pairwise,
        group_summary => $group_summary,
        group_membership => $group_membership,
        ungrouped => $ungrouped,
        summary => $summary,
        anova => $anova,
        map_locations => _build_map_locations($schema, $group_membership, $ungrouped),
        files => {
            pairwise => "/documents/tempfiles/environment_stratification_files/" . basename($pairwise_file),
            group_summary => "/documents/tempfiles/environment_stratification_files/" . basename($group_summary_file),
            group_membership => "/documents/tempfiles/environment_stratification_files/" . basename($group_membership_file),
            ungrouped => "/documents/tempfiles/environment_stratification_files/" . basename($ungrouped_file),
            summary => "/documents/tempfiles/environment_stratification_files/" . basename($summary_file),
            anova => "/documents/tempfiles/environment_stratification_files/" . basename($anova_file),
        },
    };
}

sub _read_json_file {
    my $json = shift;
    my $file = shift;

    return [] if !$file || !-e $file;
    my $contents = read_file($file);
    return $json->decode($contents || '[]');
}

sub _shell_quote {
    my $value = shift;
    my @parts = split(/'/, $value, -1);
    return "'" . join("'\"'\"'", @parts) . "'";
}

sub _build_map_locations {
    my $schema = shift;
    my $group_membership = shift || [];
    my $ungrouped = shift || [];

    my @rows;
    my %location_names;

    foreach my $row (@$group_membership) {
        next if !$row->{location};
        push @rows, {
            environment => $row->{environment_label} || $row->{environment} || '',
            location => $row->{location},
            trial => $row->{trial} || '',
            year => $row->{year} || '',
            group_id => $row->{group_id} || '',
            group_label => $row->{group_id} || '',
        };
        $location_names{$row->{location}} = 1;
    }

    foreach my $row (@$ungrouped) {
        next if !$row->{location};
        push @rows, {
            environment => $row->{environment_label} || $row->{environment} || '',
            location => $row->{location},
            trial => $row->{trial} || '',
            year => $row->{year} || '',
            group_id => 'Ungrouped',
            group_label => 'Ungrouped',
        };
        $location_names{$row->{location}} = 1;
    }

    return [] if !@rows;

    my %coordinates;
    my @locations = keys %location_names;
    my $rs = $schema->resultset("NaturalDiversity::NdGeolocation")->search({
        description => { -in => \@locations },
    });
    while (my $loc = $rs->next()) {
        $coordinates{$loc->description()} = {
            latitude => $loc->latitude(),
            longitude => $loc->longitude(),
        };
    }

    foreach my $row (@rows) {
        my $coords = $coordinates{$row->{location}} || {};
        $row->{latitude} = $coords->{latitude};
        $row->{longitude} = $coords->{longitude};
        $row->{has_coordinates} = defined($row->{latitude}) && length($row->{latitude}) && defined($row->{longitude}) && length($row->{longitude}) ? 1 : 0;
    }

    return \@rows;
}

1;
