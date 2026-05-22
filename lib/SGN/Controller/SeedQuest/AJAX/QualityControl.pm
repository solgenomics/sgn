
package SGN::Controller::SeedQuest::AJAX::QualityControl;

use Moose;

use Data::Dumper;
use File::Slurp;
use File::Spec qw | catfile |;
use File::Glob qw(bsd_glob);
use JSON::Any;
use File::Basename qw | basename |;
use DateTime;
use Bio::Chado::Schema;
use CXGN::Dataset::File;
use CXGN::Phenotypes::File;
use CXGN::MixedModels;
use SGN::Controller::AJAX::Dataset;
use JSON;


BEGIN { extends 'Catalyst::Controller::REST' };

__PACKAGE__->config(
    default => 'application/json',
    stash_key => 'rest',
    map => { 'application/json' => 'JSON' },
   );

use constant MAX_QC_OUTLIERS => 5000;
use constant MAX_QC_TRAITS   => 200;
use constant MAX_QC_TRIALS   => 500;

sub _positive_int {
    my ($self, $value) = @_;
    return defined $value && $value =~ /^[1-9][0-9]*$/;
}

sub _trait_cvterm_id {
    my ($self, $schema, $trait_name) = @_;
    return undef unless defined $trait_name && $trait_name ne '' && length($trait_name) <= 500;
    my $row = eval { SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, $trait_name) };
    return $row ? $row->cvterm_id : undef;
}

sub _html_escape {
    my ($self, $value) = @_;
    return '' unless defined $value;
    $value =~ s/&/&amp;/g;
    $value =~ s/</&lt;/g;
    $value =~ s/>/&gt;/g;
    $value =~ s/"/&quot;/g;
    $value =~ s/'/&#39;/g;
    return $value;
}

sub prepare: Path('/ajax/seedquest/qualitycontrol/prepare') Args(0) {
    my $self = shift;
    my $c = shift;
    my $dataset_id = $c->req->param('dataset_id');

    if (! $c->user()) {
        $c->stash->{rest} = {error=>'You must be logged in first!'};
        $c->detach;
    }

    unless ($self->_positive_int($dataset_id)) {
        $c->stash->{rest} = { error => 'Invalid dataset_id.' };
        return;
    }

    $c->tempfiles_subdir("qualitycontrol");

    my ($fh, $tempfile) = $c->tempfile(TEMPLATE=>"qualitycontrol/qc_XXXXX");

    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
    my $temppath = $c->config->{basepath}."/".$tempfile;

    my $ds_json = CXGN::Dataset->new(people_schema => $people_schema, schema => $schema, sp_dataset_id => $dataset_id);
    $ds_json->retrieve_traits();
    my $ds_traits = $ds_json->traits();


    # Print extracted traits
    if ($ds_traits && @$ds_traits) {

        my $ds = CXGN::Dataset::File->new(people_schema => $people_schema, schema => $schema, sp_dataset_id => $dataset_id, exclude_dataset_outliers => 1, file_name => $temppath, quotes => 0);
        $ds->retrieve_phenotypes();
        my $pf = CXGN::Phenotypes::File->new( { file => $temppath."_phenotype.txt" });

        my $traits = $pf->traits();

        my $trait_options = "trait_options";
        my $trait_html ="";

        foreach my $trait (@$traits) {
           if ($trait =~ m/.+\d{7}/){
            my $safe_trait = $self->_html_escape($trait);
            $trait_html .= '<input type="checkbox" class="trait_box" name="'.$trait_options.'" value="'.$safe_trait.'">'.$safe_trait.'</input> </br>';
           }
        }


        $c->stash->{rest} = {
            selected_variable => $trait_html,
            tempfile => $tempfile."_phenotype.txt",
        };

    } else {
        $c->stash->{rest} = {
            error => "No traits found in the dataset. Please select a dataset with trial(s) and trait(s).",
        };
    }
}

# ============================================================================
# Shared helper: parse a QC phenotype TSV file into structured data.
# Returns ($data_aref, $unique_names_href) where $data_aref contains
# hash-rows and $unique_names_href maps study names seen in the data.
# ============================================================================

