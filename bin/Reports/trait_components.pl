#!/usr/bin/env perl

=head1 NAME

trait_components.pl - Split composed traits

=head1 SYNOPSIS

    trait_components.pl -U [dbuser] -P [dbpass] -H [dbhost] -D [dbname] -o [dir] -f [name]
        -t trial_ids_file [-a accession_ids_file] [-T trait_ids_file]

=head1 COMMAND-LINE OPTIONS

 -U  db username (postgres)
 -P  db password
 -H  host name
 -D  database name
 -o  output directory
 -f  output filename (without extension)
 -t  file with trial ids, one per line (required)
 -a  file with accession ids, one per line
 -T  file with trait ids, one per line; a composed trait is kept when it or
     one of its components is in the list (e.g. "Brix" keeps every Brix combination)

=head1 DESCRIPTION

Phenotypes with each composed trait split into trait, attribute and time columns.

The base trait becomes a value column and each other component (attribute,
time, ...) gets its own column, ready to use as factors in a model or as
filters in a dashboard.

For a trait such as "Brix|Plant Cane|Early Season" the row gets attribute =
Plant Cane, time = Early Season and the value goes in the Brix column (see
GitHub issue solgenomics/sgn#6331).

Components are read from the ontology (the "contains" relationships of the
composed trait, and the category of each component's ontology: trait,
attribute, time, ...). Traits without those relationships are split on "|"
and each part is looked up by name. Traits that are not composed keep empty
component columns.

Writes <name>.xlsx with three sheets (By trait: one column per base trait;
Long: one row per observation; Trait map: how each trait was split), one csv
per sheet, and <name>.results.json for the Report Factory page.

=head1 AUTHOR

Chris Simoes <ccs263@cornell.edu>

=cut

use strict;
use warnings;
use Getopt::Std;
use DBI;
use CXGN::Report::Output;

our %opt;
getopts('H:D:U:P:o:f:t:a:T:', \%opt);

my $dbhost = $opt{H} // 'localhost';
my $dbname = $opt{D} // 'breedbase';
my $dbuser = $opt{U} // 'postgres';
my $dbpass = $opt{P} // '';
my $out_directory = $opt{o} // '';
my $filename = $opt{f} // 'trait_components';
my @list_trial_ids = CXGN::Report::Output::read_ids($opt{t});
my %accession_filter = map { $_ => 1 } CXGN::Report::Output::read_ids($opt{a});
my %trait_filter = map { $_ => 1 } CXGN::Report::Output::read_ids($opt{T});
die "Give a file of trial ids (-t).\n" if !$opt{t};

my $dbh = DBI->connect("dbi:Pg:dbname=$dbname;host=$dbhost", $dbuser, $dbpass, { AutoCommit => 0, RaiseError => 1 });

sub cvterm_id {
    my ($name, $cv) = @_;
    my ($id) = $dbh->selectrow_array('SELECT cvterm_id FROM cvterm JOIN cv USING(cv_id) WHERE cvterm.name = ? AND cv.name = ? LIMIT 1', undef, $name, $cv);
    return $id;
}

# ---------------------------------------------------------------- trials
my @where = ('p.project_id = ANY(?)');
my @bind = ([ @list_trial_ids ? @list_trial_ids : (-1) ]);
my $year_type = cvterm_id('project year', 'project_property');
my $location_type = cvterm_id('project location', 'project_property');
my $trials = $dbh->selectall_arrayref(
    "SELECT p.project_id, p.name, y.value, g.description
     FROM project p
     LEFT JOIN projectprop y ON (y.project_id = p.project_id AND y.type_id = ?)
     LEFT JOIN projectprop l ON (l.project_id = p.project_id AND l.type_id = ?)
     LEFT JOIN nd_geolocation g ON (l.value ~ '^[0-9]+\$' AND g.nd_geolocation_id = l.value::int)
     WHERE " . join(' AND ', @where) . " ORDER BY p.name",
    undef, $year_type // -1, $location_type // -1, @bind);
my %trial = map { $_->[0] => { name => $_->[1], year => $_->[2] // '', location => $_->[3] // '' } } @$trials;
my @trial_ids = keys %trial;
print STDERR scalar(@trial_ids) . " trials\n";

# ---------------------------------------------------------------- observations
my $rep_type = cvterm_id('replicate', 'stock_property');
my $block_type = cvterm_id('block', 'stock_property');
my @obs;
if (@trial_ids) {
    my $sth = $dbh->prepare(
        "SELECT ep.project_id, unit.stock_id, unit.uniquename, ut.name, acc.stock_id, acc.uniquename, rep.value, blk.value, ph.cvalue_id, ph.value
         FROM nd_experiment_project ep
         JOIN nd_experiment_phenotype nep ON (nep.nd_experiment_id = ep.nd_experiment_id)
         JOIN phenotype ph ON (ph.phenotype_id = nep.phenotype_id)
         JOIN nd_experiment_stock nes ON (nes.nd_experiment_id = ep.nd_experiment_id)
         JOIN stock unit ON (unit.stock_id = nes.stock_id)
         JOIN cvterm ut ON (ut.cvterm_id = unit.type_id)
         LEFT JOIN LATERAL (
             SELECT a.stock_id, a.uniquename
             FROM stock_relationship r
             JOIN stock a ON (a.stock_id = r.object_id)
             JOIN cvterm at ON (at.cvterm_id = a.type_id AND at.name = 'accession')
             WHERE r.subject_id = unit.stock_id
             LIMIT 1
         ) acc ON (TRUE)
         LEFT JOIN stockprop rep ON (rep.stock_id = unit.stock_id AND rep.type_id = ?)
         LEFT JOIN stockprop blk ON (blk.stock_id = unit.stock_id AND blk.type_id = ?)
         WHERE ep.project_id = ANY(?)
         ORDER BY ep.project_id, unit.uniquename, ph.phenotype_id");
    $sth->execute($rep_type // -1, $block_type // -1, \@trial_ids);
    while (my @r = $sth->fetchrow_array) {
        my ($pid, $unit_id, $unit, $level, $acc_id, $acc) = @r;
        # values stored directly on accessions (e.g. analyses)
        ($acc_id, $acc) = ($unit_id, $unit) if !defined($acc_id) && $level eq 'accession';
        next if %accession_filter && !(defined($acc_id) && $accession_filter{$acc_id});
        push @obs, \@r;
    }
}
print STDERR scalar(@obs) . " observations\n";

# ---------------------------------------------------------------- components of each trait
# category of an ontology: its cvprop "<category>_ontology" (trait_ontology, attribute_ontology, time_ontology, ...)
my %cv_category;
my $cv_sth = $dbh->prepare("SELECT cvprop.cv_id, t.name FROM cvprop JOIN cvterm t ON (t.cvterm_id = cvprop.type_id) WHERE t.name LIKE '%\\_ontology'");
$cv_sth->execute();
while (my ($cv_id, $type) = $cv_sth->fetchrow_array) {
    next if $type =~ /^composed_/;
    (my $cat = $type) =~ s/_ontology$//;
    $cv_category{$cv_id} //= $cat;
}

my %used_trait_ids = map { $_->[8] => 1 } @obs;
my $contains = cvterm_id('contains', 'relationship');
my %trait_info;    # cvterm_id => { name, base, parts => { category => value }, source, component_ids }
my $name_sth = $dbh->prepare('SELECT cvterm_id, name, cv_id FROM cvterm WHERE cvterm_id = ANY(?)');
$name_sth->execute([ keys %used_trait_ids ]);
my %names;
while (my ($id, $name, $cv_id) = $name_sth->fetchrow_array) { $names{$id} = $name; }

my $comp_sth = $dbh->prepare(
    'SELECT r.object_id, c.cvterm_id, c.name, c.cv_id FROM cvterm_relationship r JOIN cvterm c ON (c.cvterm_id = r.subject_id)
     WHERE r.type_id = ? AND r.object_id = ANY(?) ORDER BY r.object_id, r.cvterm_relationship_id');
$comp_sth->execute($contains // -1, [ keys %used_trait_ids ]);
my %components;
while (my ($tid, $cid, $cname, $cv_id) = $comp_sth->fetchrow_array) {
    push @{ $components{$tid} }, { id => $cid, name => $cname, category => category_name($cv_category{$cv_id}) };
}

my $lookup_sth = $dbh->prepare(
    "SELECT c.cvterm_id, c.cv_id FROM cvterm c JOIN cv USING(cv_id) WHERE c.name = ? AND cv.name NOT LIKE 'composed%' AND c.is_obsolete = 0 ORDER BY c.cvterm_id");

sub category_name {
    my $cat = shift;
    return 'component' if !defined($cat);
    return 'time' if $cat eq 'time';
    return $cat;
}

my %category_seen;
foreach my $tid (keys %used_trait_ids) {
    my $name = $names{$tid} // "trait $tid";
    my @comps = @{ $components{$tid} || [] };
    my $source = 'ontology';
    if (@comps) {
        # composed term linked to components; order the parts as in the name
        my %pos;
        my @pieces = split /\|/, $name;
        for my $i (0 .. $#pieces) { $pos{ $pieces[$i] =~ s/^\s+|\s+$//gr } //= $i; }
        @comps = sort { ($pos{ $a->{name} } // 99) <=> ($pos{ $b->{name} } // 99) } @comps;
    }
    elsif ($name =~ /\|/) {
        $source = 'name';
        foreach my $piece (map { s/^\s+|\s+$//gr } split /\|/, $name) {
            next if $piece eq '';
            $lookup_sth->execute($piece);
            my ($cid, $cv_id) = $lookup_sth->fetchrow_array;
            $lookup_sth->finish();
            push @comps, { id => $cid, name => $piece, category => category_name(defined($cv_id) ? $cv_category{$cv_id} : undef) };
        }
        # the first part of a composed name is the trait when nothing else says so
        $comps[0]->{category} = 'trait' if @comps && !grep { $_->{category} eq 'trait' } @comps;
    }
    else {
        $source = 'not composed';
        @comps = ({ id => $tid, name => $name, category => 'trait' });
    }
    my @base = map { $_->{name} } grep { $_->{category} eq 'trait' } @comps;
    @base = ($name) if !@base;
    my %parts;
    foreach my $c (grep { $_->{category} ne 'trait' } @comps) {
        $parts{ $c->{category} } = defined($parts{ $c->{category} }) ? "$parts{ $c->{category} }; $c->{name}" : $c->{name};
        $category_seen{ $c->{category} }++;
    }
    $trait_info{$tid} = {
        name => $name,
        base => join(' | ', @base),
        parts => \%parts,
        source => $source,
        component_ids => [ grep { defined } map { $_->{id} } @comps ],
    };
}

# trait list: the trait itself or one of its components
if (%trait_filter) {
    @obs = grep {
        my $ti = $trait_info{ $_->[8] };
        $trait_filter{ $_->[8] } || grep { $trait_filter{$_} } @{ $ti->{component_ids} };
    } @obs;
}

# component columns: usual categories first
my %order = (attribute => 1, time => 2, toy => 3, tod => 4, evt => 5, meta => 6, gen => 7, component => 99);
my @categories = sort { ($order{$a} // 50) <=> ($order{$b} // 50) || $a cmp $b } keys %category_seen;
my @unit_columns = qw( study_name study_year location_name observationunit_name observationunit_level accession_name replicate block_number );

# ---------------------------------------------------------------- tables
my (%base_count, %cat_count, %units, %used_traits, %trials_with_obs);
my @long;
my %wide;    # key => { row => [...], values => { base => [values] } }
my @wide_keys;
foreach my $o (@obs) {
    my ($pid, $unit_id, $unit, $level, $acc_id, $acc, $rep, $block, $tid, $value) = @$o;
    my $ti = $trait_info{$tid};
    my $t = $trial{$pid};
    $acc //= ($level eq 'accession' ? $unit : '');
    my @unit_values = ($t->{name}, $t->{year}, $t->{location}, $unit, $level, $acc, $rep // '', $block // '');
    my @cat_values = map { $ti->{parts}->{$_} // '' } @categories;
    push @long, [ @unit_values, @cat_values, $ti->{base}, $value, $ti->{name} ];
    $base_count{ $ti->{base} }++;
    $units{$unit_id} = 1;
    $trials_with_obs{$pid} = 1;
    $used_traits{$tid} = 1;
    for my $i (0 .. $#categories) { $cat_count{ $categories[$i] }->{ $cat_values[$i] || '(none)' }++; }

    my $key = join("\t", $pid, $unit_id, @cat_values);
    if (!$wide{$key}) {
        $wide{$key} = { row => [ @unit_values, @cat_values ], values => {} };
        push @wide_keys, $key;
    }
    push @{ $wide{$key}->{values}->{ $ti->{base} } }, $value;
}

my @bases = sort { lc($a) cmp lc($b) } keys %base_count;
my @wide_rows;
foreach my $key (@wide_keys) {
    my $w = $wide{$key};
    # repeated values of the same trait and components: one row each
    my $n = 1;
    foreach my $b (@bases) { my $k = scalar(@{ $w->{values}->{$b} || [] }); $n = $k if $k > $n; }
    for my $i (0 .. $n - 1) {
        push @wide_rows, [ @{ $w->{row} }, map { $w->{values}->{$_} ? ($w->{values}->{$_}->[$i] // '') : '' } @bases ];
    }
}

my @map_rows = map {
    my $ti = $trait_info{$_};
    [ $ti->{name}, $ti->{base}, (map { $ti->{parts}->{$_} // '' } @categories), $ti->{source} ]
} sort { lc($trait_info{$a}->{name}) cmp lc($trait_info{$b}->{name}) } keys %used_traits;

# ---------------------------------------------------------------- output
my $out = CXGN::Report::Output->new({ directory => $out_directory, basename => $filename, title => 'Composed traits split into components' });
$out->add_summary('Trials', scalar(keys %trials_with_obs) . ' / ' . scalar(@trial_ids), 'with phenotypes / selected');
$out->add_summary('Observation units', scalar(keys %units));
$out->add_summary('Observations', scalar(@long));
$out->add_summary('Traits', scalar(keys %used_traits), scalar(@bases) . ' base trait' . (@bases == 1 ? '' : 's'));
$out->add_summary('Component columns', scalar(@categories) ? join(', ', @categories) : 'none');

my @top_bases = grep { defined } (sort { $base_count{$b} <=> $base_count{$a} || $a cmp $b } @bases)[0 .. 14];
$out->add_chart({ title => 'Observations by base trait' . (@bases > 15 ? ' (top 15)' : ''), labels => \@top_bases, values => [ map { $base_count{$_} } @top_bases ] }) if @top_bases;
foreach my $cat (@categories) {
    my $h = $cat_count{$cat};
    my @labels = grep { defined } (sort { $h->{$b} <=> $h->{$a} || $a cmp $b } keys %$h)[0 .. 14];
    $out->add_chart({ title => "Observations by $cat" . (keys(%$h) > 15 ? ' (top 15)' : ''), labels => \@labels, values => [ map { $h->{$_} } @labels ] });
}

my $by_name = grep { $trait_info{$_}->{source} eq 'name' } keys %used_traits;
$out->add_note("$by_name trait(s) have no component links in the ontology; they were split on \"|\" and each part was looked up by name (see the Trait map sheet).") if $by_name;
my $unknown = grep { exists $trait_info{$_}->{parts}->{component} } keys %used_traits;
$out->add_note("$unknown trait(s) have parts whose ontology category is unknown; those parts are in the \"component\" column.") if $unknown;
$out->add_note('No trial matched the inputs.') if !@trial_ids;
$out->add_note('The chosen trials have no phenotypes for the chosen accessions and traits.') if @trial_ids && !@long;

$out->add_table({ name => 'By trait', description => 'One row per observation unit and combination of components, one column per base trait.', columns => [ @unit_columns, @categories, @bases ], rows => \@wide_rows });
$out->add_table({ name => 'Long', description => 'One row per observation.', columns => [ @unit_columns, @categories, 'trait', 'value', 'original_trait_name' ], rows => \@long });
$out->add_table({ name => 'Trait map', description => 'How each trait was split.', columns => [ 'original_trait_name', 'trait', @categories, 'source' ], rows => \@map_rows });
my $files = $out->write();
print STDERR "Files written: @$files\n";

$dbh->disconnect();
exit(0);
