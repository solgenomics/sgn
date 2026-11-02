package CXGN::Pedigree::Parentage;

use strict;
use warnings;
use SGN::Model::Cvterm;

=head1 NAME

CXGN::Pedigree::Parentage - shared parent identity, write and cycle rules

=head1 DESCRIPTION

Uses the standard stock relationships. Writers acquire the transaction-scoped
pedigree advisory lock before reading or locking stocks. This serializes cycle
validation with writes without a schema change. SQL/admin writers outside this
protocol remain responsible for maintaining graph integrity.

=cut

=head2 lock($schema)

Acquire the common pedigree graph lock in a DBIx::Class transaction. The
application uses READ COMMITTED, so validation after waiting sees the preceding
writer's commit. A different isolation level must not silently use an old graph
snapshot. Locks are released by PostgreSQL on commit or rollback.

=cut

sub lock {
    my ($class, $schema) = @_;
    die "Parentage writes require a transaction.\n" unless $schema->storage->transaction_depth;
    # Two-key PostgreSQL advisory namespace: ASCII PEDI, protocol version 1.
    my (undef, $isolation) = $schema->storage->dbh->selectrow_array(
        q{SELECT pg_advisory_xact_lock(1346716745, 1), current_setting('transaction_isolation')});
    die "Parentage writes require READ COMMITTED isolation.\n" unless $isolation eq 'read committed';
}

=head2 vocabulary($schema)

Load the small relevant vocabulary once per operation, without process-global
caches that could mix databases or retain changed term IDs.

=cut

sub vocabulary {
    my ($class, $schema) = @_;
    my @relationships = qw(female_parent male_parent scion_of rootstock_of);
    my @stocks = qw(accession cross population vector_construct);
    my $rs = $schema->resultset('Cv::Cvterm')->search({
        'me.is_obsolete' => 0,
        -or => [
            {'cv.name' => 'stock_relationship', 'me.name' => {-in => \@relationships}},
            {'cv.name' => 'stock_type', 'me.name' => {-in => \@stocks}},
            {'cv.name' => 'stock_property', 'me.name' => 'stock_synonym'},
        ],
    }, {prefetch => 'cv'});
    my %v;
    while (my $term = $rs->next) {
        my ($cv, $name) = ($term->cv->name, $term->name);
        die "Ambiguous vocabulary term $cv/$name.\n" if exists $v{$cv}{$name};
        $v{$cv}{$name} = $term->cvterm_id;
    }
    die "Female and male parent terms are required.\n"
        unless $v{stock_relationship}{female_parent} && $v{stock_relationship}{male_parent};
    $v{roles} = {female => $v{stock_relationship}{female_parent}, male => $v{stock_relationship}{male_parent}};
    $v{stock_names} = {reverse %{$v{stock_type} || {}}};
    return \%v;
}

=head2 supported_cross_types()

Types for a single accession pedigree. Compound crossing generators retain
separate standard workflows.

=cut

sub supported_cross_types {
    return qw(biparental open self sib polycross backcross reselected doubled_haploid dihaploid_induction);
}

=head2 normalize_type($value)

Normalize empty and legacy literal null values without inferring a type.

=cut

sub normalize_type {
    my ($class, $value) = @_;
    return defined($value) && $value ne '' && $value ne 'null' ? $value : undef;
}

=head2 overwrite_flag($value)

Normalize explicit upload booleans for model and HTTP callers. Missing means
no overwrite; arbitrary truthy strings never authorize replacement.

=cut

sub overwrite_flag {
    my ($class, $value) = @_;
    return 0 unless defined($value);
    my $text = "$value";
    return 1 if $text =~ /^(?:1|true|on|yes)$/i;
    return 0 if $text =~ /^(?:0|false|off|no)?$/i;
    die "Overwrite must be true or false.\n";
}

=head2 error_message($exception)

Keep validation messages useful while avoiding SQL/bind details in user errors.
DBIx::Class wraps application validation errors with an UNKNOWN/source wrapper.

=cut

sub error_message {
    my ($class, $error) = @_;
    my $text = "$error";
    return 'An error occurred while saving the parents. No parents were changed.'
        if $text =~ /DBI Exception|DBD::|SQLSTATE/;
    $text =~ s/\A.*?\{UNKNOWN\}:\s*//s;
    $text =~ s/\s+at\s+\/[^\n]+?\s+line\s+\d+.*\z//s;
    $text =~ s/\s+\z//;
    return $text;
}

=head2 resolve_names($schema, $names, $vocabulary)

Resolve only requested canonical names and synonyms in one bounded SQL query.
Return every candidate, deduplicated by stock ID, so ambiguity is never resolved
by row order or a last-wins hash assignment.

=cut