sub _parse_phenotype_file {
    my ($self, $c, $file_param, $trait) = @_;

    my $file = basename($file_param);
    my $temppath = File::Spec->catfile(
        $c->config->{basepath},
        "static/documents/tempfiles/qualitycontrol/" . $file
    );

    my $F;
    unless (open($F, "<", $temppath)) {
        return (undef, undef, "Can't find data.");
    }

    my $header = <$F>;
    chomp($header);
    my @keys = split("\t", $header);

    my @data;
    while (<$F>) {
        chomp;
        my @fields = split "\t";
        my %line;

        for (my $n = 0; $n < @keys; $n++) {
            if (exists($fields[$n]) && defined($fields[$n])) {
                $line{$keys[$n]} = $fields[$n];
            }
        }
        if (defined $line{$trait} && $line{$trait} ne '') {
            push @data, \%line;
        }
    }
    close($F);

    # Collect unique study (project) names from parsed data
    my %unique_names;
    foreach my $entry (@data) {
        if (defined $entry->{'studyName'} && $entry->{'studyName'} ne '') {
            $unique_names{$entry->{'studyName'}} = 1;
        }
    }

    return (\@data, \%unique_names, undef);
}

sub extract_trait_data :Path('/ajax/seedquest/qualitycontrol/grabdata') Args(0) {
    my $self = shift;
    my $c = shift;
    my $dbh = $c->dbc->dbh();

    unless ($c->user()) {
        $c->stash->{rest} = { error => 'You must be logged in first!' };
        return;
    }

    my $file = $c->req->param("file");
    my $trait = $c->req->param("trait");

    # Parse the phenotype TSV via shared helper
    my ($data, $unique_names, $error) = $self->_parse_phenotype_file($c, $file, $trait);
    if ($error) {
        $c->stash->{rest} = { error => $error };
        return;
    }

    # Strip ontology suffix for LIKE matching
    $trait =~ s/\|.*//;
    my $trait_like = $trait . '%';

    # Build parameterized query — no string interpolation in SQL
    my @names = keys %$unique_names;
    unless (@names) {
        $c->stash->{rest} = { data => $data, trait => $trait };
        return;
    }

    my $placeholders = join(',', ('?') x scalar(@names));

    my $trait_sql = qq{
        SELECT project."name" FROM projectprop
        JOIN project ON project.project_id = projectprop.project_id
        WHERE projectprop.type_id = (SELECT cvterm_id FROM cvterm WHERE cvterm."name" = 'validated_phenotype')
        AND project.name IN ($placeholders)
        AND projectprop.value LIKE ?
        GROUP BY project."name"
    };

    my @validated_projects;
    eval {
        my $sth_trait = $dbh->prepare($trait_sql);
        $sth_trait->execute(@names, $trait_like);

        while (my ($project_name) = $sth_trait->fetchrow_array) {
            push @validated_projects, $project_name;
        }

        if (scalar(@validated_projects) > 0) {
            my $list_projects = join(", ", @validated_projects);
            my $message = "Trait $trait is already validated data for trials: $list_projects";
            $c->stash->{rest} = { message => $message };
        } else {
            $c->stash->{rest} = { data => $data, trait => $trait };
        }
    };

    if ($@) {
        $c->stash->{rest} = { error => "Failed to search data: $@" };
        return;
    }
}

sub data_restore :Path('/ajax/seedquest/qualitycontrol/datarestore') Args(0) {
    my $self = shift;
    my $c = shift;

    unless ($c->user()) {
        $c->stash->{rest} = { error => 'You must be logged in first!' };
        return;
    }

    my $file = $c->req->param("file");
    my $trait = $c->req->param("trait");

    # Parse the phenotype TSV via shared helper
    my ($data, $unique_names, $error) = $self->_parse_phenotype_file($c, $file, $trait);
    if ($error) {
        $c->stash->{rest} = { error => $error };
        return;
    }

    my @project_names = keys %$unique_names;
    $c->stash->{rest} = { data => \@project_names, trait => $trait };
}

