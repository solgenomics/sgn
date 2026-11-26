package CXGN::VarietySheet;

=head1 NAME

CXGN::VarietySheet - commercial variety release profiles built from Breedbase data

=head1 DESCRIPTION

A variety profile is a commercial summary of one accession: a commercial name,
pedigree, testing evidence (trials, locations, years), head-to-head performance
against check varieties, trait ratings (e.g. disease reactions), photos and
free-text sections. The profile content is stored as JSON in phenome.variety_sheet
(db patch AddVarietySheetTable). The numbers shown on a profile are a snapshot
taken when the profile was saved, so a published profile does not change when new
data arrive; the editor can refresh them.

The class methods below collect the data the profile editor needs.

=head1 AUTHOR

Breedbase

=cut

use strict;
use warnings;
use JSON::XS;
use List::Util qw(sum max min);
use SGN::Model::Cvterm;

# scalar 'no value' (a bare return would break hash constructors that call these subs)
my $NONE;

my $NUM_RE = '^\s*-?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?\s*$';

sub _cvterm_id {
    my ($schema, $name, $cv) = @_;
    my $row = SGN::Model::Cvterm->get_cvterm_row($schema, $name, $cv);
    return $row ? $row->cvterm_id() : undef;
}

sub _in_list {
    my @ids = grep { defined $_ && /^\d+$/ } @_;
    return @ids ? join(',', @ids) : 'NULL';
}

# Names that may appear on a profile: the released variety name when the
# accession has one, else its accession name. Experimental names of released
# checks are confidential and never go on a sheet.
sub public_names {
    my ($class, $dbh, @ids) = @_;
    my $in = _in_list(@ids);
    my %n = map { $_->[0] => $_->[1] } @{ $dbh->selectall_arrayref("SELECT stock_id, uniquename FROM stock WHERE stock_id IN ($in)") };
    my $rel = $class->released_names($dbh, @ids);
    $n{$_} = $rel->{$_} for keys %$rel;
    return \%n;
}

# stock_id => released variety name, only for accessions that have one
# (the only names the profile's descriptions may use)
sub released_names {
    my ($class, $dbh, @ids) = @_;
    my $in = _in_list(@ids);
    my $rows = $dbh->selectall_arrayref(
        "SELECT sp.stock_id, sp.value FROM stockprop sp JOIN cvterm c ON c.cvterm_id=sp.type_id
          WHERE c.name='released_variety_name' AND sp.stock_id IN ($in) AND sp.value <> '' ORDER BY sp.rank DESC");
    my %r;
    $r{$_->[0]} = $_->[1] for @$rows;    # lowest rank wins
    return \%r;
}

# Stock types whose phenotypes count as field testing.
sub _field_unit_type_ids {
    my $schema = shift;
    return grep { defined } map { _cvterm_id($schema, $_, 'stock_type') } qw(plot subplot plant);
}

=head2 accession_summary($schema, $stock_id)

Returns a hashref with names, pedigree, testing evidence, traits, analyses and
suggested checks for one accession. Images are added by the controller (they
need the Catalyst context to build URLs).

=cut

sub accession_summary {
    my ($class, $schema, $stock_id) = @_;
    my $dbh = $schema->storage->dbh();

    my $accession_type_id = _cvterm_id($schema, 'accession', 'stock_type');
    my ($name, $type_id, $organism) = $dbh->selectrow_array(
        "SELECT s.uniquename, s.type_id, o.species FROM stock s LEFT JOIN organism o USING(organism_id) WHERE s.stock_id=? AND s.is_obsolete='f'",
        undef, $stock_id);
    return { error => "Accession $stock_id not found." } unless $name;
    return { error => "$name is not an accession." } if $accession_type_id && $type_id != $accession_type_id;

    my %r = (stock_id => $stock_id + 0, accession_name => $name, species => $organism);

    # properties
    my $props = $dbh->selectall_arrayref(
        "SELECT c.name, sp.value FROM stockprop sp JOIN cvterm c ON c.cvterm_id=sp.type_id WHERE sp.stock_id=? AND c.name IN ('stock_synonym','released_variety_name','variety','organization','notes') ORDER BY sp.rank",
        undef, $stock_id);
    $r{synonyms} = [ map { $_->[1] } grep { $_->[0] eq 'stock_synonym' } @$props ];
    $r{released_variety_name} = [ map { $_->[1] } grep { $_->[0] eq 'released_variety_name' } @$props ];
    $r{variety} = [ map { $_->[1] } grep { $_->[0] eq 'variety' } @$props ];

    $r{pedigree} = $class->pedigree($schema, $stock_id);
    $r{evidence} = $class->testing_evidence($schema, $stock_id);
    $r{traits} = $class->traits($schema, $stock_id);
    $r{analyses} = $class->analyses_with_accession($schema, $stock_id);
    $r{suggested_checks} = $class->suggested_checks($schema, $stock_id);
    $r{sheets} = $class->list_sheets($schema, { stock_id => $stock_id });
    $r{meetings} = $class->decision_meetings($schema, $stock_id);
    return \%r;
}

=head2 decision_meetings($schema, $stock_id)

Every decision meeting (project with design 'Meeting') where the accession
was discussed, oldest first, with the decision taken for it in each one:
[{ meeting_id, meeting_name, date, location, program, decision,
   previous_stage, new_stage, comment }]

=cut

sub decision_meetings {
    my ($class, $schema, $stock_id) = @_;
    my $json_type = _cvterm_id($schema, 'meeting_json', 'project_property');
    return [] unless $json_type;
    my $rows = eval {
        $schema->storage->dbh->selectall_arrayref(
            "WITH m AS (
                 SELECT DISTINCT ON (pp.project_id) pp.project_id, p.name, pp.value
                   FROM projectprop pp JOIN project p ON p.project_id = pp.project_id
                  WHERE pp.type_id = ? AND pp.value LIKE '%' || ? || '%'
                  ORDER BY pp.project_id, pp.projectprop_id DESC)
             SELECT m.project_id, m.name, m.value::jsonb->>'meeting_name', m.value::jsonb->>'date',
                    coalesce(m.value::jsonb->>'location_name', m.value::jsonb->>'location'),
                    e->>'breeding_program', e->>'decision', e->>'previous_stage', e->>'new_stage',
                    coalesce(nullif(e->>'save_comment', ''), e->>'notes')
               FROM m, jsonb_array_elements(CASE WHEN jsonb_typeof(m.value::jsonb->'accessions') = 'array'
                                                 THEN m.value::jsonb->'accessions' ELSE '[]'::jsonb END) e
              WHERE e->>'stock_id' = ?
              ORDER BY 4 NULLS FIRST, 1",
            undef, $json_type, $stock_id, "$stock_id");
    } || [];
    return [ map { {
        meeting_id => $_->[0] + 0, meeting_name => $_->[2] || $_->[1], date => $_->[3] // '', location => $_->[4] // '',
        program => $_->[5] // '', decision => $_->[6] // '', previous_stage => $_->[7] // '', new_stage => $_->[8] // '',
        comment => $_->[9] // '',
    } } @$rows ];
}

=head2 meeting_selections($schema, \%filters)

Accessions selected in decision meetings (decision 'advance' or 'jump'), ONE row
per accession (its latest matching decision), filtered and paged in SQL so it
scales to any number of meetings. Saved meetings give their saved decisions;
meetings not saved yet give their draft decisions (meeting_json.draft_decisions,
keyed "accession\tprogram"), marked draft => 1.

