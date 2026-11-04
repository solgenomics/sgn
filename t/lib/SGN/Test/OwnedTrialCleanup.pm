package SGN::Test::OwnedTrialCleanup;

use strict;
use warnings;
use Text::CSV;
use JSON::XS;

my @pending;

=head1 NAME

SGN::Test::OwnedTrialCleanup - isolate the two committed observation HTTP tests

=head1 SYNOPSIS

 my $owned = SGN::Test::OwnedTrialCleanup->new(
     schema => $schema, label => 'provenance',
     trial_name => $tag.'_trial', stock_names => [$tag.'_plot'],
     %{SGN::Test::OwnedTrialCleanup->cutoffs($schema)},
     phenotype_names => [$tag.'_A', $tag.'_B'], # optional stricter ownership
 );
 # Create the named trial, make HTTP requests, then:
 $owned->cleanup;

=head1 CONTRACT

Create the helper before writing any test rows. All stock names must be unique
and exclusive to this test. All three ID cutoffs are mandatory. Cleanup proves
ownership of every experiment, phenotype and file before deleting exact IDs.
It never rewinds sequences. Existing metadata IDs are preserved even when no
file references them; foreign-key constraints protect other metadata users.
The helper owns only the two observation regression callers, not arbitrary
fixture changes. Standard project phenotype deletion is asynchronous and is
unsuitable for isolation between sequential HTTP tests.

An unlinked archive is attributable only when its nonempty, valid CSV contains
exclusively owned observationUnitDbIds. Zero-row and unknown archives are left
alone; a global file-ID cutoff is not proof of ownership.

Set SGN_TEST_OWNED_TRIAL_FAIL to LABEL:after_creation, LABEL:after_http_store or
LABEL:before_cleanup for deliberate failure injection. Set
SGN_TEST_OWNED_TRIAL_EVIDENCE to an existing directory to record before/after
row counts and the original trial137 layout/observations/file links as JSON.
END cleanup runs after failure and preserves the original nonzero exit status.

=cut

sub cutoffs {
    my ($class, $schema) = @_;
    my $db = $schema->storage->dbh;
    return {
        before_file_id => $db->selectrow_array('SELECT coalesce(max(file_id),0) FROM metadata.md_files'),
        before_phenotype_id => $db->selectrow_array('SELECT coalesce(max(phenotype_id),0) FROM phenotype'),
        before_metadata_id => $db->selectrow_array('SELECT coalesce(max(metadata_id),0) FROM metadata.md_metadata'),
    };
}

sub new {
    my ($class, %args) = @_;
    for my $key (qw(schema label trial_name stock_names before_file_id before_phenotype_id before_metadata_id)) {
        die "Missing owned-trial cleanup argument $key" unless defined $args{$key};
    }
    die 'Owned stock names cannot be empty' unless @{$args{stock_names}};
    my $db = $args{schema}->storage->dbh;
    die 'Owned trial name already exists' if $db->selectrow_array('SELECT count(*) FROM project WHERE name=?', undef, $args{trial_name});
    for my $name (@{$args{stock_names}}) {
        die "Owned stock name already exists: $name" if $db->selectrow_array('SELECT count(*) FROM stock WHERE uniquename=?', undef, $name);
    }
    $args{phenotype_names} = {map { $_ => 1 } @{$args{phenotype_names}}} if $args{phenotype_names};
    my $self = bless {%args, archive_paths => [], done => 0}, $class;
    push @pending, $self;
    $self->record_evidence('before');
    return $self;
}

