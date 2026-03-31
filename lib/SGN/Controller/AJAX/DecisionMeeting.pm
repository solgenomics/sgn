# lib/SGN/Controller/AJAX/DecisionMeeting.pm
package SGN::Controller::AJAX::DecisionMeeting;
use Moose;
use CXGN::List;
use JSON;
use JSON qw(decode_json);
use JSON qw(encode_json);
use Try::Tiny;
use CXGN::BreedersToolbox::Projects;
use SGN::Model::Cvterm;
use CXGN::Trial::TrialCreate;
use CXGN::People::Person;
use CXGN::Dataset;
use CXGN::Dataset::File;
use CXGN::Phenotypes::File;
use File::Spec qw(catfile);
use File::Basename qw(basename);
use Scalar::Util qw(looks_like_number);



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

# --- GET /ajax/decisionmeeting/decisions?list_id=NN
sub decisions : Path('decisions') : Args(0) : ActionClass('REST') { }
sub decisions_GET {
    my ($self, $c) = @_;

    $c->log->debug('decisions_GET() hit');
    print STDERR "### decisions_GET triggered ###\n";

    return $self->status_forbidden($c, message => 'Login required') unless $c->user;

    my $list_id = $c->req->param('list_id');
    return $self->status_bad_request($c, message => 'Missing list_id') unless $list_id;

    my $dbh    = $c->dbc->dbh;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    my $decision_format = $c->config->{decision_format} || 'state,yy,stage';
    my $breeding_stages = $c->config->{breeding_stages} || 'T1,T2,Y1,Y2,Y3,Y4,Y5';

    # Adjust these if your stockprop cvterm names are different
    my $notes_prop_name = 'notes';
    my $year_prop_name  = 'acquisition date';

    # 1) get accession names from the list
    my $list = CXGN::List->new({ dbh => $dbh, list_id => $list_id });
    my $els  = $list->elements || [];
    my @accessions = grep { defined $_ && $_ ne '' } @$els;

    return $self->status_ok($c, entity => { rows => [] }) unless @accessions;

    # 2) get breeding programs
    my $ps       = CXGN::BreedersToolbox::Projects->new({ schema => $schema });
    my $programs = $ps->get_breeding_programs() || [];

    my @program_names;
    my %seen_program;
    foreach my $p (@$programs) {
        my $nm = '';
        if (ref($p) eq 'ARRAY') {
            $nm = $p->[1] // '';
        }
        elsif (ref($p) eq 'HASH') {
            $nm = $p->{name} // $p->{project_name} // '';
        }
        next unless defined $nm && $nm ne '';
        next if $seen_program{$nm}++;
        push @program_names, $nm;
    }

    # 3) prepare pedigree lookup once for all accessions
    my %pedigree_by_acc;
    if (@accessions) {
        my $female_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'female_parent', 'stock_relationship');
        my $male_cvterm   = SGN::Model::Cvterm->get_cvterm_row($schema, 'male_parent',   'stock_relationship');

        my $female_type_id = $female_cvterm ? $female_cvterm->cvterm_id : undef;
        my $male_type_id   = $male_cvterm   ? $male_cvterm->cvterm_id   : undef;

        if ($female_type_id || $male_type_id) {
            my $placeholders = join(',', ('?') x @accessions);

            my @bind = ();
            my $sql = qq{
                SELECT
                    s.uniquename AS accession,
                    mother.uniquename AS female_parent,
                    father.uniquename AS male_parent
                FROM stock s
            };

            if ($female_type_id) {
                $sql .= qq{
                    LEFT JOIN stock_relationship m_rel
                        ON s.stock_id = m_rel.object_id
                       AND m_rel.type_id = ?
                    LEFT JOIN stock mother
                        ON m_rel.subject_id = mother.stock_id
                };
                push @bind, $female_type_id;
            } else {
                $sql .= qq{
                    LEFT JOIN stock mother
                        ON 1=0
                };
            }

            if ($male_type_id) {
                $sql .= qq{
                    LEFT JOIN stock_relationship f_rel
                        ON s.stock_id = f_rel.object_id
                       AND f_rel.type_id = ?
                    LEFT JOIN stock father
                        ON f_rel.subject_id = father.stock_id
                };
                push @bind, $male_type_id;
            } else {
                $sql .= qq{
                    LEFT JOIN stock father
                        ON 1=0
                };
            }

            $sql .= qq{
                WHERE s.uniquename IN ($placeholders)
            };

            push @bind, @accessions;

            my $sth = $dbh->prepare($sql);
            $sth->execute(@bind);

            while (my $row = $sth->fetchrow_hashref) {
                $pedigree_by_acc{$row->{accession}} = {
                    female_parent => $row->{female_parent} || '',
                    male_parent   => $row->{male_parent}   || '',
                };
            }
        }
    }

    # 4) stockprop cvterms for common accession-level fields
    my $notes_cvterm = SGN::Model::Cvterm->get_cvterm_row(
        $schema,
        $notes_prop_name,
        'stock_property'
    );

    my $year_cvterm = SGN::Model::Cvterm->get_cvterm_row(
        $schema,
        $year_prop_name,
        'stock_property'
    );

    my @rows;

    # 5) build one row per accession x breeding program
    foreach my $acc (@accessions) {

        my $stock_row = $schema->resultset('Stock::Stock')->search(
            { uniquename => $acc },
            { rows => 1 }
        )->first;

        my $female_parent = exists $pedigree_by_acc{$acc} ? ($pedigree_by_acc{$acc}{female_parent} || '') : '';
        my $male_parent   = exists $pedigree_by_acc{$acc} ? ($pedigree_by_acc{$acc}{male_parent}   || '') : '';

        my $notes_value = '';
        my $year_value  = '';

        if ($stock_row) {
            if ($notes_cvterm) {
                my $notes_prop = $stock_row->search_related(
                    'stockprops',
                    { type_id => $notes_cvterm->cvterm_id },
                    { order_by => { -desc => 'stockprop_id' }, rows => 1 }
                )->first;

                $notes_value = defined($notes_prop) ? ($notes_prop->value // '') : '';
            }

            if ($year_cvterm) {
                my $year_prop = $stock_row->search_related(
                    'stockprops',
                    { type_id => $year_cvterm->cvterm_id },
                    { order_by => { -desc => 'stockprop_id' }, rows => 1 }
                )->first;

                $year_value = defined($year_prop) ? ($year_prop->value // '') : '';
            }
        }

        foreach my $bp (@program_names) {
            my $stage_prop_name = $bp . '_Stage';
            my $stage_value     = '';

            if ($stock_row) {
                my $stage_cvterm = SGN::Model::Cvterm->get_cvterm_row(
                    $schema,
                    $stage_prop_name,
                    'stock_property'
                );

                if ($stage_cvterm) {
                    my $prop = $stock_row->search_related(
                        'stockprops',
                        { type_id => $stage_cvterm->cvterm_id },
                        { order_by => { -desc => 'stockprop_id' }, rows => 1 }
                    )->first;

                    $stage_value = defined($prop) ? ($prop->value // '') : '';
                }
            }

            my $decision_value = '';
            my $new_stage = $self->_compute_new_stage(
                current_stage_value => $stage_value,
                decision_value      => $decision_value,
                year_value          => $year_value,
                decision_format     => $decision_format,
                breeding_stages     => $breeding_stages,
            );

            push @rows, {
              stock_id         => $stock_row->stock_id,
              accession        => $acc,
              breeding_program => $bp,
              stage            => $stage_value,
              year             => $year_value,
              decision         => $decision_value,
              new_stage        => $new_stage,
              female_parent    => $female_parent,
              male_parent      => $male_parent,
              notes            => $notes_value,
          };
        }
    }

    return $self->status_ok($c, entity => { rows => \@rows });
}

sub stages_GET : Path('/ajax/decisionmeeting/stages') Args(0) {
    my ($self, $c) = @_;

    print STDERR "### stages_GET called ###\n";

    unless ($c->user) {
        $c->res->status(403);
        $c->res->content_type('application/json');
        $c->res->body(encode_json({ error => 'Login required' }));
        $c->detach();
    }

    my $conf_stages = $c->config->{breeding_stages};

    print STDERR "### breeding_stages exists? "
        . (exists $c->config->{breeding_stages} ? 'YES' : 'NO') . "\n";

    print STDERR "### breeding_stages ref type: ["
        . (ref($conf_stages) || 'SCALAR') . "]\n";

    my $raw = '';

    if (ref($conf_stages) eq 'ARRAY') {
        print STDERR "### breeding_stages array items ###\n";
        for my $i (0 .. $#$conf_stages) {
            print STDERR "###   [$i] = [" . (defined $conf_stages->[$i] ? $conf_stages->[$i] : 'UNDEF') . "]\n";
        }

        $raw = defined $conf_stages->[0] ? $conf_stages->[0] : '';
        print STDERR "### using only array[0]: [$raw]\n";
    }
    elsif (defined $conf_stages) {
        $raw = $conf_stages;
        print STDERR "### using scalar value: [$raw]\n";
    }
    else {
        print STDERR "### breeding_stages is UNDEF ###\n";
    }

    $raw =~ s/^\s+|\s+$//g;

    my @stages = grep { defined($_) && $_ ne '' }
                 map  {
                     my $x = $_;
                     $x =~ s/^\s+|\s+$//g;
                     print STDERR "### parsed stage token: [$x]\n";
                     $x;
                 }
                 split(/\s*,\s*/, $raw);

    print STDERR "### final stages parsed: [" . join(', ', @stages) . "]\n";

    $c->res->status(200);
    $c->res->content_type('application/json');
    $c->res->body(encode_json({ stages => \@stages }));
    $c->detach();
}

sub compute_new_stage : Path('compute_new_stage') : Args(0) : ActionClass('REST') { }
sub compute_new_stage_GET {
    my ($self, $c) = @_;

    return $self->status_forbidden($c, message => 'Login required')
        unless $c->user;

    my $current_stage  = $c->req->param('current_stage');
    my $decision       = lc($c->req->param('decision') // '');
    my $year           = $c->req->param('year');
    my $stock_id       = $c->req->param('stock_id');
    my $selected_stage = $c->req->param('selected_stage') || '';

    my $decision_format = $c->config->{decision_format} || 'state,year yy,stage';
    my $breeding_stages = $c->config->{breeding_stages} || 'T1,T2,Y1,Y2,Y3,Y4,Y5';

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    print STDERR "### compute_new_stage_GET called ###\n";
    print STDERR "### current_stage   = [" . ($current_stage // '') . "]\n";
    print STDERR "### decision        = [" . ($decision // '') . "]\n";
    print STDERR "### year            = [" . ($year // '') . "]\n";
    print STDERR "### stock_id        = [" . ($stock_id // '') . "]\n";
    print STDERR "### selected_stage  = [" . ($selected_stage // '') . "]\n";
    print STDERR "### decision_format = [" . ($decision_format // '') . "]\n";

    my $current_stage_token = $self->_extract_stage_token($current_stage);
    print STDERR "### extracted current_stage_token = [" . ($current_stage_token // '') . "]\n";

    my $stage_only = '';
    my $state = $self->_get_stockprop_value(
        schema    => $schema,
        stock_id  => $stock_id,
        prop_name => 'state',
    );

    print STDERR "### state from stockprop = [" . ($state // '') . "]\n";

    my $state_for_format = $state;

    if ($decision eq 'advance' || $decision eq 'jump') {
        $stage_only = $selected_stage || '';
        print STDERR "### using selected_stage from dialog = [" . ($stage_only // '') . "]\n";
    }
    elsif ($decision eq 'hold') {
        # HOLD must keep the current stage
        $stage_only = $current_stage_token || '';
        print STDERR "### HOLD: keeping current stage = [" . ($stage_only // '') . "]\n";
    }
    elsif ($decision eq 'drop') {
        # DROP must keep the current stage token, but show DROP instead of the state
        $stage_only = $current_stage_token || '';
        $state_for_format = 'DROP';
        print STDERR "### DROP: keeping current stage = [" . ($stage_only // '') . "]\n";
        print STDERR "### DROP: overriding state_for_format = [" . ($state_for_format // '') . "]\n";
    }
    else {
        print STDERR "### decision not recognized, returning empty new_stage ###\n";
        return $self->status_ok($c, entity => {
            new_stage      => '',
            selected_stage => '',
            state          => '',
            stock_id       => $stock_id,
        });
    }

    my $new_stage = $self->_format_decision_stage(
        decision_format => $decision_format,
        year            => $year,
        stage           => $stage_only,
        state           => $state_for_format,
    );

    print STDERR "### final new_stage = [" . ($new_stage // '') . "]\n";

    return $self->status_ok($c, entity => {
        new_stage       => $new_stage,
        selected_stage  => $stage_only,
        state           => $state_for_format,
        stock_id        => $stock_id,
        decision_format => $decision_format,
    });
}

sub compute_new_stage_POST {
    my ($self, $c) = @_;
    return $self->compute_new_stage_GET($c);
}

sub _format_decision_stage {
    my ($self, %args) = @_;

    my $decision_format = $args{decision_format} // '';
    my $year            = $args{year} // '';
    my $stage           = $args{stage} // '';
    my $state           = $args{state} // '';

    # remove example/comment after #
    my ($format_only) = split /\#/, $decision_format, 2;
    $format_only //= '';
    $format_only =~ s/^\s+|\s+$//g;

    print STDERR "### _format_decision_stage format_only = [$format_only]\n";

    my @parts;
    my @tokens = grep { $_ ne '' } map {
        my $x = $_;
        $x =~ s/^\s+|\s+$//g;
        $x;
    } split /,/, $format_only;

    for my $token (@tokens) {
        my ($field, $modifier) = split /\s+/, $token, 2;
        $field    //= '';
        $modifier //= '';

        print STDERR "### token field=[$field] modifier=[$modifier]\n";

        if ($field eq 'state') {
            push @parts, $state if defined $state && $state ne '';
        }
        elsif ($field eq 'year') {
            my $y = $year // '';
            if ($modifier eq 'yy') {
                $y = substr($y, -2);
            }
            elsif ($modifier eq 'YYYY' || $modifier eq 'yyyy' || $modifier eq '') {
                # keep full year
            }
            push @parts, $y if $y ne '';
        }
        elsif ($field eq 'stage') {
            push @parts, $stage if defined $stage && $stage ne '';
        }
        else {
            # unknown token: ignore, but print for debugging
            print STDERR "### WARNING unknown decision_format token [$field]\n";
        }
    }

    my $final = join('-', @parts);

    print STDERR "### _format_decision_stage final = [$final]\n";

    return $final;
}

sub _get_stockprop_value {
    my ($self, %args) = @_;

    my $schema    = $args{schema};
    my $stock_id  = $args{stock_id};
    my $prop_name = $args{prop_name};

    return '' unless $schema && $stock_id && $prop_name;

    my $cvterm_row = SGN::Model::Cvterm->get_cvterm_row($schema, $prop_name, 'stock_property');
    unless ($cvterm_row) {
        print STDERR "### WARNING cvterm not found for stockprop [$prop_name] in cv [stock_property]\n";
        return '';
    }

    my $type_id = $cvterm_row->cvterm_id;

    my $stockprop = $schema->resultset('Stock::Stockprop')->search(
        {
            stock_id => $stock_id,
            type_id  => $type_id,
        },
        {
            order_by => { -desc => 'stockprop_id' },
            rows     => 1,
        }
    )->single;

    my $value = $stockprop ? $stockprop->value : '';

    return $value // '';
}

sub datasets : Path('datasets') : Args(0) : ActionClass('REST') {}
sub datasets_GET {
    my ($self, $c) = @_;

    print STDERR "### datasets_GET triggered ###\n";

    return $self->status_forbidden($c, message => 'Login required')
        unless $c->user;

    my $dbh = $c->dbc->dbh;
    my @datasets;

    eval {
        my $sql = q{
            SELECT sp_dataset_id, name
            FROM sgn_people.sp_dataset
            ORDER BY name
        };

        my $sth = $dbh->prepare($sql);
        $sth->execute();

        while (my ($dataset_id, $name) = $sth->fetchrow_array) {
            push @datasets, {
                dataset_id => int($dataset_id),
                name       => ($name || "Dataset $dataset_id"),
            };

            print STDERR "### dataset_id=$dataset_id name=[" . ($name || '') . "]\n";
        }
    };

    if ($@) {
        print STDERR "### datasets_GET ERROR: $@\n";
        return $self->status_ok($c, entity => {
            error    => "Failed to load datasets",
            details  => "$@",
            datasets => []
        });
    }

    print STDERR "### total datasets returned: " . scalar(@datasets) . "\n";

    return $self->status_ok($c, entity => {
        datasets => \@datasets
    });
}

sub dataset_summary : Path('dataset_summary') : Args(0) : ActionClass('REST') { }
sub dataset_summary_GET {
    my ($self, $c) = @_;

    return $self->status_forbidden($c, message => 'Login required')
        unless $c->user;

    my $dataset_id = $c->req->param('dataset_id');
    return $self->status_bad_request($c, message => 'Missing dataset_id')
        unless $dataset_id;

    $c->tempfiles_subdir("decisionmeeting");
    my ($fh, $tempfile) = $c->tempfile(TEMPLATE => "decisionmeeting/dm_XXXXX");

    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    my $schema        = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
    my $temppath      = $c->config->{basepath} . "/" . $tempfile;

    my $ds_json = CXGN::Dataset->new(
        people_schema => $people_schema,
        schema        => $schema,
        sp_dataset_id => $dataset_id
    );

    $ds_json->retrieve_traits();
    my $ds_traits = $ds_json->traits();

    if (!$ds_traits || ref($ds_traits) ne 'ARRAY' || !@$ds_traits) {
        return $self->status_ok($c, entity => {
            summary => [],
            error   => "No traits found in the dataset. Please select a dataset with trial(s) and trait(s)."
        });
    }

    my $ds = CXGN::Dataset::File->new(
        people_schema            => $people_schema,
        schema                   => $schema,
        sp_dataset_id            => $dataset_id,
        exclude_dataset_outliers => 1,
        file_name                => $temppath,
        quotes                   => 0
    );

    $ds->retrieve_phenotypes();

    my $phenofile = $temppath . "_phenotype.txt";

    unless (-e $phenofile) {
        return $self->status_ok($c, entity => {
            summary => [],
            error   => "Phenotype file was not generated."
        });
    }

    open(my $in, '<', $phenofile) or die "Cannot open phenotype file '$phenofile': $!";

    my $header = <$in>;
    unless (defined $header) {
        close($in);
        return $self->status_ok($c, entity => {
            summary => [],
            error   => "Phenotype file is empty."
        });
    }

    chomp($header);
    $header =~ s/\r$//;
    my @cols = split(/\t/, $header, -1);

    print STDERR "### phenotype header columns ###\n";
    print STDERR join(" | ", @cols) . "\n";

    my $germplasm_idx = -1;
    for my $i (0 .. $#cols) {
        if (defined $cols[$i] && $cols[$i] eq 'germplasmName') {
            $germplasm_idx = $i;
            last;
        }
    }

    if ($germplasm_idx < 0) {
        close($in);
        return $self->status_ok($c, entity => {
            summary => [],
            error   => "germplasmName column not found in phenotype file."
        });
    }

    my @trait_cols;
    for my $i (0 .. $#cols) {
        my $col = $cols[$i];
        next unless defined $col;

        $col =~ s/^\s+|\s+$//g;

        # Keep only real trait columns like:
        # dry yield|CO_334:0000014
        # fresh root yield|CO_334:0000013
        next unless $col =~ /:/;

        push @trait_cols, [$i, $col];
    }

    print STDERR "### trait columns selected for summary ###\n";
    print STDERR join(" | ", map { $_->[1] } @trait_cols) . "\n";

    my %grouped_values;

    while (my $line = <$in>) {
        chomp($line);
        $line =~ s/\r$//;
        next if $line =~ /^\s*$/;

        my @fields = split(/\t/, $line, -1);

        next unless defined $fields[$germplasm_idx];
        my $germplasm = $fields[$germplasm_idx];
        $germplasm =~ s/^\s+|\s+$//g;
        next if $germplasm eq '';

        foreach my $tc (@trait_cols) {
            my ($idx, $trait) = @$tc;
            next unless defined $fields[$idx];

            my $v = $fields[$idx];
            $v =~ s/^\s+|\s+$//g;

            next if $v eq '';
            next unless $v =~ /^-?(?:\d+(?:\.\d+)?|\.\d+)$/;

            push @{ $grouped_values{$germplasm}{$trait} }, $v + 0;
        }
    }
    close($in);

    my @rows;
    foreach my $germplasm (sort keys %grouped_values) {
        foreach my $trait (sort keys %{ $grouped_values{$germplasm} }) {
            my @vals = @{ $grouped_values{$germplasm}{$trait} || [] };
            next unless @vals;

            my $n = scalar(@vals);

            my $sum = 0;
            $sum += $_ for @vals;
            my $avg = $sum / $n;

            my ($min, $max) = ($vals[0], $vals[0]);
            for my $v (@vals) {
                $min = $v if $v < $min;
                $max = $v if $v > $max;
            }

            my $sq = 0;
            $sq += ($_ - $avg) ** 2 for @vals;
            my $std = $n > 1 ? sqrt($sq / ($n - 1)) : 0;

            push @rows, {
                accession => $germplasm,
                trait     => $trait,
                min       => sprintf("%.3f", $min),
                max       => sprintf("%.3f", $max),
                average   => sprintf("%.3f", $avg),
                std       => sprintf("%.3f", $std),
            };
        }
    }

    return $self->status_ok($c, entity => {
        summary  => \@rows,
        tempfile => $tempfile . "_phenotype.txt",
    });
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

sub _dm_trim {
    my ($self, $v) = @_;
    $v = '' unless defined $v;
    $v =~ s/^\s+//;
    $v =~ s/\s+$//;
    return $v;
}

sub _dm_is_numeric {
    my ($self, $v) = @_;
    return 0 unless defined $v;
    $v = $self->_dm_trim($v);
    return 0 if $v eq '';
    return $v =~ /^-?(?:\d+(?:\.\d+)?|\.\d+)$/ ? 1 : 0;
}

sub _dm_build_dataset_phenofile {
    my ($self, $c, $dataset_id) = @_;

    $c->tempfiles_subdir("decisionmeeting");
    my ($fh, $tempfile) = $c->tempfile(TEMPLATE => "decisionmeeting/dm_XXXXX");

    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    my $schema        = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
    my $temppath      = $c->config->{basepath} . "/" . $tempfile;

    my $ds_json = CXGN::Dataset->new(
        people_schema => $people_schema,
        schema        => $schema,
        sp_dataset_id => $dataset_id
    );

    $ds_json->retrieve_traits();
    my $ds_traits = $ds_json->traits();

    if (!$ds_traits || ref($ds_traits) ne 'ARRAY' || !@$ds_traits) {
        return {
            error   => "No traits found in the dataset. Please select a dataset with trial(s) and trait(s).",
            summary => [],
        };
    }

    my $ds = CXGN::Dataset::File->new(
        people_schema            => $people_schema,
        schema                   => $schema,
        sp_dataset_id            => $dataset_id,
        exclude_dataset_outliers => 1,
        file_name                => $temppath,
        quotes                   => 0
    );

    $ds->retrieve_phenotypes();

    my $phenofile = $temppath . "_phenotype.txt";

    unless (-e $phenofile) {
        return {
            error   => "Phenotype file was not generated.",
            summary => [],
        };
    }

    return {
        phenofile => $phenofile,
        tempfile  => $tempfile . "_phenotype.txt",
        ds_traits => $ds_traits,
    };
}

sub dataset_traits : Path('dataset_traits') : Args(0) : ActionClass('REST') { }
sub dataset_traits_GET {
    my ($self, $c) = @_;

    return $self->status_forbidden($c, message => 'Login required')
        unless $c->user;

    my $dataset_id = $c->req->param('dataset_id');
    return $self->status_bad_request($c, message => 'Missing dataset_id')
        unless $dataset_id;

    my $res = $self->_dm_build_dataset_phenofile($c, $dataset_id);
    if ($res->{error}) {
        return $self->status_ok($c, entity => {
            traits     => [],
            accessions => [],
            error      => $res->{error},
        });
    }

    my $phenofile = $res->{phenofile};

    open(my $in, '<', $phenofile) or die "Cannot open phenotype file '$phenofile': $!";

    my $header = <$in>;
    unless (defined $header) {
        close($in);
        return $self->status_ok($c, entity => {
            traits     => [],
            accessions => [],
            error      => "Phenotype file is empty.",
        });
    }

    chomp($header);
    $header =~ s/\r$//;
    my @cols = split(/\t/, $header, -1);

    my $germplasm_idx = -1;
    for my $i (0 .. $#cols) {
        my $col = $self->_dm_trim($cols[$i]);
        if ($col eq 'germplasmName') {
            $germplasm_idx = $i;
            last;
        }
    }

    if ($germplasm_idx < 0) {
        close($in);
        return $self->status_ok($c, entity => {
            traits     => [],
            accessions => [],
            error      => "germplasmName column not found in phenotype file.",
        });
    }

    my @traits;
    for my $i (0 .. $#cols) {
        my $col = $self->_dm_trim($cols[$i]);
        next if $col eq '';
        next unless $col =~ /:/;
        push @traits, $col;
    }

    my %seen_acc;
    my @accessions;

    while (my $line = <$in>) {
        chomp($line);
        $line =~ s/\r$//;
        next if $line =~ /^\s*$/;

        my @fields = split(/\t/, $line, -1);
        next unless defined $fields[$germplasm_idx];

        my $acc = $self->_dm_trim($fields[$germplasm_idx]);
        next if $acc eq '';
        next if $seen_acc{$acc}++;

        push @accessions, $acc;
    }
    close($in);

    @traits     = sort @traits;
    @accessions = sort @accessions;

    return $self->status_ok($c, entity => {
        traits     => \@traits,
        accessions => \@accessions,
        tempfile   => $res->{tempfile},
    });
}

sub dataset_plot_data : Path('dataset_plot_data') : Args(0) : ActionClass('REST') { }
sub dataset_plot_data_GET {
    my ($self, $c) = @_;

    return $self->status_forbidden($c, message => 'Login required')
        unless $c->user;

    my $dataset_id = $c->req->param('dataset_id');
    my $trait      = $c->req->param('trait');

    return $self->status_bad_request($c, message => 'Missing dataset_id')
        unless $dataset_id;

    return $self->status_bad_request($c, message => 'Missing trait')
        unless defined $trait && $trait ne '';

    $trait = $self->_dm_trim($trait);

    my $res = $self->_dm_build_dataset_phenofile($c, $dataset_id);
    if ($res->{error}) {
        return $self->status_ok($c, entity => {
            trait             => $trait,
            rows              => [],
            accession_summary => [],
            error             => $res->{error},
        });
    }

    my $phenofile = $res->{phenofile};

    open(my $in, '<', $phenofile) or die "Cannot open phenotype file '$phenofile': $!";

    my $header = <$in>;
    unless (defined $header) {
        close($in);
        return $self->status_ok($c, entity => {
            trait             => $trait,
            rows              => [],
            accession_summary => [],
            error             => "Phenotype file is empty.",
        });
    }

    chomp($header);
    $header =~ s/\r$//;
    my @cols = split(/\t/, $header, -1);

    my $germplasm_idx = -1;
    my $trait_idx     = -1;

    for my $i (0 .. $#cols) {
        my $col = $self->_dm_trim($cols[$i]);

        if ($col eq 'germplasmName') {
            $germplasm_idx = $i;
        }
        if ($col eq $trait) {
            $trait_idx = $i;
        }
    }

    if ($germplasm_idx < 0) {
        close($in);
        return $self->status_ok($c, entity => {
            trait             => $trait,
            rows              => [],
            accession_summary => [],
            error             => "germplasmName column not found in phenotype file.",
        });
    }

    if ($trait_idx < 0) {
        close($in);
        return $self->status_ok($c, entity => {
            trait             => $trait,
            rows              => [],
            accession_summary => [],
            error             => "Trait column not found in phenotype file.",
        });
    }

    my @rows;
    my %grouped;

    while (my $line = <$in>) {
        chomp($line);
        $line =~ s/\r$//;
        next if $line =~ /^\s*$/;

        my @fields = split(/\t/, $line, -1);

        next unless defined $fields[$germplasm_idx];
        next unless defined $fields[$trait_idx];

        my $acc = $self->_dm_trim($fields[$germplasm_idx]);
        my $val = $self->_dm_trim($fields[$trait_idx]);

        next if $acc eq '';
        next unless $self->_dm_is_numeric($val);

        my $num = $val + 0;

        push @rows, {
            accession => $acc,
            value     => $num,
        };

        push @{ $grouped{$acc} }, $num;
    }
    close($in);

    my @summary;
    foreach my $acc (sort keys %grouped) {
        my @vals = @{ $grouped{$acc} || [] };
        next unless @vals;

        my $n = scalar(@vals);

        my $sum = 0;
        $sum += $_ for @vals;
        my $mean = $sum / $n;

        my ($min, $max) = ($vals[0], $vals[0]);
        for my $v (@vals) {
            $min = $v if $v < $min;
            $max = $v if $v > $max;
        }

        my $sq = 0;
        $sq += ($_ - $mean) ** 2 for @vals;
        my $std = $n > 1 ? sqrt($sq / ($n - 1)) : 0;

        push @summary, {
            accession => $acc,
            n         => $n,
            mean      => sprintf("%.6f", $mean),
            std       => sprintf("%.6f", $std),
            min       => sprintf("%.6f", $min),
            max       => sprintf("%.6f", $max),
        };
    }

    return $self->status_ok($c, entity => {
        trait             => $trait,
        rows              => \@rows,
        accession_summary => \@summary,
        tempfile          => $res->{tempfile},
    });
}

sub save_all_decisions : Path('save_all_decisions') : Args(0) : ActionClass('REST') { }
sub save_all_decisions_POST {
    my ($self, $c) = @_;

    return $self->status_forbidden($c, message => 'Login required')
        unless $c->user;

    my $payload = $c->req->data;

    unless ($payload && ref($payload) eq 'HASH') {
        return $self->status_bad_request($c, message => 'Missing or invalid JSON payload');
    }

    my $meeting_id = $payload->{meeting_id};
    unless ($meeting_id) {
        return $self->status_bad_request($c, message => 'Missing meeting_id in payload');
    }

    my $json_text;
    eval {
        require JSON;
        $json_text = JSON->new->allow_nonref->canonical->encode($payload);
    };
    if ($@) {
        return $self->status_bad_request($c, message => 'Could not encode payload to JSON');
    }

    my $dbh = $c->dbc->dbh;

    eval {
        my $sth = $dbh->prepare(q{
            UPDATE projectprop
            SET value = ?
            WHERE project_id = ?
              AND type_id = (
                  SELECT cvterm_id
                  FROM cvterm
                  WHERE name = 'meeting_json'
              )
        });
        $sth->execute($json_text, $meeting_id);
    };
    if ($@) {
        return $self->status_bad_request($c, message => "Failed to save decisions: $@");
    }

    $c->stash(
        current_view => 'JSON',
        json_data    => {
            success    => JSON::true,
            meeting_id => $meeting_id,
            message    => 'Decisions saved successfully'
        }
    );
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

  my $design_cv   = 'experiment_meeting';
  my $design_term = 'meeting_project';

  print STDERR "Looking for cvterm: cv='$design_cv', term='$design_term'\n";

  my $design_cvterm_row = SGN::Model::Cvterm->get_cvterm_row($schema, $design_term, $design_cv);

  die "Cvterm not found: term='$design_term' cv='$design_cv'\n"
      unless $design_cvterm_row;

  my $design_cvterm_id = $design_cvterm_row->cvterm_id;
  print STDERR "Found cvterm_id=$design_cvterm_id\n";

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

sub _trim {
  my ($self, $v) = @_;
  return '' unless defined $v;
  $v =~ s/^\s+//;
  $v =~ s/\s+$//;
  return $v;
}

sub _config_list {
  my ($self, $raw) = @_;
  return () unless defined $raw && $raw ne '';
  return grep { $_ ne '' } map { $self->_trim($_) } split /,/, $raw;
}

sub _extract_stage_token {
  my ($self, $stage_value) = @_;
  return '' unless defined $stage_value && $stage_value ne '';
  my @parts = grep { defined $_ && $_ ne '' } split /-/, $stage_value;
  return '' unless @parts;
  return $parts[-1];
}

sub _extract_yy {
  my ($self, $year_value) = @_;
  return '' unless defined $year_value && $year_value ne '';

  my $v = $self->_trim($year_value);

  if ($v =~ /^\d{2}$/) {
    return $v;
  }
  if ($v =~ /^\d{4}$/) {
    return substr($v, -2);
  }
  if ($v =~ /(19\d{2}|20\d{2})/) {
    return substr($1, -2);
  }
  if ($v =~ /(?:^|\D)(\d{2})(?:\D|$)/) {
    return $1;
  }

  return '';
}

sub _compute_new_stage {
    my ($self, %args) = @_;

    my $current_stage_value = $args{current_stage_value} // '';
    my $decision_value      = lc($args{decision_value} // '');
    my $breeding_stages     = $args{breeding_stages};

    print STDERR "### _compute_new_stage called ###\n";
    print STDERR "### current_stage_value = [$current_stage_value]\n";
    print STDERR "### decision_value      = [$decision_value]\n";

    return '' unless $decision_value;

    my $current_token = $self->_extract_stage_token($current_stage_value);
    print STDERR "### current_token = [" . ($current_token // '') . "]\n";
    return '' unless $current_token;

    my @ordered_stages = $self->_config_list($breeding_stages);
    print STDERR "### ordered_stages = [" . join(', ', @ordered_stages) . "]\n";
    return '' unless @ordered_stages;

    my %pos;
    @pos{@ordered_stages} = (0 .. $#ordered_stages);

    my $next_token = $current_token;

    if ($decision_value eq 'drop') {
        $next_token = $current_token;
    }
    elsif ($decision_value eq 'hold') {
        $next_token = $current_token;
    }
    elsif ($decision_value eq 'advance') {
        if (exists $pos{$current_token} && $pos{$current_token} < $#ordered_stages) {
            $next_token = $ordered_stages[ $pos{$current_token} + 1 ];
        }
    }
    elsif ($decision_value eq 'jump') {
        if (exists $pos{$current_token}) {
            my $jump_to = $pos{$current_token} + 2;
            $jump_to = $#ordered_stages if $jump_to > $#ordered_stages;
            $next_token = $ordered_stages[$jump_to];
        }
    }
    else {
        return '';
    }

    print STDERR "### _compute_new_stage returning token only = [$next_token]\n";
    return $next_token;
}

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