sub resolve_names {
    my ($class, $schema, $names, $v) = @_;
    $v ||= $class->vocabulary($schema);
    my %seen;
    my @names = grep {defined($_) && !ref($_) && length($_) && !$seen{$_}++} @$names;
    return {} unless @names;
    my @types = values %{$v->{stock_type}};
    my $np = join(',', ('?') x @names);
    my $tp = join(',', ('?') x @types);
    my $sql = "SELECT uniquename AS matched_name, stock_id, uniquename, type_id, organism_id
        FROM stock WHERE uniquename IN ($np) AND type_id IN ($tp)";
    my @bind = (@names, @types);
    if (my $synonym = $v->{stock_property}{stock_synonym}) {
        $sql .= " UNION SELECT p.value AS matched_name, s.stock_id, s.uniquename, s.type_id, s.organism_id
            FROM stockprop p JOIN stock s ON s.stock_id = p.stock_id
            WHERE p.type_id = ? AND p.value IN ($np) AND s.type_id IN ($tp)";
        push @bind, $synonym, @names, @types;
    }
    my $rows = $schema->storage->dbh->selectall_arrayref($sql, {Slice => {}}, @bind);
    my (%matches, %ids);
    for my $row (@$rows) {
        my $name = delete $row->{matched_name};
        next if $ids{$name}{$row->{stock_id}}++;
        push @{$matches{$name}}, $row;
    }
    return \%matches;
}

=head2 choose($matches, $name, $allowed_types, $vocabulary)

Return one candidate for the requested role, or a clear missing/ambiguous error.

=cut

sub choose {
    my ($class, $matches, $name, $allowed, $v) = @_;
    die "A stock name is required.\n" unless defined($name) && !ref($name) && length($name);
    my %allowed = map {$_ => 1} @$allowed;
    my @rows = grep {$allowed{$v->{stock_names}{$_->{type_id}} || ''}} @{$matches->{$name} || []};
    die "Stock with uniquename $name was not found for this parentage role.\n" unless @rows;
    die "Parent name $name is ambiguous. Select the specific stock.\n" if @rows > 1;
    return $rows[0];
}

=head2 validate_pair($type, $female_id, $male_id)

Validate explicit new simple-pedigree input. Self requires one resolved stock in
both roles. DH/DI retain the standard upload's two explicitly recorded fields.
This method does not reinterpret unchanged historical pedigrees.

=cut

sub validate_pair {
    my ($class, $type, $female, $male) = @_;
    my %supported = map {$_ => 1} $class->supported_cross_types;
    die "Unsupported cross type: ".(defined($type) ? $type : '').".\n" unless defined($type) && $supported{$type};
    die "A female parent is required.\n" unless $female;
    die "A male parent is required for cross type $type.\n" unless $male || $type eq 'open';
    if ($male) {
        die "For self, use the same parent in both fields.\n" if $type eq 'self' && $female != $male;
        my %same_allowed = map {$_ => 1} qw(self sib reselected doubled_haploid dihaploid_induction);
        die "The parents cannot be the same for cross type $type.\n" if $female == $male && !$same_allowed{$type};
    }
}

=head2 prepare($schema, $pedigrees, $source_rows, $vocabulary)

Resolve and validate a whole simple-pedigree batch before writing. Canonical and
synonym input targeting the same child is rejected with both source positions.

=cut

sub prepare {
    my ($class, $schema, $pedigrees, $source_rows, $v) = @_;
    $v ||= $class->vocabulary($schema);
    $source_rows ||= [];
    my @names;
    for my $p (@$pedigrees) {
        push @names, $p->get_name;
        push @names, $p->get_female_parent->get_name if $p->has_female_parent;
        push @names, $p->get_male_parent->get_name if $p->has_male_parent;
    }
    my $matches = $class->resolve_names($schema, \@names, $v);
    my (@plans, %seen);
    for my $i (0 .. $#$pedigrees) {
        my $p = $pedigrees->[$i];
        my $position = defined($source_rows->[$i]) ? 'row '.$source_rows->[$i] : 'entry '.($i + 1);
        my $child = $class->choose($matches, $p->get_name, [qw(accession cross)], $v);
        die "The same accession is specified in $seen{$child->{stock_id}} and $position.\n" if $seen{$child->{stock_id}};
        $seen{$child->{stock_id}} = $position;
        die "A female parent is required at $position.\n" unless $p->has_female_parent;
        my $female = $class->choose($matches, $p->get_female_parent->get_name, [qw(accession cross)], $v);
        my $male;
        $male = $class->choose($matches, $p->get_male_parent->get_name,
            [qw(accession cross population vector_construct)], $v) if $p->has_male_parent && defined($p->get_male_parent->get_name) && length($p->get_male_parent->get_name);
        $class->validate_pair($p->get_cross_type, $female->{stock_id}, $male ? $male->{stock_id} : undef);
        push @plans, {child_id => $child->{stock_id}, female => $female->{stock_id},
            male => $male ? $male->{stock_id} : undef, type => $p->get_cross_type, position => $position};
    }
    return \@plans;
}

=head2 assert_acyclic($schema, $child_ids, $vocabulary)

