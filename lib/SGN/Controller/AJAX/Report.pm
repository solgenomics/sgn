
=head1 NAME

SGN::Controller::AJAX::Report - Report Factory: run report scripts and show their results

=head1 DESCRIPTION

  GET  /ajax/report/catalog     report scripts and the inputs each one takes (detected from its source)
  GET  /ajax/report/list_info   check a trial / accession / trait list (list_id, kind) and summarise it
  POST /ajax/report/run         start a run (curators): reportData = JSON {reports, start_date, end_date,
                                trial_list_id, accession_list_id, trait_list_id, notify, title}
  GET  /ajax/report/status      progress of a run (run_id)
  GET  /ajax/report/results     status and results of every report of a run (run_id)
  GET  /ajax/report/runs        the user's recent runs
  GET  /ajax/report/download    one file of a run (run_id, file), or the zip of all files
  POST /ajax/report/delete      delete a run (run_id)

Runs live in <cluster_shared_tempdir>/report_factory/<run_id>/ and are run by
bin/report_factory_run.pl as a background job. Report scripts stay in
bin/Reports/ and are listed in the report_engine configuration key; see
CXGN::Report::Catalog for the inputs they can take.

=head1 AUTHOR

Chris Simoes <ccs263@cornell.edu>

=cut

package SGN::Controller::AJAX::Report;

use Moose;
use JSON;
use File::Slurp qw | read_file write_file |;
use File::Path qw | make_path remove_tree |;
use File::Basename qw | basename |;
use POSIX qw | strftime |;
use Try::Tiny;
use CXGN::Job;
use CXGN::List;
use CXGN::List::Transform;
use CXGN::Report::Catalog;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
);

my $RUN_SUBDIR = 'report_factory';
my $RUNNER = 'bin/report_factory_run.pl';
my %LIST_TYPES = ( trials => 'trials', accessions => 'accessions', traits => 'traits' );
my %TRANSFORMS = ( trials => 'projects_2_project_ids', accessions => 'accessions_2_accession_ids', traits => 'traits_2_trait_ids' );

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

sub _user_id {
    my $c = shift;
    return $c->user() ? $c->user()->get_object()->get_sp_person_id() : undef;
}

sub _is_curator {
    my $c = shift;
    return ($c->user() && grep { $_ eq 'curator' } $c->user()->roles()) ? 1 : 0;
}

sub _require_login {
    my $c = shift;
    return 1 if $c->user();
    $c->stash->{rest} = { error => 'You must be logged in to use the Report Factory.' };
    return 0;
}

sub _catalog {
    my $c = shift;
    return CXGN::Report::Catalog->new({ basepath => $c->config->{basepath}, report_engine => $c->config->{report_engine} });
}