Filters: q (accession or meeting name), program, from / to (meeting date
YYYY-MM-DD), meeting_id, no_profile (only accessions without a profile),
stages (arrayref: keep decisions whose new stage, e.g. ON-26-Y5 -> Y5, is one
of them), page (1..), page_size (default 25, max 100), with_programs (also
return the programs that have selections, for the filter).

Returns { rows => [{ stock_id, accession, decision, previous_stage, new_stage,
program, draft, meeting_id, meeting_name, date, saved, n_meetings,
profiles => [{ variety_sheet_id, status, commercial_name }] }],
total, page, page_size, programs => [...] (only with with_programs) }.

=cut

# every advance/jump decision: saved ones, or drafts of meetings not saved yet
# (same "saved" rule as the Decision Meeting page); binds: meeting_json type, accession type
sub _selection_sql {
    return <<'SQL';
      WITH m AS (
        SELECT DISTINCT ON (pp.project_id) pp.project_id AS meeting_id, p.name AS project_name, pp.value::jsonb AS j
          FROM projectprop pp JOIN project p ON p.project_id = pp.project_id
         WHERE pp.type_id = ? AND pp.value LIKE '{%'
         ORDER BY pp.project_id, pp.projectprop_id DESC),
      mm AS (
        SELECT meeting_id, j,
               coalesce(nullif(j->>'meeting_name', ''), project_name) AS meeting_name,
               CASE WHEN j->>'date' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}' THEN substr(j->>'date', 1, 10) ELSE '' END AS mdate,
               (   lower(coalesce(j->>'saved', '')) IN ('1', 'true') OR lower(coalesce(j->>'is_saved', '')) IN ('1', 'true')
                OR lower(coalesce(j->>'meeting_saved', '')) IN ('1', 'true') OR lower(coalesce(j->>'decisions_saved', '')) IN ('1', 'true')
                OR coalesce(j->>'saved_at', '') <> ''
                OR lower(coalesce(j->>'saved_status', j->>'status', '')) IN ('successfully', 'saved')) AS saved
          FROM m),
      d AS (
        SELECT mm.meeting_id, mm.meeting_name, mm.mdate, mm.saved, e->>'stock_id' AS sid, e->>'accession' AS acc,
               lower(e->>'decision') AS decision, coalesce(e->>'previous_stage', '') AS previous_stage,
               coalesce(e->>'new_stage', '') AS new_stage, coalesce(e->>'breeding_program', '') AS program, false AS draft
          FROM mm, jsonb_array_elements(CASE WHEN jsonb_typeof(mm.j->'accessions') = 'array' THEN mm.j->'accessions' ELSE '[]'::jsonb END) e
         WHERE jsonb_typeof(e) = 'object' AND lower(e->>'decision') IN ('advance', 'jump')
        UNION ALL
        SELECT mm.meeting_id, mm.meeting_name, mm.mdate, mm.saved, NULL, split_part(x.k, E'\t', 1),
               lower(x.v->>'decision'), '', coalesce(x.v->>'new_stage', ''), split_part(x.k, E'\t', 2), true
          FROM mm, jsonb_each(CASE WHEN jsonb_typeof(mm.j->'draft_decisions') = 'object' THEN mm.j->'draft_decisions' ELSE '{}'::jsonb END) AS x(k, v)
         WHERE NOT mm.saved AND jsonb_typeof(x.v) = 'object' AND lower(x.v->>'decision') IN ('advance', 'jump')),
      r AS (
        SELECT d.*, coalesce(s1.stock_id, s2.stock_id) AS stock_id, coalesce(s1.uniquename, s2.uniquename) AS accession
          FROM d
          LEFT JOIN stock s1 ON s1.stock_id = (CASE WHEN d.sid ~ '^[0-9]{1,9}$' THEN d.sid::int END) AND s1.is_obsolete = 'f'
          LEFT JOIN stock s2 ON s1.stock_id IS NULL AND s2.uniquename = d.acc AND s2.type_id = ? AND s2.is_obsolete = 'f')
SQL
}