sub store_outliers : Path('/ajax/seedquest/qualitycontrol/storeoutliers') Args(0) {
    my ($self, $c) = @_;

    my $response_data = {
        is_curator => 0,
    };

    my $user = $c->user();
    unless ($user) {
        $c->stash->{rest} = $response_data;
        return;
    }

    my @user_roles = $user->roles;
    my $curator = (grep { $_ eq 'curator' || $_ eq 'breeder' } @user_roles) ? 1 : 0;
    $response_data->{is_curator} = $curator ? 1 : 0;

    unless ($curator) {
        $c->stash->{rest} = $response_data;
        return;
    }

    my $sp_person_id = $user->get_object()->get_sp_person_id();
    my $operator = $user->get_object()->get_first_name()." ".$user->get_object()->get_last_name();
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $dbh = $schema->storage->dbh;

    # Retrieve and decode the outliers from the request
    my $outliers_string = $c->req->param('outliers');
    my $outliers_data = eval { decode_json($outliers_string || '[]') };
    if ($@ || ref($outliers_data) ne 'ARRAY') {
        $c->stash->{rest} = { error => 'Invalid outlier payload.' };
        return;
    }
    if (@$outliers_data > MAX_QC_OUTLIERS) {
        $c->stash->{rest} = { error => 'Too many outliers in one request.' };
        return;
    }

    my $main_trait = $c->req->param('trait');
    unless (defined $main_trait && $main_trait ne '') {
        $c->stash->{rest} = { error => 'Missing trait.' };
        return;
    }

    my %trait_ids;
    my %study_names;
    my $trait;

    my $othertraits_json = $c->req->param('othertraits');
    my $othertraits = eval { decode_json($othertraits_json || '[]') };
    if ($@ || ref($othertraits) ne 'ARRAY') {
        $c->stash->{rest} = { error => 'Invalid other traits payload.' };
        return;
    }
    if (@$othertraits > MAX_QC_TRAITS) {
        $c->stash->{rest} = { error => 'Too many traits in one request.' };
        return;
    }

    # Remove duplicates using a hash
    my %unique_traits = map { $_ => 1 } grep { defined $_ && $_ ne '' } @$othertraits;
    my @unique_othertraits = keys %unique_traits;

    foreach my $entry (@$outliers_data) {
        if (ref($entry) ne 'HASH') {
            $c->stash->{rest} = { error => 'Invalid outlier row.' };
            return;
        }
        $trait = $entry->{trait};
        my $study_name = $entry->{studyName};
        $study_names{$study_name} = 1 if defined $study_name;
    }

    my @alltraits = ($main_trait, @unique_othertraits);
    foreach my $sel_trait (@alltraits) {
        my $cvterm_id = $self->_trait_cvterm_id($schema, $sel_trait);
        unless ($cvterm_id) {
            $c->stash->{rest} = { error => "Unknown trait: $sel_trait" };
            return;
        }
        $trait_ids{$sel_trait} = $cvterm_id;
    }

    # Build validated trait label: "trait_name|operator_name"
    $main_trait =~ s/\|.*//;
    my $trait_operator = $main_trait."|".$operator;

    my @unique_study_names = keys %study_names;
    unless (@unique_study_names) {
        $c->stash->{rest} = { error => 'No unique study names found.' };
        return;
    }
    if (@unique_study_names > MAX_QC_TRIALS) {
        $c->stash->{rest} = { error => 'Too many trials in one request.' };
        return;
    }

    # Add validated traits to projectprop — parameterized query
    my $study_placeholders = join(', ', ('?') x scalar(@unique_study_names));
    my $trial_sql = qq{
        INSERT INTO projectprop (project_id, type_id, value, rank)
        SELECT
            p.project_id,
            (SELECT cvterm_id FROM cvterm WHERE name = 'validated_phenotype'),
            ?,
            COALESCE(MAX(pp.rank), 0) + 1
        FROM project p
        LEFT JOIN projectprop pp
            ON p.project_id = pp.project_id
            AND pp.type_id = (SELECT cvterm_id FROM cvterm WHERE name = 'validated_phenotype')
        WHERE p.name IN ($study_placeholders)
        GROUP BY p.project_id
    };

    my $experiment_type = SGN::Model::Cvterm->get_cvterm_row($schema, 'phenotyping_experiment', 'experiment_type')->cvterm_id();

    my @plot_names  = map { $_->{plotName} } @$outliers_data;
    my %seen_plots;
    @plot_names = grep { defined $_ && $_ ne '' && !$seen_plots{$_}++ } @plot_names;

    my $transaction_ok = eval {
        local $dbh->{RaiseError} = 1;
        local $dbh->{PrintError} = 0;
        $dbh->begin_work;

        my $sth_trial = $dbh->prepare($trial_sql);
        $sth_trial->execute($trait_operator, @unique_study_names);

        # Proceed only if there are outliers to store
        if (@plot_names) {
            my %seen_traits;
            my @unique_trait_ids = grep { defined $_ && !$seen_traits{$_}++ } values %trait_ids;

            if (@unique_trait_ids) {
                # Build fully parameterized outlier INSERT query
                my $plot_placeholders  = join(', ', ('?') x scalar(@plot_names));
                my $trait_placeholders = join(', ', ('?') x scalar(@unique_trait_ids));

                my $outlier_data_sql = qq{
                    INSERT INTO phenotypeprop (phenotype_id, type_id, value)
                    SELECT phenotype.phenotype_id,
                           cvterm_outlier.cvterm_id,
                           phenotype.value
                    FROM phenotype
                    JOIN nd_experiment_phenotype
                        ON nd_experiment_phenotype.phenotype_id = phenotype.phenotype_id
                    JOIN nd_experiment_stock
                        ON nd_experiment_stock.nd_experiment_id = nd_experiment_phenotype.nd_experiment_id
                    JOIN stock
                        ON stock.stock_id = nd_experiment_stock.stock_id
                    LEFT JOIN phenotypeprop existing_prop
                        ON existing_prop.phenotype_id = phenotype.phenotype_id
                        AND existing_prop.type_id = (SELECT cvterm_id FROM cvterm WHERE name = 'phenotype_outlier')
                    CROSS JOIN (SELECT cvterm_id FROM cvterm WHERE name = 'phenotype_outlier') AS cvterm_outlier
                    WHERE stock.uniquename IN ($plot_placeholders)
                    AND nd_experiment_stock.type_id = ?
                    AND phenotype.observable_id IN ($trait_placeholders)
                    AND existing_prop.phenotype_id IS NULL
                };

                my $sth_outliers = $dbh->prepare($outlier_data_sql);
                $sth_outliers->execute(@plot_names, $experiment_type, @unique_trait_ids);
            }
        }

        $dbh->commit;
        1;
    };

    unless ($transaction_ok) {
        my $err = $@ || $dbh->errstr || 'unknown database error';
        eval { $dbh->rollback if $dbh->{Active} };
        $c->log->error("QC store_outliers: failed to store QC changes: $err");
        $c->stash->{rest} = { error => "Failed to store outlier data: $err" };
        return;
    }

    # Invalidate ANOVA/solGS cache so next run uses updated outlier flags
    $self->_invalidate_analysis_cache($c, \@unique_study_names);

    $c->stash->{rest} = $response_data;
}