sub _runs_dir {
    my $c = shift;
    my $dir = ($c->config->{cluster_shared_tempdir} // '/tmp') . "/$RUN_SUBDIR";
    make_path($dir) if !-d $dir;
    return $dir;
}

sub _valid_run_id {
    my $id = shift;
    return defined($id) && $id =~ /^rf_\d{8}_\d{6}_[a-z0-9]{6}$/ ? 1 : 0;
}

sub _shell_quote {
    my $value = shift;
    return "'" . join("'\"'\"'", split(/'/, $value, -1)) . "'";
}

sub _read_json {
    my $file = shift;
    return if !-e $file;
    return try { decode_json(scalar(read_file($file, binmode => ':raw'))) } catch { undef };
}

# meta of a run that belongs to the user; sets the error otherwise
sub _own_run {
    my ($c, $run_id) = @_;
    if (!_valid_run_id($run_id)) {
        $c->stash->{rest} = { error => 'Invalid report run.' };
        return;
    }
    my $dir = _runs_dir($c) . "/$run_id";
    my $meta = _read_json("$dir/meta.json");
    if (!$meta) {
        $c->stash->{rest} = { error => 'This report run no longer exists.' };
        return;
    }
    if (($meta->{sp_person_id} // -1) != (_user_id($c) // -2)) {
        $c->stash->{rest} = { error => 'This report run belongs to another user.' };
        return;
    }
    return ($meta, $dir);
}

sub _job_args {
    my ($c, %args) = @_;
    return (
        dbhost => $c->config->{dbhost},
        dbname => $c->config->{dbname},
        dbuser => $c->config->{dbuser},
        dbpass => $c->config->{dbpass},
        basepath => $c->config->{basepath},
        %args,
    );
}

# With the Slurm backend a job waits in the queue until a node takes it; when
# no node can (down, drained or invalid) start the run on the web server.
sub _slurm_ready {
    my $c = shift;
    return 1 if lc($c->config->{backend} // '') ne 'slurm';
    my $out = `timeout 5 sinfo -h -o %t 2>/dev/null` // '';
    return scalar(grep { /^\s*(idle|mix|mixed|alloc|allocated|comp|completing)\s*$/ } split /\n/, $out);
}

sub _start_local {
    my ($job, $cmd) = @_;
    my $finish = try { $job->generate_finish_timestamp_cmd() } catch { '' };
    system('setsid nohup bash -c ' . _shell_quote("($cmd$finish)") . ' > /dev/null 2>&1 < /dev/null &');
    try { $job->update_status('submitted') };
}

sub _date_ok {
    my $d = shift;
    return defined($d) && $d =~ /^(\d{4})-(\d{2})-(\d{2})$/ && $2 >= 1 && $2 <= 12 && $3 >= 1 && $3 <= 31 ? 1 : 0;
}

# a list the user may read, of the expected type, resolved to database ids
sub _resolve_list {
    my ($c, $kind, $list_id) = @_;
    return { error => 'Unknown list kind.' } if !$LIST_TYPES{ $kind // '' };
    return { error => 'Invalid list.' } if !defined($list_id) || $list_id !~ /^\d+$/;
    my $sp_person_id = _user_id($c);
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado", $sp_person_id);
    my $dbh = $schema->storage->dbh();
    my ($exists) = $dbh->selectrow_array('SELECT count(*) FROM sgn_people.list WHERE list_id = ?', undef, $list_id);
    return { error => 'This list does not exist.' } if !$exists;
    my $list = try { CXGN::List->new({ dbh => $dbh, list_id => $list_id }) } catch { undef };
    return { error => 'This list does not exist.' } if !$list;
    my $public = try { $list->check_if_public() } catch { 0 };
    if (($list->owner() // -1) != ($sp_person_id // -2) && !$public) {
        return { error => 'This list belongs to another user and is not public.' };
    }
    my $type = $list->type() // '';
    my $expected = $LIST_TYPES{$kind};
    if ($type ne $expected && !($kind eq 'trials' && $type eq 'projects')) {
        return { error => "\"" . $list->name() . "\" is a list of $type; a list of $expected is needed." };
    }
    my @items = @{ $list->elements() || [] };
    my $t = CXGN::List::Transform->new()->transform($schema, $TRANSFORMS{$kind}, \@items) || {};
    my @ids = grep { defined && /^\d+$/ } @{ $t->{transform} || [] };
    my %seen;
    @ids = grep { !$seen{$_}++ } @ids;
    return {
        id      => $list_id + 0,
        name    => $list->name(),
        kind    => $kind,
        n_items => scalar(@items),
        ids     => \@ids,
        missing => [ @{ $t->{missing} || [] } ],
    };
}

# a few facts about the trials of a list, to help choosing the other inputs
sub _trial_facts {
    my ($c, $ids) = @_;
    return {} if !@$ids;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado", _user_id($c));
    my $dbh = $schema->storage->dbh();
    my $in = join(',', map { '?' } @$ids);
    my $q = "SELECT min(p.create_date)::date, max(p.create_date)::date,
                    min(y.value), max(y.value), count(DISTINCT l.value)
             FROM project p
             LEFT JOIN projectprop y ON (y.project_id = p.project_id AND y.type_id = (SELECT cvterm_id FROM cvterm JOIN cv USING(cv_id) WHERE cvterm.name = 'project year' AND cv.name = 'project_property' LIMIT 1))
             LEFT JOIN projectprop l ON (l.project_id = p.project_id AND l.type_id = (SELECT cvterm_id FROM cvterm JOIN cv USING(cv_id) WHERE cvterm.name = 'project location' AND cv.name = 'project_property' LIMIT 1))
             WHERE p.project_id IN ($in)";
    my ($cmin, $cmax, $ymin, $ymax, $nloc) = try { $dbh->selectrow_array($q, undef, @$ids) } catch { () };
    my $q2 = "SELECT count(DISTINCT ph.cvalue_id), count(*)
              FROM nd_experiment_project ep
              JOIN nd_experiment_phenotype nep ON (nep.nd_experiment_id = ep.nd_experiment_id)
              JOIN phenotype ph ON (ph.phenotype_id = nep.phenotype_id)
              WHERE ep.project_id IN ($in)";
    my ($ntraits, $nobs) = try { $dbh->selectrow_array($q2, undef, @$ids) } catch { () };
    return {
        created_from => $cmin, created_to => $cmax,
        year_from => $ymin, year_to => $ymax,
        n_locations => $nloc, n_traits => $ntraits, n_observations => $nobs,
    };
}

sub _run_summary {
    my ($meta, $status) = @_;
    $status ||= {};
    return {
        run_id    => $meta->{run_id},
        title     => $meta->{title},
        created   => $meta->{created},
        reports   => [ map { $_->{title} } @{ $meta->{reports} || [] } ],
        inputs    => $meta->{inputs},
        state     => $status->{state} // 'waiting',
        finished  => $status->{finished},
        zip       => $status->{zip},
    };
}

# ---------------------------------------------------------------------------
# endpoints
# ---------------------------------------------------------------------------

sub catalog : Path('/ajax/report/catalog') Args(0) {
    my ($self, $c) = @_;
    return if !_require_login($c);
    my $person = $c->user()->get_object();
    my $email = $person->get_contact_email() || $person->get_private_email() || '';
    $c->stash->{rest} = {
        reports    => _catalog($c)->reports(),
        is_curator => _is_curator($c),
        email      => $email,
    };
}

sub list_info : Path('/ajax/report/list_info') Args(0) {
    my ($self, $c) = @_;
    return if !_require_login($c);
    my $kind = $c->req->param('kind') // '';
    my $info = _resolve_list($c, $kind, scalar($c->req->param('list_id')));
    if ($info->{error}) {
        $c->stash->{rest} = { error => $info->{error} };
        return;
    }
    my $n = scalar(@{ $info->{ids} });
    $info->{facts} = _trial_facts($c, $info->{ids}) if $kind eq 'trials';
    $info->{n_found} = $n;
    $info->{missing} = [ @{ $info->{missing} }[ 0 .. ($#{ $info->{missing} } > 19 ? 19 : $#{ $info->{missing} }) ] ];
    $info->{n_missing} = $info->{n_items} - $n > 0 ? $info->{n_items} - $n : 0;
    delete $info->{ids};
    $c->stash->{rest} = $info;
}

sub run : Path('/ajax/report/run') Args(0) {
    my ($self, $c) = @_;
    return if !_require_login($c);
    if (!_is_curator($c)) {
        $c->stash->{rest} = { error => 'This is a curator tool. Please contact the database curators to generate a report for you.' };
        return;
    }
    if ($c->req->method() ne 'POST') {
        $c->stash->{rest} = { error => 'Use POST to start a report.' };
        return;
    }
    my $data = try { decode_json(scalar($c->req->param('reportData')) // '') } catch { undef };
    if (ref($data) ne 'HASH') {
        $c->stash->{rest} = { error => 'Invalid request.' };
        return;
    }

    my $catalog = _catalog($c);
    my %seen;
    my @reports = map { $catalog->report($_) } grep { CXGN::Report::Catalog::valid_name($_) && !$seen{$_}++ } @{ ref($data->{reports}) eq 'ARRAY' ? $data->{reports} : [] };
    if (!@reports || grep { !defined } @reports) {
        $c->stash->{rest} = { error => 'Choose at least one report from the list.' };
        return;
    }

    # inputs
    my ($start, $end) = map { defined($_) && $_ ne '' ? $_ : undef } @$data{qw(start_date end_date)};
    my @errors;
    push @errors, 'The start date is not a valid date (YYYY-MM-DD).' if defined($start) && !_date_ok($start);
    push @errors, 'The end date is not a valid date (YYYY-MM-DD).' if defined($end) && !_date_ok($end);
    push @errors, 'Give both a start and an end date, or neither.' if (defined($start) xor defined($end));
    push @errors, 'The start date is after the end date.' if defined($start) && defined($end) && !@errors && $start gt $end;
    my %lists;
    foreach my $kind (qw(trials accessions traits)) {
        my $list_id = $data->{ ($kind =~ s/s$//r) . '_list_id' };
        next if !defined($list_id) || $list_id eq '';
        # only lists some chosen report reads
        next if !grep { $_->{inputs}->{$kind} } @reports;
        my $info = _resolve_list($c, $kind, $list_id);
        if ($info->{error}) { push @errors, $info->{error}; next; }
        if (!@{ $info->{ids} }) { push @errors, "None of the items of the list \"$info->{name}\" were found in the database."; next; }
        $lists{$kind} = $info;
    }
    my %given = (dates => (defined($start) && defined($end) ? 1 : 0), map { $_ => ($lists{$_} ? 1 : 0) } qw(trials accessions traits));
    push @errors, $catalog->validate_inputs($_, \%given) for @reports;
    if (@errors) {
        $c->stash->{rest} = { error => join("\n", @errors) };
        return;
    }

    # run directory
    my $sp_person_id = _user_id($c);
    my $stamp = strftime('%Y%m%d_%H%M%S', localtime);
    my $run_id = "rf_${stamp}_" . join('', map { ('a'..'z', 0..9)[int(rand(36))] } 1 .. 6);
    my $dir = _runs_dir($c) . "/$run_id";
    make_path($dir);
    chmod(0770, $dir);
    foreach my $kind (keys %lists) {
        write_file("$dir/$kind.txt", join("\n", @{ $lists{$kind}->{ids} }) . "\n");
    }

    my @run_reports;
    foreach my $r (@reports) {
        my %args;
        if ($r->{inputs}->{dates} && $given{dates}) { $args{start_date} = $start; $args{end_date} = $end; }
        foreach my $kind (keys %lists) {
            $args{"${kind}_file"} = "$kind.txt" if $r->{inputs}->{$kind};
        }
        push @run_reports, { name => $r->{name}, title => $r->{title}, prefix => "$r->{name}_$stamp", args => \%args };
    }

    my $notify = $data->{notify} && $data->{notify} ne 'false';
    my $person = $c->user()->get_object();
    my $email = $person->get_contact_email() || $person->get_private_email() || '';
    my $title = (defined($data->{title}) && !ref($data->{title}) && $data->{title} =~ /\S/) ? substr($data->{title}, 0, 120) : join(', ', map { $_->{title} } @reports);
    my $site = $c->config->{main_production_site_url} || $c->req->base;
    $site =~ s{/+$}{};

    my %meta = (
        run_id       => $run_id,
        sp_person_id => $sp_person_id,
        created      => time(),
        title        => $title,
        basepath     => $c->config->{basepath},
        site_url     => "$site",
        notify_email => ($notify && $email =~ /^[^\s@]+@[^\s@]+$/ ? $email : undef),
        reports      => \@run_reports,
        inputs       => {
            (defined($start) ? (start_date => $start, end_date => $end) : ()),
            map { $_ => { id => $lists{$_}->{id}, name => $lists{$_}->{name}, n => scalar(@{ $lists{$_}->{ids} }) } } keys %lists,
        },
    );
    # the runner reads the connection and deletes the file: the password never goes in the job command
    write_file("$dir/dbconf.json", { perms => oct(600) }, encode_json({ map { $_ => $c->config->{$_} } qw(dbhost dbname dbuser dbpass) }));
    chmod(0600, "$dir/dbconf.json");

    my $basepath = $c->config->{basepath};
    my $cmd = join(' ', 'perl', '-I' . _shell_quote("$basepath/lib"), _shell_quote("$basepath/$RUNNER"), _shell_quote($dir))
        . ' > ' . _shell_quote("$dir/runner.log") . ' 2>&1';

    my $people_schema = $c->dbic_schema("CXGN::People::Schema", undef, $sp_person_id);
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado", $sp_person_id);
    my $job;
    try {
        $job = CXGN::Job->new({ _job_args($c,
            schema => $schema,
            people_schema => $people_schema,
            sp_person_id => $sp_person_id,
            name => "Report Factory: $title",
            job_type => 'report',
            cmd => $cmd,
            results_page => "/tools/report?run_id=$run_id",
            cxgn_tools_run_config => {
                backend => $c->config->{backend},
                submit_host => $c->config->{cluster_host},
                temp_base => $dir,
                queue => $c->config->{'web_cluster_queue'},
                do_cleanup => 0,
                max_cluster_jobs => 1_000_000_000,
            },
        ) });
        if (_slurm_ready($c)) {
            $job->submit();
        } else {
            print STDERR "Report Factory: no Slurm node available, starting run $run_id on the web server\n";
            $job->store();
            _start_local($job, $cmd);
            $meta{started_locally} = 1;
        }
    } catch {
        $c->stash->{rest} = { error => "Could not start the report: $_" };
    };
    if ($c->stash->{rest}) {
        unlink("$dir/dbconf.json");
        return;
    }
    $meta{job_id} = $job->sp_job_id();
    $meta{cmd} = $cmd;
    write_file("$dir/meta.json", { binmode => ':raw' }, encode_json(\%meta));

    $c->stash->{rest} = { run_id => $run_id, job_id => $meta{job_id} };
}

sub status : Path('/ajax/report/status') Args(0) {
    my ($self, $c) = @_;
    return if !_require_login($c);
    my ($meta, $dir) = _own_run($c, scalar($c->req->param('run_id')));
    return if !$meta;
    my $status = _read_json("$dir/status.json");

    if (!$status) {
        # not started: the job may wait for a Slurm node that never comes
        if (!$meta->{started_locally} && $meta->{cmd} && !_slurm_ready($c)) {
            print STDERR "Report Factory: run $meta->{run_id} waits for an unavailable Slurm node, starting it on the web server\n";
            my $people_schema = $c->dbic_schema("CXGN::People::Schema", undef, _user_id($c));
            my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado", _user_id($c));
            my $job = try { CXGN::Job->new({ _job_args($c, schema => $schema, people_schema => $people_schema, sp_job_id => $meta->{job_id}) }) } catch { undef };
            if ($job) {
                try { $job->cancel() };
                $meta->{started_locally} = 1;
                write_file("$dir/meta.json", { binmode => ':raw' }, encode_json($meta));
                _start_local($job, $meta->{cmd});
            }
        }
        my $waited = time() - ($meta->{created} // time());
        my $runner_log = -e "$dir/runner.log" ? read_file("$dir/runner.log") : '';
        if ($runner_log =~ /\S/ && !-e "$dir/dbconf.json") {
            # the runner started and died before writing its status
            $c->stash->{rest} = { state => 'failed', error => "The report runner stopped:\n" . substr($runner_log, -2000) };
            return;
        }
        $c->stash->{rest} = {
            state => 'waiting',
            progress => 'Waiting in the job queue' . ($waited > 120 ? sprintf(' for %d min. The job cluster may be busy; if this lasts, please contact the site administrator.', $waited / 60) : ''),
        };
        return;
    }
    $c->stash->{rest} = $status;
}

sub results : Path('/ajax/report/results') Args(0) {
    my ($self, $c) = @_;
    return if !_require_login($c);
    my ($meta, $dir) = _own_run($c, scalar($c->req->param('run_id')));
    return if !$meta;
    my $status = _read_json("$dir/status.json") || { state => 'waiting', reports => [] };
    my %by_name = map { $_->{name} => $_ } @{ $status->{reports} || [] };
    my @reports;
    foreach my $r (@{ $meta->{reports} || [] }) {
        my $st = $by_name{ $r->{name} } || { state => 'waiting' };
        my $results = ($st->{has_results} && $r->{prefix} =~ /^[A-Za-z0-9_.-]+$/) ? _read_json("$dir/$r->{prefix}.results.json") : undef;
        push @reports, { %$st, name => $r->{name}, title => $r->{title}, args => $r->{args}, results => $results };
    }
    $c->stash->{rest} = {
        run   => _run_summary($meta, $status),
        state => $status->{state},
        reports => \@reports,
    };
}

sub runs : Path('/ajax/report/runs') Args(0) {
    my ($self, $c) = @_;
    return if !_require_login($c);
    my $sp_person_id = _user_id($c);
    my $base = _runs_dir($c);
    opendir(my $dh, $base) or do { $c->stash->{rest} = { runs => [] }; return; };
    my @ids = sort { $b cmp $a } grep { _valid_run_id($_) && -d "$base/$_" } readdir($dh);
    closedir($dh);
    my @runs;
    foreach my $id (@ids) {
        my $meta = _read_json("$base/$id/meta.json") or next;
        next if ($meta->{sp_person_id} // -1) != $sp_person_id;
        push @runs, _run_summary($meta, _read_json("$base/$id/status.json"));
        last if @runs >= 30;
    }
    $c->stash->{rest} = { runs => \@runs };
}

sub download : Path('/ajax/report/download') Args(0) {
    my ($self, $c) = @_;
    return if !_require_login($c);
    my ($meta, $dir) = _own_run($c, scalar($c->req->param('run_id')));
    return if !$meta;
    my $file = $c->req->param('file') // '';
    my $status = _read_json("$dir/status.json") || {};
    my %allowed = map { $_ => 1 } grep { defined } ($status->{zip}, map { @{ $_->{files} || [] } } @{ $status->{reports} || [] });
    if ($file !~ /^[A-Za-z0-9_.-]+$/ || !$allowed{$file} || !-f "$dir/$file") {
        $c->stash->{rest} = { error => 'This file is not part of the report.' };
        return;
    }
    my %types = (xlsx => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', csv => 'text/csv', zip => 'application/zip', txt => 'text/plain', json => 'application/json', pdf => 'application/pdf', html => 'text/html');
    my ($ext) = $file =~ /\.([A-Za-z0-9]+)$/;
    open(my $fh, '<:raw', "$dir/$file") or do { $c->stash->{rest} = { error => 'Cannot read the file.' }; return; };
    $c->res->content_type($types{ lc($ext // '') } // 'application/octet-stream');
    $c->res->header('Content-Disposition', qq{attachment; filename="$file"});
    $c->res->body($fh);
}

sub delete_run : Path('/ajax/report/delete') Args(0) {
    my ($self, $c) = @_;
    return if !_require_login($c);
    if ($c->req->method() ne 'POST') {
        $c->stash->{rest} = { error => 'Use POST to delete a report.' };
        return;
    }
    my ($meta, $dir) = _own_run($c, scalar($c->req->param('run_id')));
    return if !$meta;
    my $status = _read_json("$dir/status.json");
    if (!$status || ($status->{state} // '') eq 'running') {
        $c->stash->{rest} = { error => 'This report is still running.' };
        return;
    }
    remove_tree($dir);
    $c->stash->{rest} = { success => 1 };
}

1;