Check the complete proposed graph inside the locked transaction. UNION bounds
revisiting in legacy cycles and shared ancestors. Graft ancestry is included to
match the stock ancestor viewer. Only cycles involving changed children reject
the write; unrelated historical records are not rewritten.

=cut

sub assert_acyclic {
    my ($class, $schema, $ids, $v) = @_;
    return unless @$ids;
    $v ||= $class->vocabulary($schema);
    my @types = values %{$v->{stock_relationship}};
    my $cp = join(',', ('?') x @$ids);
    my $tp = join(',', ('?') x @types);
    my ($cycle) = $schema->storage->dbh->selectrow_array(qq{
        WITH RECURSIVE ancestors(root_id, stock_id) AS (
            SELECT object_id, subject_id FROM stock_relationship
            WHERE object_id IN ($cp) AND type_id IN ($tp)
            UNION
            SELECT a.root_id, r.subject_id FROM ancestors a
            JOIN stock_relationship r ON r.object_id = a.stock_id
            WHERE r.type_id IN ($tp)
        )
        SELECT root_id FROM ancestors WHERE root_id = stock_id LIMIT 1
    }, undef, @$ids, @types, @types);
    die "A parent relationship cannot make a stock its own ancestor (stock $cycle).\n" if defined($cycle);
}

=head2 apply($schema, $plans, $overwrite, $vocabulary)

Apply canonical plans inside a transaction after lock(). Conflicting saved roles
require explicit overwrite. Identical requests are idempotent; missing roles or
an explicitly supplied missing type may be completed without replacing data.

=cut

sub apply {
    my ($class, $schema, $plans, $overwrite, $v) = @_;
    die "Parentage writes require a transaction.\n" unless $schema->storage->transaction_depth;
    $v ||= $class->vocabulary($schema);
    $overwrite = $class->overwrite_flag($overwrite);
    my %seen;
    my @ids = sort {$a <=> $b} map {
        die "The same accession occurs more than once in this batch.\n" if $seen{$_->{child_id}}++;
        $_->{child_id}
    } @$plans;
    return {changed => 0, unchanged => 0} unless @ids;
    my @locked = $schema->resultset('Stock::Stock')->search({stock_id => {-in => \@ids}}, {for => 'update', order_by => 'stock_id'})->all;
    die "A target accession was not found.\n" unless @locked == @ids;
    my %role_for = reverse %{$v->{roles}};
    my %existing;
    my $rs = $schema->resultset('Stock::StockRelationship')->search({object_id => {-in => \@ids}, type_id => {-in => [values %{$v->{roles}}]}});
    while (my $r = $rs->next) {push @{$existing{$r->object_id}{$role_for{$r->type_id}}}, $r}
    my (@changed, $unchanged);
    for my $plan (@$plans) {
        my $id = $plan->{child_id};
        my $current = $existing{$id} || {};
        my $type = $class->normalize_type($plan->{type});
        my $different = 0;
        for my $role (qw(female male)) {
            my @rows = @{$current->{$role} || []};
            if (!$overwrite) {
                die "More than one $role parent is stored. Use explicit overwrite after reviewing the pedigree.\n" if @rows > 1;
                die "The existing $role parent conflicts with this pedigree. Explicit overwrite is required.\n"
                    if @rows && (!defined($plan->{$role}) || $rows[0]->subject_id != $plan->{$role});
            }
            $different = 1 if @rows != (defined($plan->{$role}) ? 1 : 0)
                || (@rows == 1 && defined($plan->{$role}) && $rows[0]->subject_id != $plan->{$role});
        }
        my $female = $current->{female} && @{$current->{female}} == 1 ? $current->{female}[0] : undef;
        my $old_type = $female ? $class->normalize_type($female->value) : undef;
        my $same_type = (!defined($type) && !defined($old_type)) || (defined($type) && defined($old_type) && $type eq $old_type);
        die "The existing cross type conflicts with this pedigree. Explicit overwrite is required.\n"
            if !$overwrite && defined($old_type) && !$same_type;
        $different = 1 unless $same_type;
        if (!$different) {$unchanged++; next}
        if ($overwrite) {
            $schema->resultset('Stock::StockRelationship')->search({object_id => $id, type_id => {-in => [values %{$v->{roles}}]}})->delete;
            $current = {};
        }
        for my $role (qw(female male)) {
            next unless defined($plan->{$role});
            my $old = $current->{$role} && $current->{$role}[0];
            if (!$old) {
                $schema->resultset('Stock::StockRelationship')->create({object_id => $id,
                    subject_id => $plan->{$role}, type_id => $v->{roles}{$role}, value => $role eq 'female' ? $type : undef});
            } elsif ($role eq 'female' && !defined($old_type) && defined($type)) {
                $old->update({value => $type});
            }
        }
        push @changed, $id;
    }
    $class->assert_acyclic($schema, \@changed, $v);
    return {changed => scalar(@changed), unchanged => $unchanged || 0};
}

1;