sub restore_outliers : Path('/ajax/seedquest/qualitycontrol/restoreoutliers') Args(0) {

    my ($self, $c) = @_;

    my $response_data = {
        is_curator => 0,
    };

    my $user = $c->user();
    unless ($user) {
        $c->stash->{rest} = $response_data;
        return;
    }

    my @user_roles = $user->roles;
    my $curator = (grep { $_ eq 'curator' } @user_roles) ? 'curator' : undef;
    $response_data->{is_curator} = $curator ? 1 : 0;

    unless ($curator && $curator eq 'curator') {
        $c->stash->{rest} = $response_data;
        return;
    }

    my $dbh = $c->dbc->dbh();
    my $sp_person_id = $user->get_object()->get_sp_person_id();
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    # Retrieve and decode the outlier trials from the request
    my $outliers_string = $c->req->param('outliers');
    my $outlier_trials = eval { decode_json($outliers_string || '[]') };
    if ($@) {
        $c->stash->{rest} = { error => 'Invalid restore payload.' };
        return;
    }

    # getting trait name — strip ontology suffix for LIKE matching
    my $trait = $c->req->param('trait');
    unless (defined $trait && $trait ne '') {
        $c->stash->{rest} = { error => 'Missing trait.' };
        return;
    }
    $trait =~ s/\|.*//;
    my $trait_like = $trait . '%';

    # Normalize $outlier_trials to an array of trial name strings
    my @trial_list;
    if (ref($outlier_trials) eq 'ARRAY') {
        @trial_list = @$outlier_trials;
    } elsif (!ref($outlier_trials)) {
        # Scalar string — could be comma-separated
        @trial_list = split(/,\s*/, $outlier_trials);
    }

    unless (@trial_list) {
        $c->stash->{rest} = { error => 'No trial names provided.' };
        return;
    }
    @trial_list = grep { defined $_ && $_ ne '' && length($_) <= 500 } @trial_list;
    unless (@trial_list) {
        $c->stash->{rest} = { error => 'No valid trial names provided.' };
        return;
    }
    if (@trial_list > MAX_QC_TRIALS) {
        $c->stash->{rest} = { error => 'Too many trials in one request.' };
        return;
    }

    my $trial_placeholders = join(', ', ('?') x scalar(@trial_list));

    # Parameterized DELETE: remove validated_phenotype projectprop entries
    my $trial_clean_sql = qq{
        DELETE FROM projectprop
        WHERE projectprop.project_id IN (
            SELECT project.project_id
            FROM project
            WHERE project.name IN ($trial_placeholders)
        )
        AND projectprop.value LIKE ?
        AND projectprop.type_id = (
            SELECT cvterm_id FROM cvterm WHERE name = 'validated_phenotype'
        )
    };

    # Parameterized DELETE: remove phenotypeprop outlier marks
    my $outliers_clean_sql = qq{
        DELETE FROM phenotypeprop
        WHERE phenotypeprop.phenotype_id IN (
            SELECT phenotypeprop.phenotype_id
            FROM phenotypeprop
            JOIN phenotype ph ON phenotypeprop.phenotype_id = ph.phenotype_id
            JOIN nd_experiment_phenotype nep ON nep.phenotype_id = phenotypeprop.phenotype_id
            JOIN nd_experiment_project nes ON nes.nd_experiment_id = nep.nd_experiment_id
            JOIN project pr ON pr.project_id = nes.project_id
            WHERE ph.observable_id IN (
                SELECT cvterm_id FROM cvterm WHERE cvterm.name LIKE ?
            )
            AND pr.name IN ($trial_placeholders)
        )
    };

    my $transaction_ok = eval {
        local $dbh->{RaiseError} = 1;
        local $dbh->{PrintError} = 0;
        $dbh->begin_work;

        my $sth_trial = $dbh->prepare($trial_clean_sql);
        $sth_trial->execute(@trial_list, $trait_like);

        my $sth_clean = $dbh->prepare($outliers_clean_sql);
        $sth_clean->execute($trait_like, @trial_list);

        $dbh->commit;
        1;
    };

    unless ($transaction_ok) {
        my $err = $@ || $dbh->errstr || 'unknown database error';
        eval { $dbh->rollback if $dbh->{Active} };
        $c->stash->{rest} = { error => "Failed to restore data: $err" };
        return;
    }

    $c->stash->{rest} = $response_data;

    # Invalidate ANOVA/solGS cache after restoring outliers
    $self->_invalidate_analysis_cache($c, \@trial_list) if @trial_list;
}