sub meeting_selections {
    my ($class, $schema, $f) = @_;
    $f ||= {};
    my $json_type = _cvterm_id($schema, 'meeting_json', 'project_property');
    my $acc_type = _cvterm_id($schema, 'accession', 'stock_type');
    my $page_size = ($f->{page_size} // '') =~ /^\d+$/ && $f->{page_size} > 0 ? ($f->{page_size} > 100 ? 100 : $f->{page_size} + 0) : 25;
    my $page = ($f->{page} // '') =~ /^\d+$/ && $f->{page} > 0 ? $f->{page} + 0 : 1;
    return { rows => [], total => 0, page => 1, page_size => $page_size, programs => [] } unless $json_type && $acc_type;
    my $dbh = $schema->storage->dbh();
    my $base = _selection_sql();
    my @base_bind = ($json_type, $acc_type);

    my @w = ('r.stock_id IS NOT NULL');
    my @b;
    if (length($f->{q} // '')) {
        my $q = $f->{q};
        $q =~ s/([\\%_])/\\$1/g;
        push @w, '(r.accession ILIKE ? OR r.meeting_name ILIKE ?)';
        push @b, "%$q%", "%$q%";
    }
    if (length($f->{program} // '')) { push @w, 'r.program = ?'; push @b, $f->{program}; }
    if (($f->{from} // '') =~ /^\d{4}-\d{2}-\d{2}$/) { push @w, "r.mdate <> '' AND r.mdate >= ?"; push @b, $f->{from}; }
    if (($f->{to} // '') =~ /^\d{4}-\d{2}-\d{2}$/) { push @w, "r.mdate <> '' AND r.mdate <= ?"; push @b, $f->{to}; }
    if (($f->{meeting_id} // '') =~ /^\d+$/) { push @w, 'r.meeting_id = ?'; push @b, $f->{meeting_id}; }
    push @w, 'NOT EXISTS (SELECT 1 FROM phenome.variety_sheet v WHERE v.stock_id = r.stock_id)' if $f->{no_profile};
    my @stages = grep { length } map { my $x = uc($_ // ''); $x =~ s/^\s+|\s+$//g; $x } @{ $f->{stages} || [] };
    if (@stages) { push @w, "upper(regexp_replace(r.new_stage, '^.*-', '')) = ANY(?)"; push @b, \@stages; }
    my $where = join(' AND ', @w);

    my $rows = $dbh->selectall_arrayref(
        "$base,
         f AS (SELECT r.* FROM r WHERE $where),
         n AS (SELECT stock_id AS n_stock_id, count(DISTINCT meeting_id) AS n_meetings FROM f GROUP BY stock_id),
         one AS (SELECT DISTINCT ON (f.stock_id) f.*, n.n_meetings FROM f JOIN n ON n.n_stock_id = f.stock_id
                  ORDER BY f.stock_id, f.mdate DESC, f.meeting_id DESC, f.draft)
         SELECT stock_id, accession, decision, previous_stage, new_stage, program, draft, meeting_id, meeting_name, mdate, saved, n_meetings,
                count(*) OVER () AS total
           FROM one ORDER BY mdate DESC, meeting_id DESC, lower(accession)
          LIMIT ? OFFSET ?",
        { Slice => {} }, @base_bind, @b, $page_size, ($page - 1) * $page_size);

    my $programs = $f->{with_programs}
        ? $dbh->selectcol_arrayref("$base SELECT DISTINCT program FROM r WHERE program <> '' AND stock_id IS NOT NULL ORDER BY 1", undef, @base_bind)
        : undef;

    my %profiles;
    if (@$rows) {
        my $p = $dbh->selectall_arrayref(
            "SELECT stock_id, variety_sheet_id, status, commercial_name FROM phenome.variety_sheet WHERE stock_id = ANY(?) ORDER BY modified_date DESC",
            undef, [ map { $_->{stock_id} } @$rows ]);
        push @{ $profiles{ $_->[0] } }, { variety_sheet_id => $_->[1] + 0, status => $_->[2], commercial_name => $_->[3] } for @$p;
    }
    my $total = @$rows ? $rows->[0]{total} + 0 : 0;
    for my $r (@$rows) {
        delete $r->{total};
        $r->{date} = delete $r->{mdate};
        $r->{$_} += 0 for qw(stock_id meeting_id n_meetings);
        $r->{$_} = $r->{$_} ? 1 : 0 for qw(draft saved);
        $r->{profiles} = $profiles{ $r->{stock_id} } || [];
    }
    return { rows => $rows, total => $total, page => $page, page_size => $page_size, ($programs ? (programs => $programs) : ()) };
}

=head2 selection_meetings($schema, $q)

Meetings with at least one selected accession, newest first, for the meeting
search box: [{ meeting_id, meeting_name, date, saved, n_selected }] (max 20).

=cut

sub selection_meetings {
    my ($class, $schema, $q) = @_;
    my $json_type = _cvterm_id($schema, 'meeting_json', 'project_property');
    my $acc_type = _cvterm_id($schema, 'accession', 'stock_type');
    return [] unless $json_type && $acc_type;
    my @w = ('r.stock_id IS NOT NULL');
    my @b;
    if (length($q // '')) {
        $q =~ s/([\\%_])/\\$1/g;
        push @w, 'r.meeting_name ILIKE ?';
        push @b, "%$q%";
    }
    my $rows = $schema->storage->dbh->selectall_arrayref(
        _selection_sql() . " SELECT meeting_id, meeting_name, mdate AS date, bool_or(saved) AS saved, count(DISTINCT stock_id) AS n_selected
           FROM r WHERE " . join(' AND ', @w) . "
          GROUP BY meeting_id, meeting_name, mdate ORDER BY mdate DESC, meeting_id DESC LIMIT 20",
        { Slice => {} }, $json_type, $acc_type, @b);
    for my $m (@$rows) {
        $m->{$_} += 0 for qw(meeting_id n_selected);
        $m->{saved} = $m->{saved} ? 1 : 0;
    }
    return $rows;
}

=head2 pedigree($schema, $stock_id)

Parents and grandparents (two generations) with the cross type.

=cut

sub pedigree {
    my ($class, $schema, $stock_id) = @_;
    my $dbh = $schema->storage->dbh();
    my $female = _cvterm_id($schema, 'female_parent', 'stock_relationship');
    my $male = _cvterm_id($schema, 'male_parent', 'stock_relationship');
    return {} unless $female && $male;

    my $q = "SELECT r.type_id, p.stock_id, p.uniquename, r.value FROM stock_relationship r JOIN stock p ON p.stock_id=r.subject_id WHERE r.object_id=? AND r.type_id IN (?,?)";
    my $h = $dbh->prepare($q);
    my $parents = sub {
        my $id = shift;
        $h->execute($id, $female, $male);
        my %p;
        while (my ($t, $pid, $pname, $cross_type) = $h->fetchrow_array()) {
            my $k = $t == $female ? 'female' : 'male';
            $p{$k} = { stock_id => $pid + 0, name => $pname };
            $p{cross_type} = $cross_type if $cross_type;
        }
        return \%p;
    };
    my $ped = $parents->($stock_id);
    for my $k (qw(female male)) {
        next unless $ped->{$k};
        my $gp = $parents->($ped->{$k}{stock_id});
        $ped->{$k}{female} = $gp->{female} if $gp->{female};
        $ped->{$k}{male} = $gp->{male} if $gp->{male};
    }
    # released variety names: the only parent names a profile's text may use
    my @nodes = grep { $_ } map { ($_, $_ ? ($_->{female}, $_->{male}) : ()) } ($ped->{female}, $ped->{male});
    my $rel = $class->released_names($dbh, map { $_->{stock_id} } @nodes);
    $_->{released_name} = $rel->{ $_->{stock_id} } for grep { $rel->{ $_->{stock_id} } } @nodes;
    return $ped;
}

=head2 testing_evidence($schema, $stock_id)

Counts of field trials, locations, years, programs and plots in which the
accession has phenotypes, with the list of locations (coordinates, country).

=cut

sub testing_evidence {
    my ($class, $schema, $stock_id) = @_;
    my $dbh = $schema->storage->dbh();
    my $units = _in_list(_field_unit_type_ids($schema));
    my $country_type = _cvterm_id($schema, 'country_name', 'geolocation_property') || 0;

    my $rows = $dbh->selectall_arrayref(
        "SELECT m.trial_id, m.location_id, m.year_id, m.breeding_program_id, count(DISTINCT m.stock_id)
           FROM materialized_phenoview m JOIN stock s ON s.stock_id=m.stock_id
          WHERE m.accession_id=? AND m.trait_id IS NOT NULL AND s.type_id IN ($units)
          GROUP BY 1,2,3,4", undef, $stock_id);

    my (%trials, %locs, %years, %programs, $plots);
    for my $row (@$rows) {
        my ($trial, $loc, $year, $prog, $n) = @$row;
        $trials{$trial} = 1;
        $locs{$loc}{$trial} = 1 if $loc;
        $years{$year} = 1 if defined $year && $year =~ /^\d{4}$/;
        $programs{$prog} = 1 if $prog;
        $plots += $n;
    }

    my @locations;
    if (%locs) {
        my $ids = _in_list(keys %locs);
        my $lr = $dbh->selectall_arrayref(
            "SELECT g.nd_geolocation_id, g.description, g.latitude, g.longitude, cp.value
               FROM nd_geolocation g LEFT JOIN nd_geolocationprop cp ON cp.nd_geolocation_id=g.nd_geolocation_id AND cp.type_id=?
              WHERE g.nd_geolocation_id IN ($ids)", undef, $country_type);
        for my $l (@$lr) {
            push @locations, { id => $l->[0] + 0, name => $l->[1], lat => $l->[2], lon => $l->[3], country => $l->[4],
                               trials => scalar(keys %{$locs{$l->[0]}}) };
        }
        @locations = sort { $b->{trials} <=> $a->{trials} || $a->{name} cmp $b->{name} } @locations;
    }
    my %countries;
    $countries{$_->{country}} += $_->{trials} for grep { $_->{country} } @locations;

    my @program_names;
    if (%programs) {
        my $ids = _in_list(keys %programs);
        @program_names = map { $_->[0] } @{ $dbh->selectall_arrayref("SELECT name FROM project WHERE project_id IN ($ids) ORDER BY name") };
    }
    my @years = sort keys %years;
    return {
        trials => scalar(keys %trials),
        locations => scalar(keys %locs),
        years => scalar(@years),
        year_list => \@years,
        year_min => $years[0],
        year_max => $years[-1],
        plots => $plots || 0,
        programs => \@program_names,
        countries => [ map { { name => $_, trials => $countries{$_} } } sort { $countries{$b} <=> $countries{$a} } keys %countries ],
        location_list => \@locations,
    };
}

=head2 traits($schema, $stock_id)

Traits measured on the accession in field trials, with the number of trials,
a suggested direction (lower is better for disease, lodging, etc.) and scale.

=cut

sub traits {
    my ($class, $schema, $stock_id) = @_;
    my $dbh = $schema->storage->dbh();
    my $units = _in_list(_field_unit_type_ids($schema));
    my $rows = $dbh->selectall_arrayref(
        "SELECT m.trait_id, c.name, c.definition, db.name || ':' || x.accession, count(DISTINCT m.trial_id), count(*),
                sum(CASE WHEN p.value ~ '$NUM_RE' THEN 1 ELSE 0 END)
           FROM materialized_phenoview m
           JOIN stock s ON s.stock_id=m.stock_id
           JOIN phenotype p ON p.phenotype_id=m.phenotype_id
           JOIN cvterm c ON c.cvterm_id=m.trait_id
           LEFT JOIN dbxref x ON x.dbxref_id=c.dbxref_id LEFT JOIN db ON db.db_id=x.db_id
          WHERE m.accession_id=? AND s.type_id IN ($units)
          GROUP BY 1,2,3,4 ORDER BY 5 DESC, 2", undef, $stock_id);

    my %scale = $class->_trait_scales($schema, [ map { $_->[0] } @$rows ]);
    my @traits;
    for my $r (@$rows) {
        my ($id, $name, $def, $acc, $ntrials, $nobs, $nnum) = @$r;
        push @traits, {
            trait_id => $id + 0, name => $name, accession => $acc, definition => $def,
            label => _suggest_label($name, $def), unit => _suggest_unit($name, $def), trials => $ntrials + 0, observations => $nobs + 0,
            numeric => ($nnum >= $nobs * 0.8 ? 1 : 0),
            direction => _suggest_direction($name, $def),
            direction_known => _direction_known($name, $def),
            kind => _suggest_kind($name, $def),
            %{ $scale{$id} || {} },
        };
    }
    return \@traits;
}

sub _trait_scales {
    my ($class, $schema, $ids) = @_;
    return () unless @$ids;
    my $in = _in_list(@$ids);
    my %s;
    my $rows = $schema->storage->dbh->selectall_arrayref(
        "SELECT cp.cvterm_id, c.name, cp.value FROM cvtermprop cp JOIN cvterm c ON c.cvterm_id=cp.type_id
          WHERE cp.cvterm_id IN ($in) AND c.name IN ('trait_minimum','trait_maximum','trait_format','trait_categories','trait_details')");
    for my $r (@$rows) {
        my ($id, $k, $v) = @$r;
        $k =~ s/^trait_//;
        $s{$id}{"scale_$k"} = $v;
    }
    return %s;
}

sub _suggest_label {
    my ($name, $def) = @_;
    return $name unless $def;
    my $l = $def;
    $l =~ s/^"|"$//g;
    # definitions written as method|unit|description
    $l = (split /\|/, $l)[-1] if $l =~ /^[^|]{0,30}\|[^|]{0,30}\|./;
    $l =~ s/[.;].*$//s;
    $l =~ s/\s+/ /g;
    return length($l) > 2 && length($l) <= 60 ? ucfirst($l) : $name;
}

# unit from definitions written as method|unit|description
sub _suggest_unit {
    my ($name, $def) = @_;
    return $NONE unless $def && $def =~ /^"?[^|]{0,30}\|([^|]{1,20})\|./;
    my $u = $1;
    my %map = (kgha => 'kg/ha', kgplot => 'kg/plot', plntha => 'plants/ha', plntplot => 'plants/plot', '1to9' => '1–9', '1to5' => '1–5', ymd => '', ctplot => 'per plot');
    return exists $map{lc $u} ? $map{lc $u} : $u;
}

my $LOWER_IS_BETTER = qr/sev|disease|incid|lodg|scab|rot|blight|rust|spot|damage|virus|mildew|wilt|shatter|moisture|moist|gmoi|defect|days to|maturity date|dtm|aflatox|mycotox|pest|insect|nematode|lesion|infect/;
my $HIGHER_IS_BETTER = qr/yield|\byld\b|^yld|_yld|^gy_|marketable|production|kg\/ha|t\/ha|bu\/a|cwt|dry matter|starch|protein|oil content|brix|resist|toleran|survival|vigou?r|germination/;

sub _suggest_direction {
    my $t = lc(join ' ', grep { defined } @_);
    return 'lower' if $t =~ $LOWER_IS_BETTER;
    return 'higher';
}

# 1 when the name says which way is better (yield up, disease down ...); 0 for descriptive
# traits (height, flowering time, kernel weight, 1-9 aspect scores ...) that should be
# described, not judged against a check
sub _direction_known {
    my $t = lc(join ' ', grep { defined } @_);
    return ($t =~ $LOWER_IS_BETTER || $t =~ $HIGHER_IS_BETTER) ? 1 : 0;
}

sub _suggest_kind {
    my $t = lc(join ' ', grep { defined } @_);
    return 'disease' if $t =~ /sev|disease|incid|scab|rot|blight|rust|spot|virus|mildew|wilt|nematode|lesion|infect|resist/;
    return 'agronomic';
}

=head2 trait_importance($schema, $stock_id)

Ranks the traits of an accession by how much they matter, from the data alone
(no configuration):

  coverage  share of the accession's trials that measured the trait
  routine   share of all entries of those trials measured for it (a trait the
            program records on everything, not a special subset)
  analysed  share of the stored analyses holding the accession that include it
            (breeders analyse what they select on); 'decided' when such an
            analysis was linked to a decision meeting about the accession
  yield     the name or definition reads like yield / production
  housekeeping penalty for plot size, stand counts, dates, notes

Returns [{ trait_id, name, score (0..1), coverage, routine, analysed, decided,
yield, housekeeping, reasons => [plain-language strings] }] sorted by score.

=cut

sub trait_importance {
    my ($class, $schema, $stock_id, $traits) = @_;
    my $dbh = $schema->storage->dbh();
    $traits ||= $class->traits($schema, $stock_id);
    return [] unless @$traits;
    my $units = _in_list(_field_unit_type_ids($schema));

    # trials of the accession, and per trait: trials and entries measured in them
    my $trials = $dbh->selectcol_arrayref(
        "SELECT DISTINCT m.trial_id FROM materialized_phenoview m JOIN stock s ON s.stock_id=m.stock_id
          WHERE m.accession_id=? AND m.trait_id IS NOT NULL AND s.type_id IN ($units)", undef, $stock_id);
    my $n_trials = scalar @$trials;
    my (%entries, $all_entries);
    if (@$trials) {
        my $tin = _in_list(@$trials);
        my $rows = $dbh->selectall_arrayref(
            "SELECT m.trait_id, count(DISTINCT m.accession_id) FROM materialized_phenoview m JOIN stock s ON s.stock_id=m.stock_id
              WHERE m.trial_id IN ($tin) AND m.trait_id IS NOT NULL AND s.type_id IN ($units) GROUP BY 1");
        $entries{ $_->[0] } = $_->[1] for @$rows;
        ($all_entries) = $dbh->selectrow_array(
            "SELECT count(DISTINCT m.accession_id) FROM materialized_phenoview m JOIN stock s ON s.stock_id=m.stock_id
              WHERE m.trial_id IN ($tin) AND m.trait_id IS NOT NULL AND s.type_id IN ($units)");
    }

    # traits of the stored analyses holding the accession (matched by id, or by name without a |suffix)
    my $base = sub { my $n = lc(shift // ''); $n =~ s/\|.*$//; $n =~ s/^\s+|\s+$//g; $n };
    my $analyses = $class->analyses_with_accession($schema, $stock_id);
    my (%in_analysis, %decided);
    if (@$analyses) {
        my $type = _cvterm_id($schema, 'analysis_instance', 'stock_type');
        my $ain = _in_list(map { $_->{analysis_id} } @$analyses);
        my $rows = $dbh->selectall_arrayref(
            "SELECT DISTINCT m.trial_id, m.trait_id, c.name FROM materialized_phenoview m JOIN stock s ON s.stock_id=m.stock_id AND s.type_id=?
               JOIN cvterm c ON c.cvterm_id=m.trait_id WHERE m.trial_id IN ($ain)", undef, $type);
        my %meeting_analyses;
        for my $m (@{ $class->decision_meetings($schema, $stock_id) }) {
            my ($json) = $dbh->selectrow_array(
                "SELECT pp.value FROM projectprop pp WHERE pp.project_id=? AND pp.type_id=? ORDER BY pp.projectprop_id DESC LIMIT 1",
                undef, $m->{meeting_id}, _cvterm_id($schema, 'meeting_json', 'project_property'));
            my $d = eval { decode_json($json // '') };
            next unless ref $d eq 'HASH' && ref $d->{related_analyses} eq 'ARRAY';
            $meeting_analyses{ $_->{analysis_id} } = 1 for grep { ref $_ eq 'HASH' && ($_->{analysis_id} // '') =~ /^\d+$/ } @{ $d->{related_analyses} };
        }
        for my $r (@$rows) {
            my ($aid, $tid, $tname) = @$r;
            for my $key ("id:$tid", 'name:' . $base->($tname)) {
                $in_analysis{$key}{$aid} = 1;
                $decided{$key} = 1 if $meeting_analyses{$aid};
            }
        }
    }
    my $n_analyses = scalar @$analyses;

    my $YIELD = qr/yield|\byld\b|^yld|_yld|production|marketable|kg\/ha|t\/ha|bu\/a|cwt|grain weight|fresh root weight|tuber weight|biomass/i;
    my $HOUSE = qr/plot (length|width|size|area)|\bplot\b|stand count|(^|_)p?stand(_|$)|plant count|number of plants|plants per plot|row|replicate|\bblock\b|planting date|harvest date|sowing date|\bdate\b|notes?\b|comment|emergence count|plant stand|plot_?(id|number)/i;

    my @out;
    for my $t (grep { $_->{numeric} } @$traits) {
        my $text = join(' ', grep { defined } $t->{name}, $t->{definition});
        my $cov = $n_trials ? $t->{trials} / $n_trials : 0;
        my $routine = $all_entries ? ($entries{ $t->{trait_id} } || 0) / $all_entries : 0;
        my %aset = (%{ $in_analysis{"id:$t->{trait_id}"} || {} }, %{ $in_analysis{'name:' . $base->($t->{name})} || {} });
        my $an = $n_analyses ? scalar(keys %aset) / $n_analyses : 0;
        my $dec = ($decided{"id:$t->{trait_id}"} || $decided{'name:' . $base->($t->{name})}) ? 1 : 0;
        my $yield = $text =~ $YIELD ? 1 : 0;
        my $house = ($t->{name} =~ $HOUSE && !$yield) ? 1 : 0;
        my $score = $n_analyses
            ? 0.30 * $cov + 0.15 * $routine + 0.30 * $an + 0.10 * $dec + 0.15 * $yield
            : 0.55 * $cov + 0.30 * $routine + 0.15 * $yield;
        $score *= 0.35 if $house;
        $score *= 0.4 if $t->{trials} < 2;
        my @why;
        push @why, "measured in $t->{trials} of $n_trials trials" if $n_trials;
        push @why, sprintf('recorded on %d%% of the entries of those trials', 100 * $routine + 0.5) if $all_entries;
        push @why, sprintf('in %d of %d stored analyses', scalar(keys %aset), $n_analyses) if $n_analyses && %aset;
        push @why, 'used in a decision meeting' if $dec;
        push @why, 'yield-type trait' if $yield;
        push @why, 'looks like a field-management record' if $house;
        push @out, {
            trait_id => $t->{trait_id}, name => $t->{name}, score => _r($score, 3), coverage => _r($cov, 2), routine => _r($routine, 2),
            analysed => _r($an, 2), decided => $dec, yield => $yield, housekeeping => $house, reasons => \@why,
        };
    }
    return [ sort { $b->{score} <=> $a->{score} || $a->{name} cmp $b->{name} } @out ];
}

=head2 analyses_with_accession($schema, $stock_id)

Stored analyses (e.g. BLUPs/BLUEs) that hold values for the accession.

=cut

sub analyses_with_accession {
    my ($class, $schema, $stock_id) = @_;
    my $type = _cvterm_id($schema, 'analysis_instance', 'stock_type') or return [];
    my $rows = $schema->storage->dbh->selectall_arrayref(
        "SELECT p.project_id, p.name, p.description, count(DISTINCT m.trait_id)
           FROM materialized_phenoview m JOIN stock s ON s.stock_id=m.stock_id AND s.type_id=?
           JOIN project p ON p.project_id=m.trial_id
          WHERE m.accession_id=? AND m.trait_id IS NOT NULL
          GROUP BY 1,2,3 ORDER BY 1 DESC", undef, $type, $stock_id);
    return [ map { { analysis_id => $_->[0] + 0, name => $_->[1], description => $_->[2], traits => $_->[3] + 0 } } @$rows ];
}

=head2 analysis_traits($schema, $analysis_id)

Traits stored in an analysis.

=cut

sub analysis_traits {
    my ($class, $schema, $analysis_id) = @_;
    my $type = _cvterm_id($schema, 'analysis_instance', 'stock_type') or return [];
    my $rows = $schema->storage->dbh->selectall_arrayref(
        "SELECT m.trait_id, c.name, c.definition, count(DISTINCT m.accession_id)
           FROM materialized_phenoview m JOIN stock s ON s.stock_id=m.stock_id AND s.type_id=?
           JOIN cvterm c ON c.cvterm_id=m.trait_id
          WHERE m.trial_id=? GROUP BY 1,2,3 ORDER BY 2", undef, $type, $analysis_id);
    # post-composed traits (trait|statistic): describe them by their base trait
    for my $r (@$rows) {
        my ($base, $stat) = split /\|/, $r->[1], 2;
        next unless $stat;
        my ($def) = $schema->storage->dbh->selectrow_array("SELECT definition FROM cvterm WHERE name=? AND definition IS NOT NULL LIMIT 1", undef, $base);
        $r->[2] = $def if $def;
        push @$r, $base, $stat;
    }
    return [ map { { trait_id => $_->[0] + 0, name => $_->[1], label => _suggest_label($_->[4] // $_->[1], $_->[2]), unit => _suggest_unit($_->[1], $_->[2]), statistic => $_->[5],
                     accessions => $_->[3] + 0, direction => _suggest_direction($_->[1], $_->[2]),
                     kind => _suggest_kind($_->[1], $_->[2]) } } @$rows ];
}

=head2 suggested_checks($schema, $stock_id)

Accessions that shared the most field trials with the accession; accessions
used as controls ('is a control' on their plots) are flagged.

=cut

sub suggested_checks {
    my ($class, $schema, $stock_id, $limit) = @_;
    $limit ||= 15;
    my $dbh = $schema->storage->dbh();
    my $units = _in_list(_field_unit_type_ids($schema));
    my $rows = $dbh->selectall_arrayref(
        "WITH t AS (SELECT DISTINCT trial_id FROM materialized_phenoview WHERE accession_id=? AND trait_id IS NOT NULL)
         SELECT m.accession_id, a.uniquename, count(DISTINCT m.trial_id) AS n
           FROM t JOIN materialized_phenoview m USING(trial_id)
           JOIN stock a ON a.stock_id=m.accession_id
           JOIN stock s ON s.stock_id=m.stock_id AND s.type_id IN ($units)
          WHERE m.accession_id<>? AND m.trait_id IS NOT NULL
          GROUP BY 1,2 ORDER BY 3 DESC LIMIT ?", undef, $stock_id, $stock_id, $limit * 2);
    return [] unless @$rows;

    my %control;
    my $ctl = _cvterm_id($schema, 'is a control', 'stock_property');
    my $plot_of = _cvterm_id($schema, 'plot_of', 'stock_relationship');
    if ($ctl && $plot_of) {
        my $ids = _in_list(map { $_->[0] } @$rows);
        my $c = $dbh->selectall_arrayref(
            "SELECT r.object_id, count(*) FROM stockprop sp JOIN stock_relationship r ON r.subject_id=sp.stock_id AND r.type_id=?
              WHERE sp.type_id=? AND sp.value IN ('1','true','yes') AND r.object_id IN ($ids) GROUP BY 1", undef, $plot_of, $ctl);
        $control{$_->[0]} = $_->[1] for @$c;
    }
    my %relname;
    {
        my $ids = _in_list(map { $_->[0] } @$rows);
        my $rv = $dbh->selectall_arrayref(
            "SELECT sp.stock_id, sp.value FROM stockprop sp JOIN cvterm c ON c.cvterm_id=sp.type_id
              WHERE c.name='released_variety_name' AND sp.stock_id IN ($ids)");
        $relname{$_->[0]} ||= $_->[1] for @$rv;
    }
    my @out = map { { stock_id => $_->[0] + 0, name => $_->[1], shared_trials => $_->[2] + 0,
                      control_plots => ($control{$_->[0]} || 0) + 0, released_variety_name => $relname{$_->[0]} } } @$rows;
    # controls and released varieties first, then by shared trials
    @out = sort { (($b->{control_plots} || $b->{released_variety_name}) ? 1 : 0) <=> (($a->{control_plots} || $a->{released_variety_name}) ? 1 : 0)
                  || $b->{shared_trials} <=> $a->{shared_trials} } @out;
    splice(@out, $limit) if @out > $limit;
    return \@out;
}

=head2 trial_performance($schema, $stock_id, \@check_ids, \@trait_ids, \%opts)

Head-to-head comparison from field trial data. For each trait the accession's
trial means are compared with each check in the trials where both were
measured: means, % of check, wins, paired t-test, and a by-year series.
Values marked as outliers are left out. opts: year_min, year_max.

=cut

sub trial_performance {
    my ($class, $schema, $stock_id, $checks, $traits, $opts) = @_;
    $opts ||= {};
    my $dbh = $schema->storage->dbh();
    my $units = _in_list(_field_unit_type_ids($schema));
    my @acc = ($stock_id, grep { /^\d+$/ && $_ != $stock_id } @$checks);
    my $acc_in = _in_list(@acc);
    my $trait_in = _in_list(@$traits);
    my $outlier = _cvterm_id($schema, 'phenotype_outlier', 'phenotype_property') || 0;
    my @where;
    push @where, "m.year_id >= " . $dbh->quote($opts->{year_min}) if $opts->{year_min} && $opts->{year_min} =~ /^\d{4}$/;
    push @where, "m.year_id <= " . $dbh->quote($opts->{year_max}) if $opts->{year_max} && $opts->{year_max} =~ /^\d{4}$/;
    my $where = @where ? ' AND ' . join(' AND ', @where) : '';

    my $rows = $dbh->selectall_arrayref(
        "SELECT m.trait_id, m.trial_id, m.year_id, m.location_id, m.accession_id, avg(p.value::numeric), count(*)
           FROM materialized_phenoview m
           JOIN stock s ON s.stock_id=m.stock_id AND s.type_id IN ($units)
           JOIN phenotype p ON p.phenotype_id=m.phenotype_id
          WHERE m.accession_id IN ($acc_in) AND m.trait_id IN ($trait_in) AND p.value ~ '$NUM_RE' $where
            AND NOT EXISTS (SELECT 1 FROM phenotypeprop pp WHERE pp.phenotype_id=p.phenotype_id AND pp.type_id=$outlier)
          GROUP BY 1,2,3,4,5");

    # $d{trait}{trial}{accession} = mean
    my (%d, %trial_year, %trial_loc);
    for my $r (@$rows) {
        my ($trait, $trial, $year, $loc, $acc, $mean) = @$r;
        $d{$trait}{$trial}{$acc} = $mean + 0;
        $trial_year{$trial} = $year;
        $trial_loc{$trial} = $loc;
    }

    my %names = %{ $class->public_names($dbh, @acc) };
    my $released = $class->released_names($dbh, @acc);
    my %out;
    for my $trait (@$traits) {
        my $tr = $d{$trait} || {};
        my @vtrials = grep { defined $tr->{$_}{$stock_id} } keys %$tr;
        my @vvals = map { $tr->{$_}{$stock_id} } @vtrials;
        my %t = (
            trait_id => $trait + 0,
            variety => { mean => _mean(\@vvals), trials => scalar(@vtrials), min => (@vvals ? min(@vvals) : undef), max => (@vvals ? max(@vvals) : undef),
                         locations => scalar(keys %{{ map { ($trial_loc{$_} || 0) => 1 } @vtrials }}) },
            checks => [],
        );
        # by year for the variety alone
        my %vy;
        push @{ $vy{$trial_year{$_}} }, $tr->{$_}{$stock_id} for @vtrials;
        $t{variety}{by_year} = { map { $_ => _r(_mean($vy{$_})) } keys %vy };

        for my $check (@acc[1..$#acc]) {
            my @shared = sort grep { defined $tr->{$_}{$check} } @vtrials;
            my @v = map { $tr->{$_}{$stock_id} } @shared;
            my @c = map { $tr->{$_}{$check} } @shared;
            my @diff = map { $v[$_] - $c[$_] } 0 .. $#v;
            my $wins = 0;
            for my $i (0 .. $#v) {
                $wins++ if (($opts->{direction}{$trait} || 'higher') eq 'lower') ? $v[$i] < $c[$i] : $v[$i] > $c[$i];
            }
            my ($vm, $cm) = (_mean(\@v), _mean(\@c));
            my %by_year;
            for my $i (0 .. $#shared) {
                my $y = $trial_year{$shared[$i]};
                push @{ $by_year{$y}{v} }, $v[$i];
                push @{ $by_year{$y}{c} }, $c[$i];
            }
            push @{ $t{checks} }, {
                stock_id => $check + 0, name => $names{$check}, released => $released->{$check} ? 1 : 0,
                shared_trials => scalar(@shared),
                shared_locations => scalar(keys %{{ map { ($trial_loc{$_} || 0) => 1 } @shared }}),
                variety_mean => _r($vm), check_mean => _r($cm),
                difference => (defined $vm && defined $cm) ? _r($vm - $cm) : undef,
                pct_of_check => ($cm && defined $vm) ? _r(100 * $vm / $cm, 1) : undef,
                wins => $wins,
                p_value => _paired_t_p(\@diff),
                by_year => [ map { { year => $_, n => scalar(@{$by_year{$_}{v}}), variety => _r(_mean($by_year{$_}{v})), check => _r(_mean($by_year{$_}{c})) } } sort keys %by_year ],
            };
        }
        $t{variety}{mean} = _r($t{variety}{mean});
        $t{variety}{min} = _r($t{variety}{min});
        $t{variety}{max} = _r($t{variety}{max});
        $out{$trait} = \%t;
    }
    return { source => 'trials', traits => [ map { $out{$_} } @$traits ] };
}

=head2 analysis_performance($schema, $analysis_id, $stock_id, \@check_ids, \@trait_ids, \%opts)

Values from a stored analysis: the accession's value, its rank among all
entries, the mean of all entries and the value of each check.

=cut

sub analysis_performance {
    my ($class, $schema, $analysis_id, $stock_id, $checks, $traits, $opts) = @_;
    $opts ||= {};
    my $dbh = $schema->storage->dbh();
    my $type = _cvterm_id($schema, 'analysis_instance', 'stock_type') or return { error => 'No analysis_instance type' };
    my $trait_in = _in_list(@$traits);
    my $rows = $dbh->selectall_arrayref(
        "SELECT m.trait_id, m.accession_id, a.uniquename, avg(p.value::numeric)
           FROM materialized_phenoview m
           JOIN stock s ON s.stock_id=m.stock_id AND s.type_id=?
           JOIN stock a ON a.stock_id=m.accession_id
           JOIN phenotype p ON p.phenotype_id=m.phenotype_id
          WHERE m.trial_id=? AND m.trait_id IN ($trait_in) AND p.value ~ '$NUM_RE'
          GROUP BY 1,2,3", undef, $type, $analysis_id);
    my (%v, %names);
    for my $r (@$rows) {
        $v{$r->[0]}{$r->[1]} = $r->[3] + 0;
        $names{$r->[1]} = $r->[2];
    }
    my ($aname) = $dbh->selectrow_array("SELECT name FROM project WHERE project_id=?", undef, $analysis_id);
    %names = (%names, %{ $class->public_names($dbh, @$checks) });
    my $released = $class->released_names($dbh, @$checks);
    my @out;
    for my $trait (@$traits) {
        my $vals = $v{$trait} || {};
        my $lower = ($opts->{direction}{$trait} || 'higher') eq 'lower';
        my @sorted = sort { $lower ? $vals->{$a} <=> $vals->{$b} : $vals->{$b} <=> $vals->{$a} } keys %$vals;
        my %rank; @rank{@sorted} = (1 .. @sorted);
        my $vm = $vals->{$stock_id};
        my $all = _mean([ values %$vals ]);
        push @out, {
            trait_id => $trait + 0,
            variety => { mean => _r($vm), rank => $rank{$stock_id}, entries => scalar(@sorted),
                         top_pct => ($rank{$stock_id} && @sorted) ? _r(100 * $rank{$stock_id} / @sorted, 0) : undef },
            all_mean => _r($all),
            pct_of_mean => ($all && defined $vm) ? _r(100 * $vm / $all, 1) : undef,
            checks => [ map { my $cm = $vals->{$_};
                              { stock_id => $_ + 0, name => $names{$_}, released => $released->{$_} ? 1 : 0, check_mean => _r($cm), variety_mean => _r($vm), rank => $rank{$_},
                                difference => (defined $vm && defined $cm) ? _r($vm - $cm) : undef,
                                pct_of_check => ($cm && defined $vm) ? _r(100 * $vm / $cm, 1) : undef } }
                        grep { /^\d+$/ && $_ != $stock_id } @$checks ],
        };
    }
    return { source => 'analysis', analysis_id => $analysis_id + 0, analysis_name => $aname, traits => \@out };
}

# ---- profile storage ----

sub _decode_row {
    my $r = shift;
    return $NONE unless $r;
    # DBD::Pg may return the jsonb as characters (pg_enable_utf8) or as UTF-8 bytes
    my $sheet = eval { utf8::is_utf8($r->{sheet}) ? JSON::XS->new->decode($r->{sheet}) : decode_json($r->{sheet}) } || {};
    return { %$r, sheet => $sheet };
}

my $SHEET_COLS = "v.variety_sheet_id, v.stock_id, s.uniquename AS accession_name, v.sp_person_id, v.commercial_name, v.status,
    v.sheet, to_char(v.create_date, 'YYYY-MM-DD HH24:MI') AS create_date, to_char(v.modified_date, 'YYYY-MM-DD HH24:MI') AS modified_date,
    coalesce(nullif(trim(coalesce(pe.first_name,'') || ' ' || coalesce(pe.last_name,'')), ''), pe.username) AS owner";
my $SHEET_FROM = "phenome.variety_sheet v JOIN stock s ON s.stock_id=v.stock_id LEFT JOIN sgn_people.sp_person pe ON pe.sp_person_id=v.sp_person_id";

sub get_sheet {
    my ($class, $schema, $sheet_id) = @_;
    my $r = $schema->storage->dbh->selectrow_hashref("SELECT $SHEET_COLS FROM $SHEET_FROM WHERE v.variety_sheet_id=?", undef, $sheet_id);
    return _decode_row($r);
}

# For viewers who cannot edit: drop the pedigree / decision history when the
# owner chose to hide them, so they are not sent in the page or the JSON either.
sub strip_hidden {
    my ($class, $row) = @_;
    my $s = $row && $row->{sheet};
    return $row unless ref $s eq 'HASH' && ref $s->{options} eq 'HASH';
    # the pedigree data holds the parents' accession names; the sheet shows only the pedigree text
    delete $s->{pedigree};
    if (exists $s->{options}{show_pedigree} && !$s->{options}{show_pedigree}) {
        $s->{text}{pedigree} = '' if ref $s->{text} eq 'HASH';
    }
    delete $s->{decisions} if exists $s->{options}{show_decisions} && !$s->{options}{show_decisions};
    # the experimental name is confidential: only editors get it
    delete @{$s}{qw(accession_name former_names)};
    delete $row->{accession_name};
    return $row;
}

=head2 refresh_check_names($schema, $row)

Puts the current public name (released variety name, else accession name) on
every check of a saved profile, so a check released after the profile was
saved, or a profile saved before checks were named this way, never shows the
check's experimental name.

=cut

sub refresh_check_names {
    my ($class, $schema, $row) = @_;
    my $s = $row && $row->{sheet};
    return $row unless ref $s eq 'HASH';
    my @lists;
    my $perf = ref $s->{performance} eq 'HASH' ? $s->{performance} : {};
    push @lists, $perf->{checks} if ref $perf->{checks} eq 'ARRAY';
    for my $res ($perf->{results}, (ref $s->{ratings} eq 'HASH' ? $s->{ratings}{results} : undef)) {
        next unless ref $res eq 'HASH' && ref $res->{traits} eq 'ARRAY';
        push @lists, map { $_->{checks} } grep { ref $_ eq 'HASH' && ref $_->{checks} eq 'ARRAY' } @{ $res->{traits} };
    }
    my @items = grep { ref $_ eq 'HASH' && ($_->{stock_id} // '') =~ /^\d+$/ } map { @$_ } @lists;
    return $row unless @items;
    my @ids = map { $_->{stock_id} } @items;
    my $names = $class->public_names($schema->storage->dbh(), @ids);
    my $released = $class->released_names($schema->storage->dbh(), @ids);
    for (@items) {
        $_->{name} = $names->{ $_->{stock_id} } if defined $names->{ $_->{stock_id} };
        $_->{released} = $released->{ $_->{stock_id} } ? 1 : 0;
    }
    return $row;
}

sub list_sheets {
    my ($class, $schema, $f) = @_;
    $f ||= {};
    my (@w, @b);
    if ($f->{stock_id}) { push @w, 'v.stock_id=?'; push @b, $f->{stock_id}; }
    if ($f->{published}) { push @w, "v.status='published'"; }
    if ($f->{visible_to}) { push @w, "(v.status='published' OR v.sp_person_id=?)"; push @b, $f->{visible_to}; }
    if (defined $f->{owner}) { push @w, 'v.sp_person_id=?'; push @b, $f->{owner}; }
    my $where = @w ? 'WHERE ' . join(' AND ', @w) : '';
    my $rows = $schema->storage->dbh->selectall_arrayref(
        "SELECT v.variety_sheet_id, v.stock_id, s.uniquename AS accession_name, v.commercial_name, v.status, v.sp_person_id,
                to_char(v.modified_date, 'YYYY-MM-DD') AS modified_date,
                coalesce(nullif(trim(coalesce(pe.first_name,'') || ' ' || coalesce(pe.last_name,'')), ''), pe.username) AS owner
           FROM $SHEET_FROM $where ORDER BY v.modified_date DESC", { Slice => {} }, @b);
    return $rows;
}

sub save_sheet {
    my ($class, $schema, $args) = @_;
    my $dbh = $schema->storage->dbh();
    # ASCII JSON: safe whatever the connection's UTF-8 setting (jsonb decodes the escapes)
    my $json = JSON::XS->new->ascii->canonical->encode($args->{sheet});
    if ($args->{sheet_id}) {
        $dbh->do("UPDATE phenome.variety_sheet SET sheet=?, commercial_name=?, status=?, modified_date=now() WHERE variety_sheet_id=?",
                 undef, $json, $args->{commercial_name}, $args->{status}, $args->{sheet_id});
        return $args->{sheet_id};
    }
    my ($id) = $dbh->selectrow_array(
        "INSERT INTO phenome.variety_sheet (stock_id, sp_person_id, commercial_name, status, sheet) VALUES (?,?,?,?,?) RETURNING variety_sheet_id",
        undef, $args->{stock_id}, $args->{sp_person_id}, $args->{commercial_name}, $args->{status}, $json);
    return $id;
}

sub delete_sheet {
    my ($class, $schema, $sheet_id) = @_;
    return $schema->storage->dbh->do("DELETE FROM phenome.variety_sheet WHERE variety_sheet_id=?", undef, $sheet_id);
}

=head2 check_name($schema, $name, $stock_id)

Is a commercial name free? Returns exact matches (another stock's name,
synonym or released variety name) and whether the accession already has it.

=cut

sub check_name {
    my ($class, $schema, $name, $stock_id) = @_;
    my $dbh = $schema->storage->dbh();
    $name =~ s/^\s+|\s+$//g;
    my $rows = $dbh->selectall_arrayref(
        "SELECT s.stock_id, s.uniquename, 'name' FROM stock s WHERE lower(s.uniquename)=lower(?) AND s.is_obsolete='f'
         UNION
         SELECT s.stock_id, s.uniquename, c.name FROM stockprop sp JOIN cvterm c ON c.cvterm_id=sp.type_id JOIN stock s ON s.stock_id=sp.stock_id
          WHERE c.name IN ('stock_synonym','released_variety_name') AND lower(sp.value)=lower(?) AND s.is_obsolete='f'",
        undef, $name, $name);
    my (@conflicts, %own);
    for my $r (@$rows) {
        if ($r->[0] == $stock_id) { $own{$r->[2]} = 1; next; }
        my ($c) = grep { $_->{stock_id} == $r->[0] } @conflicts;
        my $as = $r->[2] eq 'stock_synonym' ? 'synonym' : $r->[2] eq 'released_variety_name' ? 'released variety name' : 'accession name';
        if ($c) { $c->{as} .= " and $as"; } else { push @conflicts, { stock_id => $r->[0] + 0, name => $r->[1], as => $as }; }
    }
    return { name => $name, conflicts => \@conflicts, already_name => $own{name} ? 1 : 0,
             already_synonym => $own{stock_synonym} ? 1 : 0, already_released_name => $own{released_variety_name} ? 1 : 0 };
}

# ---- stats helpers ----

sub _mean { my $a = shift; return $NONE unless $a && @$a; return sum(@$a) / @$a; }

sub _r {
    my ($x, $d) = @_;
    return $NONE unless defined $x;
    $d = 2 unless defined $d;
    return 0 + sprintf("%.${d}f", $x);
}

# two-sided p value of the paired t test on the differences
sub _paired_t_p {
    my $d = shift;
    my $n = @$d;
    return $NONE if $n < 3;
    my $m = _mean($d);
    my $ss = sum(map { ($_ - $m) ** 2 } @$d);
    my $sd = sqrt($ss / ($n - 1));
    return ($m == 0 ? 1 : 0) if $sd == 0;
    my $t = $m / ($sd / sqrt($n));
    my $df = $n - 1;
    my $p = _betai($df / 2, 0.5, $df / ($df + $t * $t));
    return 0 + sprintf('%.4g', $p);
}

# regularized incomplete beta I_x(a,b) (Numerical Recipes)
sub _betai {
    my ($a, $b, $x) = @_;
    return 0 if $x <= 0;
    return 1 if $x >= 1;
    my $bt = exp(_lgamma($a + $b) - _lgamma($a) - _lgamma($b) + $a * log($x) + $b * log(1 - $x));
    return $x < ($a + 1) / ($a + $b + 2) ? $bt * _betacf($a, $b, $x) / $a : 1 - $bt * _betacf($b, $a, 1 - $x) / $b;
}

sub _betacf {
    my ($a, $b, $x) = @_;
    my ($qab, $qap, $qam) = ($a + $b, $a + 1, $a - 1);
    my ($c, $d) = (1, 1 - $qab * $x / $qap);
    $d = 1e-30 if abs($d) < 1e-30;
    $d = 1 / $d;
    my $h = $d;
    for my $m (1 .. 200) {
        my $m2 = 2 * $m;
        my $aa = $m * ($b - $m) * $x / (($qam + $m2) * ($a + $m2));
        $d = 1 + $aa * $d; $d = 1e-30 if abs($d) < 1e-30;
        $c = 1 + $aa / $c; $c = 1e-30 if abs($c) < 1e-30;
        $d = 1 / $d; $h *= $d * $c;
        $aa = -($a + $m) * ($qab + $m) * $x / (($a + $m2) * ($qap + $m2));
        $d = 1 + $aa * $d; $d = 1e-30 if abs($d) < 1e-30;
        $c = 1 + $aa / $c; $c = 1e-30 if abs($c) < 1e-30;
        $d = 1 / $d;
        my $del = $d * $c;
        $h *= $del;
        last if abs($del - 1) < 3e-12;
    }
    return $h;
}

sub _lgamma {
    my $x = shift;
    my @c = (76.18009172947146, -86.50532032941677, 24.01409824083091, -1.231739572450155, 0.1208650973866179e-2, -0.5395239384953e-5);
    my ($yy, $tmp) = ($x, $x + 5.5);
    $tmp -= ($x + 0.5) * log($tmp);
    my $series = 1.000000000190015;
    $series += $c[$_] / ++$yy for 0 .. 5;
    return -$tmp + log(2.5066282746310005 * $series / $x);
}

1;
