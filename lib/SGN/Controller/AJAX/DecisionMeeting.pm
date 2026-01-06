# lib/SGN/Controller/AJAX/DecisionMeeting.pm
package SGN::Controller::AJAX::DecisionMeeting;
use Moose;
use CXGN::Dataset;
use CXGN::List;
use JSON;
use JSON qw(decode_json);
use Try::Tiny;
use CXGN::BreedersToolbox::Projects;
use SGN::Model::Cvterm;
use CXGN::Trial::TrialCreate;
use CXGN::People::Person;
# lib/SGN/Controller/AJAX/DecisionMeeting.pm



BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    namespace => 'ajax/decisionmeeting',
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
);




# --- sanity check endpoint: GET /ajax/decision_meeting/ping
sub ping : Path('ping') : Args(0) : ActionClass('REST') {}
sub ping_GET {
  my ($self, $c) = @_;
  $c->log->debug('ping_GET() hit');
  print STDERR "### DecisionMeeting ping_GET triggered ###\n";
  $self->status_ok($c, entity => { ok => 1, user => ($c->user ? 1 : 0) });
}

# --- GET /ajax/decision_meeting/lists?type=accessions
# GET /ajax/decision_meeting/lists?type=accessions
sub lists : Path('lists') : Args(0) : ActionClass('REST') {}
sub lists_GET {
    my ($self, $c) = @_;

    $c->log->debug('lists_GET() hit');
    print STDERR "### lists_GET triggered ###\n";

    return $self->status_forbidden($c, message => 'Login required')
      unless $c->user;

    my $owner_id  = $c->user->get_object->get_sp_person_id;
    my $type_name = 'accessions';

    my $chado = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $cvterm_id = $chado->resultset('Cv::Cvterm')
                          ->search({ name => $type_name })
                          ->get_column('cvterm_id')->first;

    unless ($cvterm_id) {
        $c->log->warn("lists_GET: cvterm not found for type '$type_name'");
        return $self->status_ok($c, entity => { lists => [], type_name => $type_name, type_id => undef });
    }

    my $people = $c->dbic_schema('CXGN::People::Schema');

    # If your List table has an 'obsolete' flag, keep it in the filter:
    my $rs = $people->resultset('List')->search(
        { owner => $owner_id, type_id => $cvterm_id },
        { order_by => 'name' }
    );

    my @lists = map {
        +{
          list_id  => int($_->list_id),
          name     => $_->name,
          type_id  => $cvterm_id,
          type_name=> $type_name,
        }
    } $rs->all;

    $self->status_ok($c, entity => { lists => \@lists, type_name => $type_name, type_id => $cvterm_id });
}

# --- ADD: REST endpoint to list breeding programs ---------------------------
sub programs : Path('programs') : ActionClass('REST') { }
sub programs_GET {
    my ($self, $c) = @_;

    return $self->status_forbidden($c, message => 'Login required') unless $c->user;

    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    my $ps     = CXGN::BreedersToolbox::Projects->new({ schema => $schema });
    my $programs = $ps->get_breeding_programs();  # typically [ [id, name, desc, ...], ... ]

    my @items;
    foreach my $p (@{ $programs || [] }) {
        if (ref $p eq 'ARRAY') {
            my ($id, $name) = ($p->[0], $p->[1]);
            push @items, { program_id => $id, name => $name } if defined $id && defined $name;
        } elsif (ref $p eq 'HASH') {
            push @items, {
                program_id => $p->{program_id} // $p->{project_id} // $p->{id},
                name       => $p->{name}       // $p->{project_name},
            };
        }
    }

    return $self->status_ok($c, entity => \@items);
}