# ============================================================================
# Cache invalidation: clear ANOVA + phenotype cache for affected trials
# so the next run recalculates with current outlier flags.
# ============================================================================

sub _invalidate_analysis_cache {
    my ($self, $c, $trial_names) = @_;
    return unless $trial_names && @$trial_names;

    my $dbh = $c->dbc->dbh;
    my $tmp_dir = $c->config->{cluster_shared_tempdir} || '/home/production/tmp';

    # Resolve trial names to project IDs (parameterized)
    my $placeholders = join(',', ('?') x scalar(@$trial_names));
    my $sth = $dbh->prepare(
        "SELECT project_id FROM project WHERE name IN ($placeholders)"
    );
    $sth->execute(@$trial_names);

    my @trial_ids;
    while (my ($pid) = $sth->fetchrow_array) {
        push @trial_ids, $pid;
    }
    return unless @trial_ids;

    # Delete cache files matching each trial ID under all known cache paths
    for my $tid (@trial_ids) {
        my @patterns = (
            # solGS phenotype data + traits
            "$tmp_dir/*/solgs/cache/phenotype_data_$tid",
            "$tmp_dir/*/solgs/cache/all_traits_pop_$tid",
            "$tmp_dir/*/solgs/cache/traits_*_pop_$tid",
            "$tmp_dir/*/solgs/tempfiles/*${tid}*",
            # ANOVA results under hostname subdir
            "$tmp_dir/*/anova/cache/*${tid}*",
            "$tmp_dir/*/anova/tempfiles/*${tid}*",
            # Direct ANOVA cache (breedbase-site dir, used by Anova.pm)
            "$tmp_dir/breedbase-site/anova/*${tid}*",
        );
        for my $pattern (@patterns) {
            my @files = bsd_glob($pattern);
            unlink @files if @files;
        }
    }
}


1;