sub checkpoint {
    my ($self, $stage) = @_;
    die "Deliberate owned-trial failure: $self->{label}:$stage\n"
        if ($ENV{SGN_TEST_OWNED_TRIAL_FAIL} // '') eq "$self->{label}:$stage";
}

sub record_evidence {
    my ($self, $stage) = @_;
    my $dir = $ENV{SGN_TEST_OWNED_TRIAL_EVIDENCE};
    return unless defined $dir;
    die "Evidence directory does not exist: $dir" unless -d $dir;
    my $db = $self->{schema}->storage->dbh;
    my %counts;
    for my $table (qw(project projectprop project_relationship stock stockprop stock_relationship phenotype phenotypeprop nd_experiment nd_experimentprop nd_experiment_protocol nd_experiment_project nd_experiment_stock nd_experiment_phenotype metadata.md_files metadata.md_metadata phenome.nd_experiment_md_files phenome.project_owner phenome.stock_owner)) {
        $counts{$table} = $db->selectrow_array("SELECT count(*) FROM $table");
    }
    my $snapshot = {
        stocks => $db->selectall_arrayref('SELECT DISTINCT s.stock_id,s.name,s.uniquename FROM nd_experiment_project p JOIN nd_experiment_stock es USING(nd_experiment_id) JOIN stock s USING(stock_id) WHERE p.project_id=137 ORDER BY s.stock_id'),
        stockprops => $db->selectall_arrayref('SELECT DISTINCT sp.stockprop_id,sp.stock_id,sp.type_id,sp.value,sp.rank FROM nd_experiment_project p JOIN nd_experiment_stock es USING(nd_experiment_id) JOIN stockprop sp USING(stock_id) WHERE p.project_id=137 ORDER BY sp.stockprop_id'),
        relationships => $db->selectall_arrayref('SELECT DISTINCT r.stock_relationship_id,r.subject_id,r.object_id,r.type_id,r.value,r.rank FROM nd_experiment_project p JOIN nd_experiment_stock es USING(nd_experiment_id) JOIN stock_relationship r ON r.subject_id=es.stock_id OR r.object_id=es.stock_id WHERE p.project_id=137 ORDER BY r.stock_relationship_id'),
        observations => $db->selectall_arrayref('SELECT DISTINCT ph.phenotype_id,ph.uniquename,ph.value,ph.operator,ph.collect_date FROM nd_experiment_project p JOIN nd_experiment_phenotype ep USING(nd_experiment_id) JOIN phenotype ph USING(phenotype_id) WHERE p.project_id=137 ORDER BY ph.phenotype_id'),
        files => $db->selectall_arrayref('SELECT DISTINCT f.file_id,f.nd_experiment_id FROM nd_experiment_project p JOIN phenome.nd_experiment_md_files f USING(nd_experiment_id) WHERE p.project_id=137 ORDER BY f.file_id,f.nd_experiment_id'),
    };
    open(my $fh, '>:raw', "$dir/$self->{label}-$stage.json") or die "Cannot write cleanup evidence: $!";
    print {$fh} JSON::XS->new->canonical->encode({counts=>\%counts, original_trial137=>$snapshot});
    close($fh) or die "Cannot close cleanup evidence: $!";
}

sub cleanup {
    my ($self) = @_;
    return 1 if $self->{done};
    $self->{schema}->txn_do(sub {
        my $db = $self->{schema}->storage->dbh;
        my ($trial_id) = $db->selectrow_array('SELECT project_id FROM project WHERE name=?', undef, $self->{trial_name});
        my @names = @{$self->{stock_names}};
        my $placeholders = join(',', ('?') x @names);
        my $plot_ids = $db->selectcol_arrayref("SELECT stock_id FROM stock WHERE uniquename IN ($placeholders)", undef, @names);
        my %owned_plots = map { $_ => 1 } @$plot_ids;
        return if !$trial_id && !@$plot_ids;
        die 'Own plot exists without its trial' if !$trial_id;
        my $experiment_ids = $db->selectcol_arrayref('SELECT nd_experiment_id FROM nd_experiment_project WHERE project_id=?', undef, $trial_id);
        my %experiments = map { $_ => 1 } @$experiment_ids;
        my %files;
        for my $id (@$experiment_ids) {
            $files{$_} = 1 for @{$db->selectcol_arrayref('SELECT file_id FROM phenome.nd_experiment_md_files WHERE nd_experiment_id=?', undef, $id)};
        }
        # Recover a request archive even if the HTTP request died before the
        # experiment/file link was committed. Its CSV units must all be ours.
        my $candidates = $db->selectall_arrayref("SELECT file_id,dirname,basename FROM metadata.md_files WHERE file_id>? AND filetype='brapi observations'", {Slice=>{}}, $self->{before_file_id});
        for my $file (@$candidates) {
            next if $files{$file->{file_id}};
            my $path = $file->{dirname}.'/'.$file->{basename};
            next unless -f $path;
            open(my $input, '<:raw', $path) or die "Cannot inspect candidate archive $path: $!";
            my $csv = Text::CSV->new({binary=>1});
            my $header = $csv->getline($input) || [];
            my ($unit_column) = grep { $header->[$_] eq 'observationUnitDbId' } 0..$#$header;
            my ($rows, $foreign) = (0, 0);
            if (defined $unit_column) {
                while (my $row = $csv->getline($input)) {
                    $rows++;
                    $foreign++ unless defined($row->[$unit_column]) && $owned_plots{$row->[$unit_column]};
                }
            }
            $foreign++ if defined($unit_column) && !$csv->eof;
            close($input) or die "Cannot close archive $path: $!";
            $files{$file->{file_id}} = 1 if $rows && !$foreign;
        }
        # An upload may also create a file-only experiment. Include it only
        # through an archive already attached to this test's owning experiment.
        for my $file_id (keys %files) {
            die "Archive $file_id predates this test" unless $file_id > $self->{before_file_id};
            $experiments{$_} = 1 for @{$db->selectcol_arrayref('SELECT nd_experiment_id FROM phenome.nd_experiment_md_files WHERE file_id=?', undef, $file_id)};
        }
        my %phenotypes;
        for my $id (keys %experiments) {
            die "Experiment $id belongs to another trial" if $db->selectrow_array('SELECT count(*) FROM nd_experiment_project WHERE nd_experiment_id=? AND project_id<>?', undef, $id, $trial_id);
            for my $stock_id (@{$db->selectcol_arrayref('SELECT stock_id FROM nd_experiment_stock WHERE nd_experiment_id=?', undef, $id)}) {
                die "Experiment $id contains another stock" unless $owned_plots{$stock_id};
            }
            $phenotypes{$_} = 1 for @{$db->selectcol_arrayref('SELECT phenotype_id FROM nd_experiment_phenotype WHERE nd_experiment_id=?', undef, $id)};
        }
        for my $id (keys %phenotypes) {
            die "Phenotype $id predates this test" unless $id > $self->{before_phenotype_id};
            if ($self->{phenotype_names}) {
                my ($name) = $db->selectrow_array('SELECT uniquename FROM phenotype WHERE phenotype_id=?', undef, $id);
                die "Phenotype $id has an unexpected name" unless $self->{phenotype_names}{$name};
            }
            for my $exp (@{$db->selectcol_arrayref('SELECT nd_experiment_id FROM nd_experiment_phenotype WHERE phenotype_id=?', undef, $id)}) {
                die "Phenotype $id is shared outside owned graph" unless $experiments{$exp};
            }
        }
        for my $id (keys %phenotypes) {
            $self->{schema}->resultset('Phenotype::Phenotype')->find($id)->delete;
        }
        # Delete synchronously: Project::delete_phenotype_data launches an
        # asynchronous helper and can race the next HTTP fixture test.
        for my $id (keys %experiments) {
            $db->do('DELETE FROM phenome.nd_experiment_md_files WHERE nd_experiment_id=?', undef, $id);
            $self->{schema}->resultset('NaturalDiversity::NdExperiment')->find($id)->delete;
        }
        for my $id (keys %files) {
            die "Archive $id is shared" if $db->selectrow_array('SELECT count(*) FROM phenome.nd_experiment_md_files WHERE file_id=?', undef, $id);
            my ($metadata_id, $dirname, $basename) = $db->selectrow_array('SELECT metadata_id,dirname,basename FROM metadata.md_files WHERE file_id=?', undef, $id);
            die "Archive $id shares its physical path" if $db->selectrow_array('SELECT count(*) FROM metadata.md_files WHERE file_id<>? AND dirname=? AND basename=?', undef, $id, $dirname, $basename);
            push @{$self->{archive_paths}}, $dirname.'/'.$basename if defined($dirname) && defined($basename);
            $db->do('DELETE FROM metadata.md_files WHERE file_id=?', undef, $id);
            if ($metadata_id > $self->{before_metadata_id}) {
                $db->do('DELETE FROM metadata.md_metadata WHERE metadata_id=? AND NOT EXISTS (SELECT 1 FROM metadata.md_files WHERE metadata_id=?)', undef, $metadata_id, $metadata_id);
            }
        }
        for my $plot_id (@$plot_ids) {
            $db->do('DELETE FROM phenome.stock_owner WHERE stock_id=?', undef, $plot_id);
            $self->{schema}->resultset('Stock::Stock')->find($plot_id)->delete;
        }
        $db->do('DELETE FROM phenome.project_owner WHERE project_id=?', undef, $trial_id);
        $self->{schema}->resultset('Project::Project')->find($trial_id)->delete;
    });
    for my $path (@{$self->{archive_paths}}) {
        unlink($path) or die "Cannot remove owned archive $path: $!" if -f $path;
    }

    $self->{done} = 1;
    $self->record_evidence('after');
    return 1;
}

END {
    my $status = $?;
    for my $self (reverse @pending) {
        next if $self->{done};
        eval { $self->cleanup; 1 } or do {
            warn "Owned trial cleanup failed for $self->{label}: $@";
            $status = 1 unless $status;
        };
    }
    $? = $status;
}

1;