# --- ADD: locations REST endpoint -------------------------------------------
sub locations : Path('locations') : ActionClass('REST') { }
sub locations_GET {
    my ($self, $c) = @_;

    return $self->status_forbidden($c, message => 'Login required') unless $c->user;

    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    my $ps     = CXGN::BreedersToolbox::Projects->new({ schema => $schema });

    # Returns AoA: [ [id, description, lat, long, alt, plot_count], ... ]
    my $locs = $ps->get_locations() || [];

    my @items;
    foreach my $r (@$locs) {
        my ($id, $desc, $lat, $lon, $alt, $count) = @$r;
        next unless defined $id;
        push @items, {
            location_id => $id,
            name        => defined $desc && $desc ne '' ? $desc : "Location $id",
            latitude    => $lat,
            longitude   => $lon,
            altitude    => $alt,
            plot_count  => $count,
        };
    }

    return $self->status_ok($c, entity => \@items);
}

# --- GET /ajax/decision_meeting/datasets
sub datasets : Path('datasets') : Args(0) : ActionClass('REST') {}
sub datasets_GET {
  my ($self, $c) = @_;
  $c->log->debug('datasets_GET() hit');
  print STDERR "### datasets_GET triggered ###\n";

  return $self->status_forbidden($c, message => 'Login required') unless $c->user;

  my $phenome = $c->dbic_schema('CXGN::Phenome::Schema');
  my $rs = $phenome->resultset('Dataset')->search( { order_by => 'name' } );

  my @datasets = map +{
    dataset_id => int($_->sp_dataset_id),
    name       => ($_->name // ('Dataset '.$_->sp_dataset_id))
  }, $rs->all;

  $self->status_ok($c, entity => { datasets => \@datasets });
}

# --- GET /ajax/decision_meeting/accessions?dataset_id=NN | list_id=NN
sub accessions : Path('accessions') : Args(0) : ActionClass('REST') {}
sub accessions_GET {
  my ($self, $c) = @_;
  $c->log->debug('accessions_GET() hit');
  print STDERR "### accessions_GET triggered ###\n";

  return $self->status_forbidden($c, message => 'Login required') unless $c->user;

  my $dataset_id    = $c->req->param('dataset_id');
  my $list_id       = $c->req->param('list_id');

  my $people_schema = $c->dbic_schema("CXGN::People::Schema");
  my $schema        = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
  my $dbh           = $c->dbc->dbh;

  my @names;

  if ($dataset_id) {
    my $ds = CXGN::Dataset->new(
      people_schema => $people_schema,
      schema        => $schema,
      sp_dataset_id => $dataset_id
    );
    eval { $ds->retrieve_accessions() };
    if ($ds->can('accessions') && ref($ds->accessions) eq 'ARRAY') {
      @names = @{$ds->accessions};
    } elsif (my $ret = eval { $ds->retrieve_accessions() }) {
      @names = @{ $ret->{data} || [] } if ref($ret) eq 'HASH';
    } elsif ($ds->can('accession_list') && ref($ds->accession_list) eq 'ARRAY') {
      @names = @{$ds->accession_list};
    }
  }
  elsif ($list_id) {
    my $list = CXGN::List->new({ dbh => $dbh, list_id => $list_id });
    my $els  = $list->elements;
    @names   = @$els if $els && ref($els) eq 'ARRAY';
  }

  my @accs = map { +{ accession_id => undef, name => "$_" } } grep { defined && $_ ne '' } @names;
  $self->status_ok($c, entity => { accessions => \@accs });
}

sub create : Path('create') Args(0) {
  my ($self, $c) = @_;
  return $self->status_forbidden($c, message => 'Login required') unless $c->user;

  my $p = $c->req->params;
  $c->log->debug('[DM] create hit. Params=' . join(', ', map {"$_=$p->{$_}"} sort keys %$p));

  my $schema   = $c->dbic_schema('Bio::Chado::Schema');
  my $dbh      = $c->dbc->dbh();
  my $person   = $c->user->get_object;
  my $owner_id = $person->get_sp_person_id;
  my $operator = $person->get_username;

  # Raw inputs
  my $trial_name_in = $p->{meeting_name}     // '';
  my $program_in    = $p->{breeding_program} // '';   # CSV fallback
  my $location_in   = $p->{location}         // '';
  my $trial_year    = $p->{year}             // '';
  my $planting_date = $p->{date}             // undef; # YYYY-MM-DD (optional)
  my $description   = $p->{data}             // '';
  my $meeting_status= $p->{meeting_status}   // '';     # optional

  # Validate required (basic)
  return $self->status_bad_request($c, message => "Missing meeting_name")      unless $trial_name_in;
  return $self->status_bad_request($c, message => "Missing breeding_program")  unless ($program_in || ref($p->{breeding_programs}) eq 'ARRAY');
  return $self->status_bad_request($c, message => "Missing location")          unless $location_in;

  # ---- Normalize breeding program (use FIRST if multiple) -------------------
  my @program_in_list =
      ref($p->{breeding_programs}) eq 'ARRAY'
        ? grep { defined($_) && $_ ne '' } @{$p->{breeding_programs}}
        : (grep { length($_) } map { s/^\s+|\s+$//gr } split(/\s*,\s*/, ($program_in // '')));

  my $program_choice = $program_in_list[0] // '';
  return $self->status_bad_request($c, message => "Missing breeding_program") unless $program_choice;

  # Resolve program/location names if IDs were provided
  my $program_name  = _resolve_program_name($schema, $program_choice)
      or return $self->status_bad_request($c, message => "Breeding program not found: '$program_choice'");
  my $location_name = _resolve_location_name($schema, $location_in)
      or return $self->status_bad_request($c, message => "Location not found: '$location_in'");

  # Resolve names for ALL selected programs (for JSON)
  my @program_name_list = grep { defined($_) && $_ ne '' }
                          map  { scalar _resolve_program_name($schema, $_) } @program_in_list;

  my $trial_name = $trial_name_in;

  # cvterm for the design prop = 'meeting_project'
  my $design_cv        = 'experiment_meeting';    # adjust if your site uses a different CV
  my $design_term      = 'meeting_project';
  my $design_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, $design_term, $design_cv)->cvterm_id;

  # --- Attendees: robust normalization (array / CSV / newline / JSON body) ---
  my @att_raw;

  # 1) Preferred: explicit array from AJAX (attendees_list[])
  if (ref($p->{attendees_list}) eq 'ARRAY') {
      push @att_raw, @{$p->{attendees_list}};
  }

  # 2) Param 'attendees' can be an array (multiple params) or a CSV/newline string
  if (ref($p->{attendees}) eq 'ARRAY') {
      for my $chunk (@{$p->{attendees}}) {
          next unless defined $chunk;
          push @att_raw, split(/\n|,/, $chunk);
      }
  } elsif (defined $p->{attendees} && $p->{attendees} ne '') {
      push @att_raw, split(/\n|,/, $p->{attendees});
  }

  # 3) Fallback: JSON body (if client posted application/json)
  if (!@att_raw) {
      my $bd = eval { $c->req->body_data } || {};
      if (ref($bd->{attendees}) eq 'ARRAY') {
          push @att_raw, @{$bd->{attendees}};
      } elsif (defined $bd->{attendees} && $bd->{attendees} ne '') {
          push @att_raw, split(/\n|,/, $bd->{attendees});
      }
  }

  # 4) Trim + compact + de-duplicate (case-insensitive)
  my @att_clean = grep { length($_) } map { s/^\s+|\s+$//gr } @att_raw;
  my %seen;
  my $attendees = [ grep { my $k = lc($_); !$seen{$k}++ } @att_clean ];

  my $attendees_json = encode_json($attendees);

  # Debug prints
  print("here are atendees $attendees_json \n and breeding_program $program_name \n");

  # Minimal design: no plots now (Decision Meeting => project shell + metadata)
  my $design_hash = {};

  my $tc = CXGN::Trial::TrialCreate->new({
      chado_schema        => $schema,
      dbh                 => $dbh,
      owner_id            => $owner_id,
      operator            => $operator,
      design_type         => 'Meeting',   # custom tag (won’t create plots)
      design              => $design_hash,
      program             => $program_name,       # MUST be name (not id)
      trial_year          => $trial_year,
      planting_date       => $planting_date,
      trial_location      => $location_name,      # MUST be name (not id)
      trial_name          => $trial_name,
      trial_description   => $description,
      project_type        => 'meeting_project',   # creates project_type projectprop
  });

  my ($project_id, $nd_experiment_id);
  my $err;
  try {
      $tc->save_trial(); # throws on duplicate name or bad lookups

      # Prefer IDs returned by the object; fall back to DB lookup if needed
      $project_id       = eval { $tc->get_trial_id }         || eval { $tc->get_project_id } || undef;
      $nd_experiment_id = eval { $tc->get_nd_experiment_id } || undef;

      my $proj_row = $project_id
        ? $schema->resultset('Project::Project')->find({ project_id => $project_id })
        : $schema->resultset('Project::Project')->find({ name => $trial_name });

      die "Project not found after save_trial" unless $proj_row;

      # Ensure $project_id BEFORE using it in logs/props
      $project_id = $proj_row->project_id;

      # --- Save meeting_json directly with explicit type_id -------------------
      my $meeting_payload = {
        attendees               => $attendees,            # arrayref of names
        meeting_status          => ($meeting_status || undef),

        breeding_programs       => \@program_in_list,     # raw selections (ids/strings)
        breeding_program_names  => \@program_name_list,   # resolved names for all selected
        breeding_program_choice => $program_choice,       # value used to create the trial
        breeding_program_name   => $program_name,         # resolved name used to create the trial

        # NEW: include year / date / location in meeting_json
        year                    => ($trial_year || undef),
        date                    => ($planting_date || undef),    # YYYY-MM-DD
        location                => $location_name,               # resolved human label
        location_raw            => $location_in,                 # id or name as provided
      };
      my $val = encode_json($meeting_payload);

      # Get cvterm_id for projectprop type 'meeting_json' (cv 'project_property')
      my $pp_type = SGN::Model::Cvterm->get_cvterm_row($schema, 'meeting_json', 'project_property')
        or die "cvterm meeting_json not found in cv project_property";
      my $type_id = $pp_type->cvterm_id;

      # Upsert: update existing prop if present, else create a new one
      my $existing = $proj_row->search_related('projectprops', { type_id => $type_id })->first;
      if ($existing) {
        $existing->update({ value => $val });
      } else {
        $proj_row->create_related('projectprops', { type_id => $type_id, value => $val });
      }

      $c->log->debug("[DM] meeting_json saved (type_id=$type_id) for project_id=$project_id");

  } catch {
      $err = "$_";
      $c->log->error("DecisionMeeting save trial error: $err");
  };

  if ($err) {
    $c->res->content_type('application/json');
    $c->res->body(encode_json({
        ok   => \0,
        msg  => "Error creating meeting trial: $err",
        echo => {
          meeting_name      => $trial_name_in,
          breeding_programs => \@program_in_list,
          breeding_program  => $program_choice,
          location          => $location_in,
          year              => $trial_year,
          date              => $planting_date,
          attendees         => $attendees,      # normalized list
        },
    }));
    return;
  }

  $c->res->content_type('application/json');
  $c->res->body(encode_json({
      ok                => \1,
      msg               => "Meeting saved as trial '$trial_name' (type=meeting_project).",
      project_id        => $project_id,
      nd_experiment_id  => $nd_experiment_id,
      design_cvterm_id  => $design_cvterm_id,
      echo              => {
        meeting_name      => $trial_name_in,
        breeding_programs => \@program_in_list,
        breeding_program  => $program_name,   # resolved
        location          => $location_name,  # resolved
        year              => $trial_year,
        date              => $planting_date,
        attendees         => $attendees,      # normalized list
      },
  }));
}



# --------- helpers ---------

sub _resolve_program_name {
  my ($schema, $in) = @_;
  return $in unless defined $in && $in =~ /^\d+$/; # already a name
  my $row = $schema->resultset('Project::Project')->find({ project_id => $in });
  return $row ? $row->name : undef;
}

sub _resolve_location_name {
  my ($schema, $in) = @_;
  return $in unless defined $in && $in =~ /^\d+$/; # already a name
  # NdGeolocation row; many Breedbase installs keep location "name" in description
  my $row = $schema->resultset('NaturalDiversity::NdGeolocation')->find({ nd_geolocation_id => $in })
        || $schema->resultset('NdGeolocation')->find({ nd_geolocation_id => $in }); # fallback namespace
  return unless $row;
  return $row->can('description') ? ($row->description // '') : ($row->can('name') ? $row->name : '');
}


# --- GET /ajax/decision_meeting/people
sub people : Path('people') : Args(0) : ActionClass('REST') { }
sub people_GET {
  my ($self, $c) = @_;

  my $dbh = $c->dbc->dbh;
  my $sth = $dbh->prepare(q{
    SELECT first_name, last_name, contact_email
    FROM sgn_people.sp_person
    ORDER BY last_name, first_name
  });
  $sth->execute();

  my @rows;
  while (my ($first_name, $last_name, $contact_email) = $sth->fetchrow_array) {
    push @rows, {
      first_name    => $first_name    // '',
      last_name     => $last_name     // '',
      contact_email => $contact_email // '',
    };
  }
  $sth->finish;

  return $self->status_ok($c, entity => \@rows);
}


sub meetings : Path('meetings') : Args(0) : ActionClass('REST') {}
sub meetings_GET {
    my ($self, $c) = @_;
    my $dbh = $c->dbc->dbh;

    # Lookup cvterms
    my ($design_type_id) = $dbh->selectrow_array(q{
        SELECT cvterm_id FROM public.cvterm WHERE name = 'design' LIMIT 1
    });
    my ($mtg_json_type_id) = $dbh->selectrow_array(q{
        SELECT cvterm_id FROM public.cvterm WHERE name = 'meeting_json' LIMIT 1
    });

    # If we don't have required cvterms, bail with empty list
    if (!$design_type_id || !$mtg_json_type_id) {
        $c->stash->{rest} = { rows => [] };
        $c->detach($c->view('JSON')); return;
    }

    # -------- Query A: all projects flagged as design='Meeting'
    my $sth_a = $dbh->prepare(qq{
        SELECT p.project_id, p.name AS project_name
          FROM project p
          JOIN projectprop pp
            ON pp.project_id = p.project_id
           AND pp.type_id = ?
           AND pp.value   = 'Meeting'   -- exact match per your spec
    });
    $sth_a->execute($design_type_id);

    my @projects;
    my @ids;
    while (my $r = $sth_a->fetchrow_hashref) {
        push @projects, $r;
        push @ids, $r->{project_id};
    }

    # If none, return empty
    if (!@ids) {
        $c->stash->{rest} = { rows => [] };
        $c->detach($c->view('JSON')); return;
    }

    # -------- Query B: meeting_json for those project_ids (latest value per project)
    # Build placeholders for IN (...)
    my $ph = join(',', ('?') x @ids);
    my $sql_b = qq{
        SELECT projectprop_id, project_id, value::text AS meeting_json
          FROM projectprop
         WHERE type_id = ?
           AND project_id IN ($ph)
         ORDER BY projectprop_id DESC
    };
    my $sth_b = $dbh->prepare($sql_b);
    $sth_b->execute($mtg_json_type_id, @ids);

    # Keep the latest meeting_json per project_id
    my %json_for; # project_id => meeting_json
    while (my $r = $sth_b->fetchrow_hashref) {
        next if exists $json_for{ $r->{project_id} }; # already captured latest
        $json_for{ $r->{project_id} } = $r->{meeting_json};
    }

    # Compose final rows only for projects that actually have meeting_json
    my @rows;
    for my $p (@projects) {
        my $pid = $p->{project_id};
        my $mj  = $json_for{$pid};
        next unless defined $mj;
        push @rows, {
            project_id   => $pid,
            project_name => $p->{project_name},
            meeting_json => $mj,            # raw JSON text (client will parse)
        };
    }

    $c->stash->{rest} = { rows => \@rows };
    $c->detach($c->view('JSON'));
}

1;
