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
use File::Path qw(make_path);
use Scalar::Util qw(looks_like_number);
use Excel::Writer::XLSX;
use Spreadsheet::ParseExcel;
use Spreadsheet::ParseXLSX;
use Spreadsheet::WriteExcel;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    namespace => 'ajax/decisionmeeting',
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
);

sub ping : Path('ping') : Args(0) : ActionClass('REST') {}
sub ping_GET {
    my ($self, $c) = @_;
    $self->status_ok($c, entity => { ok => 1, user => ($c->user ? 1 : 0) });
}

sub lists : Path('lists') : Args(0) : ActionClass('REST') {}
sub lists_GET {
    my ($self, $c) = @_;

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
        return $self->status_ok($c, entity => {
            lists     => [],
            type_name => $type_name,
            type_id   => undef
        });
    }

    my $people = $c->dbic_schema('CXGN::People::Schema');

    my $rs = $people->resultset('List')->search(
        { owner => $owner_id, type_id => $cvterm_id },
        { order_by => 'name' }
    );

    my @lists = map {
        +{
            list_id   => int($_->list_id),
            name      => $_->name,
            type_id   => $cvterm_id,
            type_name => $type_name,
        }
    } $rs->all;

    $self->status_ok($c, entity => {
        lists     => \@lists,
        type_name => $type_name,
        type_id   => $cvterm_id
    });
}

sub programs : Path('programs') : ActionClass('REST') { }
sub programs_GET {
    my ($self, $c) = @_;

    return $self->status_forbidden($c, message => 'Login required')
        unless $c->user;

    my $schema   = $c->dbic_schema('Bio::Chado::Schema');
    my $ps       = CXGN::BreedersToolbox::Projects->new({ schema => $schema });
    my $programs = $ps->get_breeding_programs();

    my @items;
    foreach my $p (@{ $programs || [] }) {
        if (ref $p eq 'ARRAY') {
            my ($id, $name) = ($p->[0], $p->[1]);
            push @items, { program_id => $id, name => $name }
                if defined $id && defined $name;
        }
        elsif (ref $p eq 'HASH') {
            push @items, {
                program_id => $p->{program_id} // $p->{project_id} // $p->{id},
                name       => $p->{name} // $p->{project_name},
            };
        }
    }

    return $self->status_ok($c, entity => \@items);
}

sub locations : Path('locations') : ActionClass('REST') { }
sub locations_GET {
    my ($self, $c) = @_;

    return $self->status_forbidden($c, message => 'Login required')
        unless $c->user;

    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    my $ps     = CXGN::BreedersToolbox::Projects->new({ schema => $schema });
    my $locs   = $ps->get_locations() || [];

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

sub decisions : Path('decisions') : Args(0) : ActionClass('REST') { }
sub decisions_GET {
    my ($self, $c) = @_;

    return $self->status_forbidden($c, message => 'Login required')
        unless $c->user;

    my $list_id          = $c->req->param('list_id');
    my $meeting_id       = $c->req->param('meeting_id');
    my $selected_program = $c->req->param('breeding_program') // '';

    return $self->status_bad_request($c, message => 'Missing list_id')
        unless $list_id;

    my $entity = $self->_decision_rows_entity(
        $c,
        list_id          => $list_id,
        meeting_id       => $meeting_id,
        breeding_program => $selected_program,
    );

    return $self->status_ok($c, entity => $entity);
}

sub _decision_rows_entity {
    my ($self, $c, %args) = @_;

    my $list_id          = $args{list_id};
    my $meeting_id       = $args{meeting_id};
    my $selected_program = $args{breeding_program} // '';

    my $dbh    = $c->dbc->dbh;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    my $decision_format = $c->config->{decision_format} || 'state,yy,stage';
    my $breeding_stages = $c->config->{breeding_stages} || 'T1,T2,Y1,Y2,Y3,Y4,Y5';

    my $notes_prop_name = 'notes';
    my $year_prop_name  = 'acquisition date';

    my $list = CXGN::List->new({ dbh => $dbh, list_id => $list_id });
    my $els  = $list->elements || [];
    my @accessions = grep { defined $_ && $_ ne '' } @$els;

    return { rows => [] } unless @accessions;

    my $ps       = CXGN::BreedersToolbox::Projects->new({ schema => $schema });
    my $programs = $ps->get_breeding_programs() || [];

    my @program_names;
    my %seen_program;
    my %program_id_to_name;

    foreach my $p (@$programs) {
        my ($pid, $nm) = ('', '');

        if (ref($p) eq 'ARRAY') {
            $pid = $p->[0] // '';
            $nm  = $p->[1] // '';
        }
        elsif (ref($p) eq 'HASH') {
            $pid = $p->{program_id} // $p->{project_id} // $p->{id} // '';
            $nm  = $p->{name} // $p->{project_name} // '';
        }

        next unless defined $nm && $nm ne '';

        $program_id_to_name{$pid} = $nm if $pid ne '';

        next if $seen_program{$nm}++;
        push @program_names, $nm;
    }

    if (!$selected_program && $meeting_id) {
        my $sth = $dbh->prepare(q{
            SELECT pp.value
            FROM projectprop pp
            WHERE pp.project_id = ?
              AND pp.type_id = (
                  SELECT cvterm_id
                  FROM cvterm
                  WHERE name = 'meeting_json'
                  LIMIT 1
              )
            ORDER BY pp.projectprop_id DESC
            LIMIT 1
        });
        $sth->execute($meeting_id);

        my ($meeting_json) = $sth->fetchrow_array;
        if ($meeting_json) {
            my $decoded = {};
            eval { $decoded = decode_json($meeting_json); };
            $decoded ||= {};

            if ($decoded->{breeding_program_name}) {
                $selected_program = $decoded->{breeding_program_name};
            }
            elsif ($decoded->{breeding_program_choice}) {
                my $bp = $decoded->{breeding_program_choice};
                $selected_program = exists $program_id_to_name{$bp}
                    ? $program_id_to_name{$bp}
                    : $bp;
            }
            elsif ($decoded->{breeding_program}) {
                my $bp = $decoded->{breeding_program};
                $selected_program = exists $program_id_to_name{$bp}
                    ? $program_id_to_name{$bp}
                    : $bp;
            }
        }
    }

    if ($selected_program && exists $program_id_to_name{$selected_program}) {
        $selected_program = $program_id_to_name{$selected_program};
    }

    my @programs_to_use = $selected_program ? ($selected_program) : @program_names;

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
            }
            else {
                $sql .= qq{ LEFT JOIN stock mother ON 1=0 };
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
            }
            else {
                $sql .= qq{ LEFT JOIN stock father ON 1=0 };
            }

            $sql .= qq{ WHERE s.uniquename IN ($placeholders) };
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

    my $notes_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, $notes_prop_name, 'stock_property');
    my $year_cvterm  = SGN::Model::Cvterm->get_cvterm_row($schema, $year_prop_name,  'stock_property');

    my @rows;

    foreach my $acc (@accessions) {
        my $stock_row = $schema->resultset('Stock::Stock')->search(
            { uniquename => $acc },
            { rows => 1 }
        )->first;

        my $female_parent = exists $pedigree_by_acc{$acc}
            ? ($pedigree_by_acc{$acc}{female_parent} || '')
            : '';
        my $male_parent = exists $pedigree_by_acc{$acc}
            ? ($pedigree_by_acc{$acc}{male_parent} || '')
            : '';

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

        foreach my $bp (@programs_to_use) {
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
                stock_id         => $stock_row ? $stock_row->stock_id : undef,
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

    return { rows => \@rows };
}

sub _decision_upload_headers {
    return (
        'Accession',
        'Breeding Program',
        'Previous Stage',
        'Decision',
        'New Stage',
        'Notes',
        'Comment',
    );
}

sub _normalize_decision_upload_header {
    my ($self, $value) = @_;
    $value = defined $value ? "$value" : '';
    $value =~ s/^\s+|\s+$//g;
    $value = lc($value);
    $value =~ s/[^a-z0-9]+/ /g;
    $value =~ s/\s+/ /g;
    $value =~ s/^\s+|\s+$//g;
    return $value;
}

sub _parse_decision_upload_file {
    my ($self, %args) = @_;

    my $filename = $args{filename} || '';
    my $original_filename = $args{original_filename} || $filename;
    my @errors;

    my ($extension) = $original_filename =~ /(\.[^.]+)$/;
    $extension = lc($extension || '');

    my $parser;
    if ($extension eq '.xlsx') {
        $parser = Spreadsheet::ParseXLSX->new();
    }
    elsif ($extension eq '.xls') {
        $parser = Spreadsheet::ParseExcel->new();
    }
    else {
        return (undef, ['The uploaded file must be an Excel .xls or .xlsx file.']);
    }

    my $excel_obj = $parser->parse($filename);
    if (!$excel_obj) {
        my $err = eval { $parser->error() } || 'Could not parse the Excel file.';
        return (undef, [$err]);
    }

    my $worksheet = ($excel_obj->worksheets())[0];
    unless ($worksheet) {
        return (undef, ['Spreadsheet must be on the first worksheet.']);
    }

    my ($row_min, $row_max) = $worksheet->row_range();
    my ($col_min, $col_max) = $worksheet->col_range();
    if (!defined $row_max || $row_max < 1) {
        return (undef, ['Spreadsheet is missing data rows.']);
    }

    my @expected_headers = $self->_decision_upload_headers();
    my @normalized_expected = map { $self->_normalize_decision_upload_header($_) } @expected_headers;

    for my $idx (0 .. $#expected_headers) {
        my $cell = $worksheet->get_cell($row_min, $idx);
        my $header = $cell ? $cell->value() : '';
        my $normalized = $self->_normalize_decision_upload_header($header);
        if ($normalized ne $normalized_expected[$idx]) {
            my $col_letter = chr(65 + $idx);
            push @errors, "Cell ${col_letter}1 must contain '$expected_headers[$idx]'.";
        }
    }

    return (undef, \@errors) if @errors;

    my @rows;
    my %allowed_decisions = map { $_ => 1 } qw(drop hold advance jump);

    for my $row ($row_min + 1 .. $row_max) {
        my @values;
        for my $col (0 .. $#expected_headers) {
            my $cell = $worksheet->get_cell($row, $col);
            my $value = $cell ? $cell->value() : '';
            $value = '' unless defined $value;
            $value =~ s/^\s+|\s+$//g;
            push @values, $value;
        }

        next unless grep { defined $_ && $_ ne '' } @values;

        my $row_number = $row + 1;
        my ($accession, $breeding_program, $previous_stage, $decision, $new_stage, $notes, $comment) = @values;

        if ($accession eq '') {
            push @errors, "Cell A$row_number: accession is required.";
        }
        if ($breeding_program eq '') {
            push @errors, "Cell B$row_number: breeding program is required.";
        }

        my $decision_norm = lc($decision || '');
        if ($decision_norm ne '' && !$allowed_decisions{$decision_norm}) {
            push @errors, "Cell D$row_number: decision must be one of drop, hold, advance, or jump.";
        }

        push @rows, {
            accession        => $accession,
            breeding_program => $breeding_program,
            previous_stage   => $previous_stage,
            decision         => $decision_norm,
            new_stage        => $new_stage,
            notes            => $notes,
            save_comment     => $comment,
            row_number       => $row_number,
        };
    }

    if (!@rows) {
        push @errors, 'Spreadsheet contains no accession decision rows.';
    }

    return (undef, \@errors) if @errors;
    return (\@rows, []);
}

sub _decision_format_config {
    my ($self, $c) = @_;
    return $c->config->{decision_format} || 'state,year yy,stage';
}

sub _breeding_stages_config {
    my ($self, $c) = @_;
    my $raw_stages_conf = $c->config->{breeding_stages};
    my $breeding_stages = '';

    if (ref($raw_stages_conf) eq 'ARRAY') {
        $breeding_stages = defined($raw_stages_conf->[0]) ? $raw_stages_conf->[0] : '';
    }
    else {
        $breeding_stages = defined($raw_stages_conf) ? $raw_stages_conf : '';
    }

    return $breeding_stages;
}

sub _meeting_year_from_meeting_id {
    my ($self, $c, $meeting_id) = @_;
    return '' unless $meeting_id;

    my $dbh = $c->dbc->dbh;
    my $sth = $dbh->prepare(q{
        SELECT pp.value
        FROM projectprop pp
        WHERE pp.project_id = ?
          AND pp.type_id = (
              SELECT cvterm_id
              FROM cvterm
              WHERE name = 'meeting_json'
              LIMIT 1
          )
        ORDER BY pp.projectprop_id DESC
        LIMIT 1
    });
    $sth->execute($meeting_id);

    my ($meeting_json) = $sth->fetchrow_array;
    return '' unless $meeting_json;

    my $decoded = {};
    eval { $decoded = decode_json($meeting_json); };
    $decoded ||= {};

    my $date = $decoded->{date} || '';
    return $1 if $date =~ /^(\d{4})-/;

    return '';
}

sub _stage_name_suggestion {
    my ($self, $candidate, $choices) = @_;

    $candidate = defined $candidate ? "$candidate" : '';
    $candidate =~ s/^\s+|\s+$//g;
    return '' if $candidate eq '';

    my $cand_lc = lc($candidate);
    foreach my $choice (@{$choices || []}) {
        next unless defined $choice && $choice ne '';
        return $choice if lc($choice) eq $cand_lc;
    }
    foreach my $choice (@{$choices || []}) {
        next unless defined $choice && $choice ne '';
        return $choice if index(lc($choice), $cand_lc) >= 0 || index($cand_lc, lc($choice)) >= 0;
    }
    return $choices && @{$choices} ? $choices->[0] : '';
}

sub _is_drop_stage_value {
    my ($self, $value) = @_;
    $value = defined $value ? "$value" : '';
    $value =~ s/^\s+|\s+$//g;
    return 0 if $value eq '';
    return $value =~ /^DROP(?:-|$)/i ? 1 : 0;
}

sub _compute_stage_transition_data {
    my ($self, %args) = @_;

    my $current_stage    = $args{current_stage};
    my $decision         = lc($args{decision} // '');
    my $year             = $args{year};
    my $stock_id         = $args{stock_id};
    my $selected_stage   = $args{selected_stage} || '';
    my $decision_format  = $args{decision_format} || 'state,year yy,stage';
    my $breeding_stages  = $args{breeding_stages} || '';
    my $schema           = $args{schema};

    my @ordered_stages = grep { defined($_) && $_ ne '' }
                         map  { my $x = $_; $x =~ s/^\s+|\s+$//g; $x }
                         split(/\s*,\s*/, $breeding_stages);

    my %pos;
    @pos{@ordered_stages} = (0 .. $#ordered_stages);

    my $current_stage_token = '';

    if (defined $current_stage && $current_stage ne '') {
        my $tmp = $current_stage;
        $tmp =~ s/^\s+|\s+$//g;

        if (exists $pos{$tmp}) {
            $current_stage_token = $tmp;
        }
        elsif ($tmp =~ /-([^-]+)$/) {
            my $last = $1;
            $last =~ s/^\s+|\s+$//g;
            if (exists $pos{$last}) {
                $current_stage_token = $last;
            }
        }
    }

    my @allowed_stages;
    if ($current_stage_token ne '' && exists $pos{$current_stage_token}) {
        my $idx = $pos{$current_stage_token};

        if ($decision eq 'advance') {
            @allowed_stages = @ordered_stages[($idx + 1) .. $#ordered_stages]
                if $idx < $#ordered_stages;
        }
        elsif ($decision eq 'jump') {
            my $start = $idx + 2;
            @allowed_stages = @ordered_stages[$start .. $#ordered_stages]
                if $start <= $#ordered_stages;
        }
    }

    my $stage_only = '';
    my $state = $self->_get_stockprop_value(
        schema    => $schema,
        stock_id  => $stock_id,
        prop_name => 'state',
    );

    my $state_for_format = $state;

    if ($decision eq 'advance' || $decision eq 'jump') {
        my %allowed_lookup = map { $_ => 1 } @allowed_stages;

        if ($selected_stage && $allowed_lookup{$selected_stage}) {
            $stage_only = $selected_stage;
        }
        else {
            $stage_only = '';
        }
    }
    elsif ($decision eq 'hold') {
        $stage_only = $current_stage_token || '';
    }
    elsif ($decision eq 'drop') {
        $stage_only = $current_stage_token || '';
        $state_for_format = 'DROP';
    }
    else {
        return {
            new_stage           => '',
            selected_stage      => '',
            allowed_stages      => [],
            state               => '',
            stock_id            => $stock_id,
            decision_format     => $decision_format,
            current_stage_token => $current_stage_token,
            ordered_stages      => \@ordered_stages,
        };
    }

    my $new_stage = '';
    if ($decision eq 'jump') {
        if ($stage_only ne '' && $current_stage_token ne '') {
            my $jump_year = $year // '';
            $jump_year =~ s/^\s+|\s+$//g;

            if (($decision_format || '') =~ /\byear\s*yy\b/i) {
                $jump_year = substr($jump_year, -2) if $jump_year ne '';
            }

            my $jump_from = $current_stage_token;
            $jump_from =~ s/^\s+|\s+$//g;
            my @jump_parts = grep { defined $_ && $_ ne '' } split /-/, $jump_from;
            $jump_from = @jump_parts ? $jump_parts[-1] : '';

            $new_stage = join('-', grep { defined($_) && $_ ne '' }
                'JUMP',
                $jump_year,
                $jump_from,
                $stage_only,
            );
        }
    }
    elsif ($decision eq 'advance') {
        if ($stage_only ne '') {
            $new_stage = $self->_format_decision_stage(
                decision_format => $decision_format,
                year            => $year,
                stage           => $stage_only,
                state           => $state_for_format,
            );
        }
    }
    else {
        $new_stage = $self->_format_decision_stage(
            decision_format => $decision_format,
            year            => $year,
            stage           => $stage_only,
            state           => $state_for_format,
        );
    }

    return {
        new_stage           => $new_stage,
        selected_stage      => $stage_only,
        allowed_stages      => \@allowed_stages,
        state               => $state_for_format,
        stock_id            => $stock_id,
        decision_format     => $decision_format,
        current_stage_token => $current_stage_token,
        ordered_stages      => \@ordered_stages,
    };
}

sub _validate_uploaded_decision_rows {
    my ($self, %args) = @_;

    my $c           = $args{c};
    my $schema      = $args{schema};
    my $meeting_year = $args{meeting_year} || '';
    my $current_rows = $args{current_rows} || [];
    my $parsed_rows  = $args{parsed_rows} || [];

    my $decision_format = $self->_decision_format_config($c);
    my $breeding_stages = $self->_breeding_stages_config($c);

    my %current_lookup;
    foreach my $row (@$current_rows) {
        my $key = join("\t", lc($row->{accession} || ''), lc($row->{breeding_program} || ''));
        $current_lookup{$key} = $row;
    }

    my @errors;
    my @unmatched_rows;

    foreach my $uploaded (@$parsed_rows) {
        my $key = join("\t", lc($uploaded->{accession} || ''), lc($uploaded->{breeding_program} || ''));
        my $target = $current_lookup{$key};
        unless ($target) {
            push @unmatched_rows, {
                accession        => $uploaded->{accession} || '',
                breeding_program => $uploaded->{breeding_program} || '',
                row_number       => $uploaded->{row_number},
            };
            next;
        }

        my $decision = $uploaded->{decision} || '';
        my $new_stage = $uploaded->{new_stage} || '';
        my $row_number = $uploaded->{row_number} || '?';
        my $current_stage_value = $target->{stage} || '';

        if ($self->_is_drop_stage_value($current_stage_value)) {
            if ($decision ne '') {
                push @errors, "Row $row_number: current stage '$current_stage_value' is already a DROP stage, so no further decision can be applied to this accession.";
                next;
            }
            next;
        }

        if ($decision eq '') {
            if ($new_stage ne '') {
                push @errors, "Row $row_number: new stage '$new_stage' was provided but decision is empty.";
            }
            next;
        }

        my $transition = $self->_compute_stage_transition_data(
            current_stage   => $target->{stage},
            decision        => $decision,
            year            => $meeting_year,
            stock_id        => $target->{stock_id},
            selected_stage  => '',
            decision_format => $decision_format,
            breeding_stages => $breeding_stages,
            schema          => $schema,
        );

        my @allowed = @{$transition->{allowed_stages} || []};
        my @all_stages = @{$transition->{ordered_stages} || []};
        my $uploaded_token = $self->_normalize_stage_token($new_stage, $breeding_stages);

        if (($decision eq 'advance' || $decision eq 'jump') && !@allowed) {
            push @errors, "Row $row_number: decision '$decision' is not compatible with current stage '" . ($target->{stage} || '') . "'.";
            next;
        }

        if ($decision eq 'advance' || $decision eq 'jump') {
            if ($new_stage eq '') {
                push @errors, "Row $row_number: decision '$decision' requires a new stage.";
                next;
            }

            if ($uploaded_token eq '') {
                my $suggest = $self->_stage_name_suggestion($new_stage, \@allowed) || $self->_stage_name_suggestion($new_stage, \@all_stages);
                my $msg = "Row $row_number: stage '$new_stage' is not stored.";
                $msg .= " Did you mean '$suggest'?" if $suggest ne '';
                push @errors, $msg;
                next;
            }

            my %allowed_lookup = map { $_ => 1 } @allowed;
            if (!$allowed_lookup{$uploaded_token}) {
                push @errors, "Row $row_number: this stage '$new_stage' is not compatible with the decision '$decision'. Allowed target stages: " . join(', ', @allowed) . ".";
                next;
            }

            my $expected = $self->_compute_stage_transition_data(
                current_stage   => $target->{stage},
                decision        => $decision,
                year            => $meeting_year,
                stock_id        => $target->{stock_id},
                selected_stage  => $uploaded_token,
                decision_format => $decision_format,
                breeding_stages => $breeding_stages,
                schema          => $schema,
            );

            if (($expected->{new_stage} || '') ne $new_stage && $new_stage ne $uploaded_token) {
                push @errors, "Row $row_number: this stage '$new_stage' is not compatible with the decision '$decision'. Did you mean '$expected->{new_stage}'?";
                next;
            }
        }
        else {
            my $expected = $self->_compute_stage_transition_data(
                current_stage   => $target->{stage},
                decision        => $decision,
                year            => $meeting_year,
                stock_id        => $target->{stock_id},
                selected_stage  => '',
                decision_format => $decision_format,
                breeding_stages => $breeding_stages,
                schema          => $schema,
            );
            my $expected_new_stage = $expected->{new_stage} || '';
            my $current_stage_for_hold = $target->{stage} || '';

            if ($new_stage eq '') {
                my $required_stage = $decision eq 'hold' ? ($current_stage_for_hold || $expected_new_stage) : $expected_new_stage;
                push @errors, "Row $row_number: decision '$decision' requires new stage '$required_stage'.";
                next;
            }

            if ($decision eq 'hold') {
                if ($new_stage ne $expected_new_stage && $new_stage ne $current_stage_for_hold) {
                    my $suggest = $current_stage_for_hold || $expected_new_stage;
                    push @errors, "Row $row_number: this stage '$new_stage' is not compatible with the decision '$decision'. Did you mean '$suggest'?";
                    next;
                }
            }
            elsif ($new_stage ne $expected_new_stage) {
                push @errors, "Row $row_number: this stage '$new_stage' is not compatible with the decision '$decision'. Did you mean '$expected_new_stage'?";
                next;
            }
        }
    }

    return (\@errors, \@unmatched_rows);
}

sub _normalize_stage_token {
    my ($self, $value, $breeding_stages) = @_;

    my $raw = defined $value ? "$value" : '';
    $raw =~ s/^\s+|\s+$//g;
    return '' if $raw eq '';

    my @ordered_stages = $self->_config_list($breeding_stages);
    my %valid = map { $_ => 1 } @ordered_stages;

    return $raw if $valid{$raw};

    my $token = $self->_extract_stage_token($raw);
    $token = defined $token ? "$token" : '';
    $token =~ s/^\s+|\s+$//g;
    return $token if $token ne '' && $valid{$token};

    if ($raw =~ /-([^-]+)$/) {
        my $last = $1;
        $last =~ s/^\s+|\s+$//g;
        return $last if $valid{$last};
    }

    foreach my $stg (sort { length($b) <=> length($a) } @ordered_stages) {
        if ($raw =~ /\Q$stg\E/) {
            return $stg;
        }
    }

    return '';
}

sub stages_GET : Path('/ajax/decisionmeeting/stages') Args(0) {
    my ($self, $c) = @_;

    unless ($c->user) {
        $c->res->status(403);
        $c->res->content_type('application/json');
        $c->res->body(encode_json({ error => 'Login required' }));
        $c->detach();
    }

    my $conf_stages = $c->config->{breeding_stages};
    my $raw = '';

    if (ref($conf_stages) eq 'ARRAY') {
        $raw = defined $conf_stages->[0] ? $conf_stages->[0] : '';
    }
    elsif (defined $conf_stages) {
        $raw = $conf_stages;
    }

    $raw =~ s/^\s+|\s+$//g;

    my @stages = grep { defined($_) && $_ ne '' }
                 map  {
                     my $x = $_;
                     $x =~ s/^\s+|\s+$//g;
                     $x;
                 }
                 split(/\s*,\s*/, $raw);

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

    my $decision_format = $self->_decision_format_config($c);
    my $breeding_stages = $self->_breeding_stages_config($c);

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $result = $self->_compute_stage_transition_data(
        current_stage   => $current_stage,
        decision        => $decision,
        year            => $year,
        stock_id        => $stock_id,
        selected_stage  => $selected_stage,
        decision_format => $decision_format,
        breeding_stages => $breeding_stages,
        schema          => $schema,
    );

    return $self->status_ok($c, entity => $result);
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

    my ($format_only) = split /\#/, $decision_format, 2;
    $format_only //= '';
    $format_only =~ s/^\s+|\s+$//g;

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

        if ($field eq 'state') {
            push @parts, $state if defined $state && $state ne '';
        }
        elsif ($field eq 'year') {
            my $y = $year // '';
            if ($modifier eq 'yy') {
                $y = substr($y, -2);
            }
            elsif ($modifier eq 'YYYY' || $modifier eq 'yyyy' || $modifier eq '') {
            }
            push @parts, $y if $y ne '';
        }
        elsif ($field eq 'stage') {
            push @parts, $stage if defined $stage && $stage ne '';
        }
    }

    my $final = join('-', @parts);
    return $final;
}

sub _get_stockprop_value {
    my ($self, %args) = @_;

    my $schema    = $args{schema};
    my $stock_id  = $args{stock_id};
    my $prop_name = $args{prop_name};

    return '' unless $schema && $stock_id && $prop_name;

    my $cvterm_row = SGN::Model::Cvterm->get_cvterm_row($schema, $prop_name, 'stock_property');
    return '' unless $cvterm_row;

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
        }
    };

    if ($@) {
        return $self->status_ok($c, entity => {
            error    => "Failed to load datasets",
            details  => "$@",
            datasets => []
        });
    }

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

    my $sp_person_id = $c->user ? $c->user->get_object->get_sp_person_id : undef;
    my $people_schema = $c->dbic_schema("CXGN::People::Schema", undef, $sp_person_id);
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
        next unless $col =~ /:/;

        push @trait_cols, [$i, $col];
    }

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

sub accessions : Path('accessions') : Args(0) : ActionClass('REST') {}
sub accessions_GET {
    my ($self, $c) = @_;

    return $self->status_forbidden($c, message => 'Login required')
        unless $c->user;

    my $dataset_id    = $c->req->param('dataset_id');
    my $list_id       = $c->req->param('list_id');

    my $sp_person_id = $c->user ? $c->user->get_object->get_sp_person_id : undef;
    my $people_schema = $c->dbic_schema("CXGN::People::Schema", undef, $sp_person_id);
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
        }
        elsif (my $ret = eval { $ds->retrieve_accessions() }) {
            @names = @{ $ret->{data} || [] } if ref($ret) eq 'HASH';
        }
        elsif ($ds->can('accession_list') && ref($ds->accession_list) eq 'ARRAY') {
            @names = @{$ds->accession_list};
        }
    }
    elsif ($list_id) {
        my $list = CXGN::List->new({ dbh => $dbh, list_id => $list_id });
        my $els  = $list->elements;
        @names   = @$els if $els && ref($els) eq 'ARRAY';
    }

    my @accs = map { +{ accession_id => undef, name => "$_" } }
               grep { defined && $_ ne '' } @names;

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

    my $sp_person_id = $c->user ? $c->user->get_object->get_sp_person_id : undef;
    my $people_schema = $c->dbic_schema("CXGN::People::Schema", undef, $sp_person_id);
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

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my @user_roles = $c->user()->roles;

    my $raw_decision_role = $c->config->{decision_role};
    my $decision_role_conf = '';

    if (ref($raw_decision_role) eq 'ARRAY') {
        $decision_role_conf = defined($raw_decision_role->[0]) ? $raw_decision_role->[0] : '';
    }
    else {
        $decision_role_conf = $raw_decision_role // '';
    }

    my @allowed_roles = grep { $_ ne '' }
        map {
            my $x = $_ // '';
            $x =~ s/^\s+|\s+$//g;
            $x;
        }
        split(/\s*,\s*/, $decision_role_conf);

    my %allowed = map { $_ => 1 } @allowed_roles;
    my $can_save = 0;

    foreach my $role (@user_roles) {
        if ($allowed{$role}) {
            $can_save = 1;
            last;
        }
    }

    unless ($can_save) {
        return $self->status_forbidden(
            $c,
            message => 'You are not allowed to save accessions stage change'
        );
    }

    $payload->{saved}        = JSON::true;
    $payload->{saved_at}     = scalar localtime();
    $payload->{saved_status} = 'successfully';

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

        my $raw_conf = $c->config->{saved_program_stage};
        my $saved_program_stage = '';

        if (ref($raw_conf) eq 'ARRAY') {
            $saved_program_stage = defined($raw_conf->[0]) ? $raw_conf->[0] : '';
        }
        else {
            $saved_program_stage = $raw_conf // '';
        }

        my $accessions = $payload->{accessions} || [];

        foreach my $acc (@$accessions) {
            next unless $acc && ref($acc) eq 'HASH';

            my $stock_id         = $acc->{stock_id};
            my $breeding_program = $acc->{breeding_program} // '';
            my $new_stage        = $acc->{new_stage} // '';

            next unless $stock_id;
            next unless $breeding_program ne '';
            next unless $new_stage ne '';

            my $stage_prop_name = '';

            foreach my $pair (split(/\s*,\s*/, $saved_program_stage)) {
                next unless $pair;

                my ($program_name, $prop_name) = split(/\s*\|\s*/, $pair, 2);

                $program_name = '' unless defined $program_name;
                $prop_name    = '' unless defined $prop_name;

                $program_name =~ s/^\s+|\s+$//g;
                $prop_name    =~ s/^\s+|\s+$//g;

                if ($program_name eq $breeding_program) {
                    $stage_prop_name = $prop_name;
                    last;
                }
            }

            next unless $stage_prop_name;

            my $cvterm_row = SGN::Model::Cvterm->get_cvterm_row(
                $schema,
                $stage_prop_name,
                'stock_property'
            );

            unless ($cvterm_row) {
                die "Could not find stock_property cvterm [$stage_prop_name]";
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

            if ($stockprop) {
                $stockprop->value($new_stage);
                $stockprop->update();
            }
            else {
                $schema->resultset('Stock::Stockprop')->create({
                    stock_id => $stock_id,
                    type_id  => $type_id,
                    value    => $new_stage,
                    rank     => 0,
                });
            }
        }
    };
    if ($@) {
        return $self->status_bad_request($c, message => "Failed to save decisions: $@");
    }

    $c->stash(
        current_view => 'JSON',
        json_data    => {
            success      => JSON::true,
            meeting_id   => $meeting_id,
            saved_status => 'successfully',
            message      => 'Decisions saved successfully'
        }
    );
}

sub decision_upload_template : Path('decision_upload_template') : Args(0) {
    my ($self, $c) = @_;

    unless ($c->user) {
        $c->res->status(403);
        $c->res->content_type('application/json');
        $c->res->body(encode_json({ error => 'Login required' }));
        return;
    }

    my $list_id    = $c->req->param('list_id');
    my $meeting_id = $c->req->param('meeting_id');

    unless ($list_id) {
        $c->res->status(400);
        $c->res->content_type('application/json');
        $c->res->body(encode_json({ error => 'Missing list_id' }));
        return;
    }

    my $entity = $self->_decision_rows_entity(
        $c,
        list_id    => $list_id,
        meeting_id => $meeting_id,
    );

    my @headers = $self->_decision_upload_headers();
    my @rows = @{$entity->{rows} || []};

    $c->tempfiles_subdir("decisionmeeting");
    my $temp_dir = $c->config->{basepath} . "/$c->{tempfiles_subdir}";
    if (!-d $temp_dir) {
        make_path($temp_dir) or die "Could not create temp directory $temp_dir: $!";
    }
    my $tempfile = $c->config->{basepath} . "/" . $c->tempfile(TEMPLATE => 'decisionmeeting/dm_template_XXXXXX');
    my $wb = Excel::Writer::XLSX->new($tempfile);
    die "Could not create Excel template" unless $wb;

    my $ws = $wb->add_worksheet('Decisions');
    for my $col (0 .. $#headers) {
        $ws->write(0, $col, $headers[$col]);
    }

    my $line = 1;
    foreach my $row (@rows) {
        $ws->write_row($line, 0, [
            $row->{accession}        || '',
            $row->{breeding_program} || '',
            $row->{stage}            || '',
            $row->{decision}         || '',
            $row->{new_stage}        || '',
            $row->{notes}            || '',
            $row->{save_comment}     || '',
        ]);
        $line++;
    }
    $wb->close();

    open(my $fh, '<', $tempfile) or die "Could not open template file: $!";
    binmode $fh;
    local $/;
    my $output = <$fh>;
    close($fh);
    unlink $tempfile;

    my $filename = 'decision_meeting_upload_template.xlsx';
    $c->res->status(200);
    $c->res->content_type('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    $c->res->header('Content-Disposition', qq[attachment; filename="$filename"]);
    $c->res->body($output);
}

sub upload_decision_template : Path('upload_decision_template') : Args(0) : ActionClass('REST') { }
sub upload_decision_template_POST {
    my ($self, $c) = @_;

    return $self->status_forbidden($c, message => 'Login required')
        unless $c->user;

    my $list_id    = $c->req->param('list_id');
    my $meeting_id = $c->req->param('meeting_id');

    return $self->status_bad_request($c, message => 'Missing list_id')
        unless $list_id;
    return $self->status_bad_request($c, message => 'Missing meeting_id')
        unless $meeting_id;

    my $upload = $c->req->upload('decision_upload_file');
    return $self->status_bad_request($c, message => 'Missing uploaded Excel file')
        unless $upload;

    my ($parsed_rows, $parse_errors) = $self->_parse_decision_upload_file(
        filename          => $upload->tempname,
        original_filename => $upload->filename,
    );

    if ($parse_errors && @$parse_errors) {
        return $self->status_bad_request($c, message => join(' ', @$parse_errors));
    }

    my $entity = $self->_decision_rows_entity(
        $c,
        list_id    => $list_id,
        meeting_id => $meeting_id,
    );

    my @current_rows = @{$entity->{rows} || []};
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $meeting_year = $self->_meeting_year_from_meeting_id($c, $meeting_id);

    unless ($meeting_year) {
        return $self->status_bad_request($c, message => 'The selected meeting does not have a valid date/year, so uploaded stages cannot be validated.');
    }

    my ($validation_errors, $unmatched_rows) = $self->_validate_uploaded_decision_rows(
        c            => $c,
        schema       => $schema,
        meeting_year => $meeting_year,
        current_rows => \@current_rows,
        parsed_rows  => $parsed_rows,
    );

    if ($validation_errors && @$validation_errors) {
        return $self->status_bad_request($c, message => join(' ', @$validation_errors));
    }

    my %current_lookup;
    foreach my $row (@current_rows) {
        my $key = join("\t", lc($row->{accession} || ''), lc($row->{breeding_program} || ''));
        $current_lookup{$key} = $row;
    }

    my $updated_count = 0;
    foreach my $uploaded (@{$parsed_rows || []}) {
        my $key = join("\t", lc($uploaded->{accession} || ''), lc($uploaded->{breeding_program} || ''));
        my $target = $current_lookup{$key};
        next unless $target;

        $target->{decision}     = $uploaded->{decision} || '';
        $target->{new_stage}    = $uploaded->{new_stage} || '';
        $target->{notes}        = $uploaded->{notes} || '';
        $target->{save_comment} = $uploaded->{save_comment} || '';
        $updated_count++;
    }

    return $self->status_ok($c, entity => {
        success        => JSON::true,
        rows           => \@current_rows,
        updated_count  => $updated_count,
        unmatched_rows => $unmatched_rows,
        message        => 'Decision upload processed successfully',
    });
}

sub meetings : Path('meetings') : Args(0) : ActionClass('REST') {}
sub meetings_GET {
    my ($self, $c) = @_;
    my $dbh = $c->dbc->dbh;

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    my $design_type_row   = SGN::Model::Cvterm->get_cvterm_row($schema, 'design', 'project_property');
    my $mtg_json_type_row = SGN::Model::Cvterm->get_cvterm_row($schema, 'meeting_json', 'project_property');

    my $design_type_id   = $design_type_row   ? $design_type_row->cvterm_id : undef;
    my $mtg_json_type_id = $mtg_json_type_row ? $mtg_json_type_row->cvterm_id : undef;

    if (!$design_type_id || !$mtg_json_type_id) {
        $c->stash->{rest} = { rows => [] };
        $c->detach($c->view('JSON'));
        return;
    }

    my $ps = CXGN::BreedersToolbox::Projects->new({ schema => $schema });
    my $programs = $ps->get_breeding_programs() || [];

    my %program_id_to_name;
    foreach my $p (@$programs) {
        my ($pid, $pname) = ('', '');

        if (ref($p) eq 'ARRAY') {
            $pid   = defined $p->[0] ? $p->[0] : '';
            $pname = defined $p->[1] ? $p->[1] : '';
        }
        elsif (ref($p) eq 'HASH') {
            $pid   = $p->{program_id} // $p->{project_id} // $p->{id} // '';
            $pname = $p->{name} // $p->{project_name} // '';
        }

        next unless defined $pid && $pid ne '';
        next unless defined $pname && $pname ne '';

        $program_id_to_name{$pid} = $pname;
    }

    my $sth_a = $dbh->prepare(qq{
        SELECT p.project_id, p.name AS project_name
          FROM project p
          JOIN projectprop pp
            ON pp.project_id = p.project_id
           AND pp.type_id = ?
           AND pp.value   = 'Meeting'
    });
    $sth_a->execute($design_type_id);

    my @projects;
    my @ids;
    while (my $r = $sth_a->fetchrow_hashref) {
        push @projects, $r;
        push @ids, $r->{project_id};
    }

    if (!@ids) {
        $c->stash->{rest} = { rows => [] };
        $c->detach($c->view('JSON'));
        return;
    }

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

    my %json_for;
    while (my $r = $sth_b->fetchrow_hashref) {
        next if exists $json_for{ $r->{project_id} };
        $json_for{ $r->{project_id} } = $r->{meeting_json};
    }

    my @rows;
    for my $p (@projects) {
        my $pid = $p->{project_id};
        my $mj  = $json_for{$pid};
        next unless defined $mj;

        my $decoded = {};
        eval { $decoded = decode_json($mj) if $mj; };
        $decoded ||= {};

        my $is_saved = 0;
        if (
            exists $decoded->{saved_status}
            && defined $decoded->{saved_status}
            && $decoded->{saved_status} eq 'successfully'
        ) {
            $is_saved = 1;
        }

        if (exists $decoded->{breeding_programs} && ref($decoded->{breeding_programs}) eq 'ARRAY') {
            my @translated = map {
                defined $_ && exists $program_id_to_name{$_}
                    ? $program_id_to_name{$_}
                    : $_
            } @{ $decoded->{breeding_programs} || [] };

            if (@translated > 1) {
                @translated = ($translated[0]);
            }

            $decoded->{breeding_programs} = \@translated;
            $decoded->{breeding_program}  = $translated[0] // '';
        }
        elsif (exists $decoded->{breeding_program}) {
            my $raw = $decoded->{breeding_program};
            my @vals = ref($raw) eq 'ARRAY'
                ? @$raw
                : grep { defined $_ && $_ ne '' } map { s/^\s+|\s+$//gr } split(/\s*,\s*/, ($raw // ''));

            my @translated = map {
                defined $_ && exists $program_id_to_name{$_}
                    ? $program_id_to_name{$_}
                    : $_
            } @vals;

            if (@translated > 1) {
                @translated = ($translated[0]);
            }

            $decoded->{breeding_programs} = \@translated;
            $decoded->{breeding_program}  = $translated[0] // '';
        }

        $decoded->{saved} = $is_saved ? JSON::true : JSON::false;

        push @rows, {
            project_id    => $pid,
            project_name  => $p->{project_name},
            meeting_json  => encode_json($decoded),
            meeting_saved => $is_saved ? JSON::true : JSON::false,
        };
    }

    $c->stash->{rest} = { rows => \@rows };
    $c->detach($c->view('JSON'));
}

sub meeting_report_html : Path('/ajax/decisionmeeting/meeting_report_html') Args(0) {
    my ($self, $c) = @_;

    return $self->status_forbidden($c, message => 'Login required')
        unless $c->user;

    my $meeting_id = $c->req->param('meeting_id');
    return $self->status_bad_request($c, message => 'Missing meeting_id')
        unless $meeting_id;

    my $dbh = $c->dbc->dbh;

    my $sth = $dbh->prepare(q{
        SELECT p.project_id, p.name, pp.value
        FROM project p
        LEFT JOIN projectprop pp
            ON pp.project_id = p.project_id
           AND pp.type_id = (
               SELECT cvterm_id
               FROM cvterm
               WHERE name = 'meeting_json'
               LIMIT 1
           )
        WHERE p.project_id = ?
        LIMIT 1
    });
    $sth->execute($meeting_id);

    my ($project_id, $project_name, $json_value) = $sth->fetchrow_array;

    unless ($project_id) {
        $c->res->status(404);
        $c->res->content_type('text/plain; charset=utf-8');
        $c->res->body("Meeting not found");
        return;
    }

    my $data = {};
    if ($json_value) {
        eval { $data = decode_json($json_value); };
        if ($@) {
            $data = {};
        }
    }

    my $meeting_notes = $data->{meeting_notes} // '';
    my $accessions    = $data->{accessions} || [];
    my $attendees     = $data->{attendees};

    my $saved_status = lc($data->{saved_status} // '');

    if (!$saved_status || $saved_status ne 'successfully') {
        $c->res->status(409);
        $c->res->content_type('application/json; charset=utf-8');
        $c->res->body(encode_json({
            error   => 'Report not available yet',
            message => 'This meeting report cannot be downloaded because decisions have not been saved yet.'
        }));
        return;
    }

    my $rows_html = '';
    foreach my $acc (@$accessions) {
        my $name      = $acc->{accession} // '';
        my $bp        = $acc->{breeding_program} // '';
        my $previous  = $acc->{previous_stage} // '';
        my $decision  = $acc->{decision} // '';
        my $new_stage = $acc->{new_stage} // '';
        my $notes     = $acc->{notes} // '';
        my $comment   = $acc->{save_comment} // '';

        for ($name, $bp, $previous, $decision, $new_stage, $notes, $comment) {
            $_ = '' unless defined $_;
            s/&/&amp;/g;
            s/</&lt;/g;
            s/>/&gt;/g;
            s/"/&quot;/g;
        }

        $rows_html .= qq{
            <tr>
              <td>$name</td>
              <td>$bp</td>
              <td>$previous</td>
              <td>$decision</td>
              <td>$new_stage</td>
              <td>$notes</td>
              <td>$comment</td>
            </tr>
        };
    }

    my $safe_project_name = $project_name // '';
    $safe_project_name =~ s/&/&amp;/g;
    $safe_project_name =~ s/</&lt;/g;
    $safe_project_name =~ s/>/&gt;/g;
    $safe_project_name =~ s/"/&quot;/g;

    $meeting_notes =~ s/&/&amp;/g;
    $meeting_notes =~ s/</&lt;/g;
    $meeting_notes =~ s/>/&gt;/g;
    $meeting_notes =~ s/"/&quot;/g;
    $meeting_notes =~ s/\n/<br>/g;

    my $attendees_html = '';
    if (ref($attendees) eq 'ARRAY') {
        my @safe_attendees = map {
            my $x = defined $_ ? $_ : '';
            $x =~ s/&/&amp;/g;
            $x =~ s/</&lt;/g;
            $x =~ s/>/&gt;/g;
            $x =~ s/"/&quot;/g;
            $x;
        } @$attendees;
        $attendees_html = join(', ', @safe_attendees);
    }
    else {
        $attendees_html = defined $attendees ? $attendees : '';
        $attendees_html =~ s/&/&amp;/g;
        $attendees_html =~ s/</&lt;/g;
        $attendees_html =~ s/>/&gt;/g;
        $attendees_html =~ s/"/&quot;/g;
    }

    my $html = qq{
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Meeting Report - $safe_project_name</title>
  <style>
    body {
      font-family: Arial, sans-serif;
      margin: 30px;
      color: #222;
    }
    h1 {
      margin-bottom: 5px;
    }
    .meta {
      margin-bottom: 20px;
      color: #555;
    }
    .notes {
      margin: 20px 0;
      padding: 12px;
      border: 1px solid #ccc;
      background: #fafafa;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      margin-top: 20px;
      font-size: 13px;
    }
    th, td {
      border: 1px solid #ccc;
      padding: 8px;
      text-align: left;
      vertical-align: top;
    }
    th {
      background: #f2f2f2;
    }
    \@media print {
      .no-print {
        display: none;
      }
      body {
        margin: 10mm;
      }
    }
  </style>
</head>
<body>
  <div class="no-print" style="margin-bottom:20px;">
    <button onclick="window.print()">Print / Save as PDF</button>
  </div>

  <h1>Meeting Report</h1>
  <div class="meta">
    <strong>Meeting:</strong> $safe_project_name<br>
    <strong>Meeting ID:</strong> $meeting_id<br>
    <strong>Attendees:</strong> $attendees_html
  </div>

  <h2>Meeting Notes</h2>
  <div class="notes">$meeting_notes</div>

  <h2>Decisions</h2>
  <table>
    <thead>
      <tr>
        <th>Accession</th>
        <th>Breeding Program</th>
        <th>Previous Stage</th>
        <th>Decision</th>
        <th>New Stage</th>
        <th>Current Notes</th>
        <th>Comment Before Save</th>
      </tr>
    </thead>
    <tbody>
      $rows_html
    </tbody>
  </table>

  <script>
  </script>
</body>
</html>
    };

    $c->res->content_type('text/html; charset=utf-8');
    $c->res->body($html);
}

sub create : Path('create') Args(0) {
    my ($self, $c) = @_;
    return $self->status_forbidden($c, message => 'Login required')
        unless $c->user;

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my @user_roles = $c->user()->roles;

    my $raw_decision_role = $c->config->{decision_role};
    my $decision_role_conf = '';

    if (ref($raw_decision_role) eq 'ARRAY') {
        $decision_role_conf = defined($raw_decision_role->[0]) ? $raw_decision_role->[0] : '';
    }
    else {
        $decision_role_conf = $raw_decision_role // '';
    }

    my @allowed_roles = grep { $_ ne '' }
        map {
            my $x = $_ // '';
            $x =~ s/^\s+|\s+$//g;
            $x;
        }
        split(/\s*,\s*/, $decision_role_conf);

    my %allowed = map { $_ => 1 } @allowed_roles;
    my $can_create_meeting = 0;

    foreach my $role (@user_roles) {
        if ($allowed{$role}) {
            $can_create_meeting = 1;
            last;
        }
    }

    unless ($can_create_meeting) {
        return $self->status_forbidden(
            $c,
            message => 'You are not allowed to create meetings'
        );
    }

    my $p = $c->req->params;

    my $dbh      = $c->dbc->dbh();
    my $person   = $c->user->get_object;
    my $owner_id = $person->get_sp_person_id;
    my $operator = $person->get_username;

    my $trial_name_in = $p->{meeting_name}     // '';
    my $program_in    = $p->{breeding_program} // '';
    my $location_in   = $p->{location}         // '';
    my $trial_year    = $p->{year}             // '';
    my $planting_date = $p->{date}             // undef;
    my $description   = $p->{data}             // '';
    my $meeting_status= $p->{meeting_status}   // '';

    return $self->status_bad_request($c, message => "Missing meeting_name")
        unless $trial_name_in;
    return $self->status_bad_request($c, message => "Missing breeding_program")
        unless ($program_in || ref($p->{breeding_programs}) eq 'ARRAY');
    return $self->status_bad_request($c, message => "Missing location")
        unless $location_in;

    my @program_in_list =
        ref($p->{breeding_programs}) eq 'ARRAY'
            ? grep { defined($_) && $_ ne '' } @{$p->{breeding_programs}}
            : (grep { length($_) } map { s/^\s+|\s+$//gr } split(/\s*,\s*/, ($program_in // '')));

    my $program_choice = $program_in_list[0] // '';
    return $self->status_bad_request($c, message => "Missing breeding_program")
        unless $program_choice;

    my $program_name  = _resolve_program_name($schema, $program_choice)
        or return $self->status_bad_request($c, message => "Breeding program not found: '$program_choice'");
    my $location_name = _resolve_location_name($schema, $location_in)
        or return $self->status_bad_request($c, message => "Location not found: '$location_in'");

    my @program_name_list = grep { defined($_) && $_ ne '' }
                            map  { scalar _resolve_program_name($schema, $_) } @program_in_list;

    my $trial_name = $trial_name_in;

    my $design_cv   = 'experiment_meeting';
    my $design_term = 'meeting_project';

    my $design_cvterm_row = SGN::Model::Cvterm->get_cvterm_row($schema, $design_term, $design_cv);
    die "Cvterm not found: term='$design_term' cv='$design_cv'\n"
        unless $design_cvterm_row;

    my $design_cvterm_id = $design_cvterm_row->cvterm_id;

    my @att_raw;

    if (ref($p->{attendees_list}) eq 'ARRAY') {
        push @att_raw, @{$p->{attendees_list}};
    }

    if (ref($p->{attendees}) eq 'ARRAY') {
        for my $chunk (@{$p->{attendees}}) {
            next unless defined $chunk;
            push @att_raw, split(/\n|,/, $chunk);
        }
    }
    elsif (defined $p->{attendees} && $p->{attendees} ne '') {
        push @att_raw, split(/\n|,/, $p->{attendees});
    }

    if (!@att_raw) {
        my $bd = eval { $c->req->body_data } || {};
        if (ref($bd->{attendees}) eq 'ARRAY') {
            push @att_raw, @{$bd->{attendees}};
        }
        elsif (defined $bd->{attendees} && $bd->{attendees} ne '') {
            push @att_raw, split(/\n|,/, $bd->{attendees});
        }
    }

    my @att_clean = grep { length($_) } map { s/^\s+|\s+$//gr } @att_raw;
    my %seen;
    my $attendees = [ grep { my $k = lc($_); !$seen{$k}++ } @att_clean ];

    my $design_hash = {};

    my $tc = CXGN::Trial::TrialCreate->new({
        chado_schema      => $schema,
        dbh               => $dbh,
        owner_id          => $owner_id,
        operator          => $operator,
        design_type       => 'Meeting',
        design            => $design_hash,
        program           => $program_name,
        trial_year        => $trial_year,
        planting_date     => $planting_date,
        trial_location    => $location_name,
        trial_name        => $trial_name,
        trial_description => $description,
        project_type      => 'meeting_project',
    });

    my ($project_id, $nd_experiment_id);
    my $err;
    try {
        $tc->save_trial();

        $project_id       = eval { $tc->get_trial_id }         || eval { $tc->get_project_id } || undef;
        $nd_experiment_id = eval { $tc->get_nd_experiment_id } || undef;

        my $proj_row = $project_id
            ? $schema->resultset('Project::Project')->find({ project_id => $project_id })
            : $schema->resultset('Project::Project')->find({ name => $trial_name });

        die "Project not found after save_trial" unless $proj_row;

        $project_id = $proj_row->project_id;

        my $meeting_payload = {
            attendees               => $attendees,
            meeting_status          => ($meeting_status || undef),
            breeding_programs       => \@program_in_list,
            breeding_program_names  => \@program_name_list,
            breeding_program_choice => $program_choice,
            breeding_program_name   => $program_name,
            year                    => ($trial_year || undef),
            date                    => ($planting_date || undef),
            location                => $location_name,
            location_raw            => $location_in,
        };
        my $val = encode_json($meeting_payload);

        my $pp_type = SGN::Model::Cvterm->get_cvterm_row($schema, 'meeting_json', 'project_property')
            or die "cvterm meeting_json not found in cv project_property";
        my $type_id = $pp_type->cvterm_id;

        my $existing = $proj_row->search_related('projectprops', { type_id => $type_id })->first;
        if ($existing) {
            $existing->update({ value => $val });
        }
        else {
            $proj_row->create_related('projectprops', { type_id => $type_id, value => $val });
        }

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
                attendees         => $attendees,
            },
        }));
        return;
    }

    $c->res->content_type('application/json');
    $c->res->body(encode_json({
        ok               => \1,
        msg              => "Meeting saved as trial '$trial_name' (type=meeting_project).",
        project_id       => $project_id,
        nd_experiment_id => $nd_experiment_id,
        design_cvterm_id => $design_cvterm_id,
        echo             => {
            meeting_name      => $trial_name_in,
            breeding_programs => \@program_in_list,
            breeding_program  => $program_name,
            location          => $location_name,
            year              => $trial_year,
            date              => $planting_date,
            attendees         => $attendees,
        },
    }));
}

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

    return '' unless $decision_value;

    my $current_token = $self->_extract_stage_token($current_stage_value);
    return '' unless $current_token;

    my @ordered_stages = $self->_config_list($breeding_stages);
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

    return $next_token;
}

sub _resolve_program_name {
    my ($schema, $in) = @_;
    return $in unless defined $in && $in =~ /^\d+$/;
    my $row = $schema->resultset('Project::Project')->find({ project_id => $in });
    return $row ? $row->name : undef;
}

sub _resolve_location_name {
    my ($schema, $in) = @_;
    return $in unless defined $in && $in =~ /^\d+$/;
    my $row = $schema->resultset('NaturalDiversity::NdGeolocation')->find({ nd_geolocation_id => $in })
          || $schema->resultset('NdGeolocation')->find({ nd_geolocation_id => $in });
    return unless $row;
    return $row->can('description') ? ($row->description // '') : ($row->can('name') ? $row->name : '');
}

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

1;
