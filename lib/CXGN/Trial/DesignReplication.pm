package CXGN::Trial::DesignReplication;

use strict;
use warnings;
use SGN::Model::Cvterm;

=head1 NAME

CXGN::Trial::DesignReplication - recorded design tags and field occurrence state

=head1 DESCRIPTION

Field-plot stock_property replicate is an accession occurrence label after a
trial's accession_occurrence_version becomes 1. design_replicate is a separate,
single-valued snapshot of its recorded design replication tag. A row with NULL
value records missing information; it must never fall back to a new occurrence.
Legacy rows without a snapshot resolve to their existing recorded replicate.
These values preserve available records, not reconstructed historical designs.
CRD labels are not blocking factors; consumers must respect the declared design.

The public/statistical replicate field remains the design tag. The operational
counter is published separately, only after the whole field layout is normalized.
Functions take a schema as their first argument; they are not class methods.

=cut

sub _term {
    my ($schema, $name, $cv) = @_;
    my $row = SGN::Model::Cvterm->get_cvterm_row($schema, $name, $cv);
    return $row ? $row->cvterm_id : undef;
}

=head2 read($schema, \@stock_ids)

Return a stock-id keyed hash containing recorded (snapshot row presence), value
(resolved design tag, possibly NULL), occurrence (resolved operational label), occurrence_raw (stored replicate),
occurrence_ready and field_projects. Missing snapshot and recorded NULL differ.
The resolved block is the unanimous plot-source tag for same-field descendants,
or the local raw tag for independent layouts. block_raw and block_recorded retain
inspection of the stored property; field_block_inherited identifies resolution.
No plot source or conflicting field contexts mean an unknown inherited block.
Only one same-field plot source can provide a child occurrence; pooled and
orphan units never advertise a legacy local label as a modern field counter.
All requested units are resolved in batches, including current project versions.

=cut

sub read {
    my ($schema, $stock_ids) = @_;
    die "Stock IDs must be an array.\n" if ref($stock_ids) ne 'ARRAY';
    return {} if !@$stock_ids;
    my %ids;
    for my $id (@$stock_ids) {
        die "Stock IDs must be positive integers.\n" if !defined($id) || ref($id) || $id !~ /^[1-9]\d*$/;
        $ids{$id} = 1;
    }
    my %result = map {$_ => {recorded=>0, value=>undef, occurrence=>undef, occurrence_raw=>undef, occurrence_ready=>0, field_projects=>[], missing_after_cutover=>0, block=>undef, block_raw=>undef, block_recorded=>0, field_block_inherited=>0}} keys %ids;
    my $rep = _term($schema, 'replicate', 'stock_property');
    my $design = _term($schema, 'design_replicate', 'stock_property');
    my $block = _term($schema, 'block', 'stock_property');
    my @types = grep {defined} ($rep, $design, $block);
    if (@types) {
        my $rows = $schema->storage->dbh->selectall_arrayref(
            'SELECT stock_id, type_id, value FROM stockprop WHERE stock_id=ANY(?) AND type_id=ANY(?) ORDER BY stock_id, type_id, rank',
            undef, [keys %ids], \@types);
        my %seen;
        for my $row (@$rows) {
            my ($id, $type, $value) = @$row;
            die "Stock $id has multiple values for a single replication property; correct its metadata first.\n" if $seen{$id}{$type}++;
            if (defined($design) && $type == $design) {
                $result{$id}{recorded}=1;
                $result{$id}{value}=$value;
            } elsif (defined($rep) && $type == $rep) {
                $result{$id}{occurrence}=$value;
                $result{$id}{occurrence_raw}=$value;
            } elsif (defined($block) && $type == $block) {
                $result{$id}{block_recorded}=1;
                $result{$id}{block_raw}=$value;
                $result{$id}{block}=$value;
            }
        }
    }
    for my $id (keys %result) {
        $result{$id}{value}=$result{$id}{occurrence} if !$result{$id}{recorded};
    }
    my $version = _term($schema, 'accession_occurrence_version', 'project_property');
    my $field = _term($schema, 'field_layout', 'experiment_type');
    if ($field) {
        my $rows = $schema->storage->dbh->selectall_arrayref(q{
            SELECT DISTINCT nes.stock_id, nep.project_id, pp.value
            FROM nd_experiment_stock nes JOIN nd_experiment ne USING(nd_experiment_id)
            JOIN nd_experiment_project nep USING(nd_experiment_id)
            LEFT JOIN projectprop pp ON pp.project_id=nep.project_id AND pp.type_id=? AND pp.rank=0
            WHERE nes.stock_id=ANY(?) AND ne.type_id=?
        }, undef, $version, [keys %ids], $field);
        my %projects;
        for my $row (@$rows) { $projects{$row->[0]}{$row->[1]}=$row->[2]; }
        for my $id (keys %projects) {
            my @projects = sort {$a<=>$b} keys %{$projects{$id}};
            $result{$id}{field_projects}=\@projects;
            $result{$id}{occurrence_ready}=1 if @projects==1 && defined($projects{$id}{$projects[0]}) && $projects{$id}{$projects[0]} eq '1';
            if (!$result{$id}{recorded} && grep {defined($_) && $_ eq '1'} values %{$projects{$id}}) {
                $result{$id}{value}=undef;
                $result{$id}{missing_after_cutover}=1;
            }
        }
    }
    _inherit_field_context($schema,\%result);
    return \%result;
}

# Field descendants physically remain in their source plot block. Resolve all
# plot sources rather than using a cache traversal's last parent. External
# sampling/plate studies retain their independent local block property.
sub _inherit_field_context {
    my ($schema,$result)=@_;
    my @field_ids=grep {@{$result->{$_}{field_projects}}} keys %$result;
    return if !@field_ids;
    my $children=$schema->storage->dbh->selectcol_arrayref(q{
        SELECT s.stock_id FROM stock s JOIN cvterm t ON t.cvterm_id=s.type_id
        WHERE s.stock_id=ANY(?) AND t.name IN ('plant','subplot','tissue_sample')
    },undef,\@field_ids);
    return if !@$children;
    my $rows=$schema->storage->dbh->selectall_arrayref(q{
        WITH RECURSIVE ancestry(unit_id,stock_id) AS (
            SELECT id,id FROM unnest(?::integer[]) id
          UNION
            SELECT a.unit_id,parent.stock_id FROM ancestry a
            JOIN stock child ON child.stock_id=a.stock_id
            JOIN cvterm ct ON ct.cvterm_id=child.type_id
            JOIN stock_relationship r ON
                (ct.name IN ('plant','subplot') AND r.object_id=a.stock_id) OR
                (ct.name='tissue_sample' AND r.subject_id=a.stock_id)
            JOIN cvterm rt ON rt.cvterm_id=r.type_id
            JOIN stock parent ON parent.stock_id=CASE WHEN ct.name='tissue_sample' THEN r.object_id ELSE r.subject_id END
            JOIN cvterm pt ON pt.cvterm_id=parent.type_id
            WHERE ((ct.name='plant' AND rt.name='plant_of') OR
                   (ct.name='subplot' AND rt.name='subplot_of') OR
                   (ct.name='tissue_sample' AND rt.name='tissue_sample_of')) AND
                  pt.name IN ('plot','plant','subplot','tissue_sample')
        ) SELECT DISTINCT a.unit_id,a.stock_id FROM ancestry a
          JOIN stock s ON s.stock_id=a.stock_id JOIN cvterm t ON t.cvterm_id=s.type_id
          WHERE t.name='plot' ORDER BY a.unit_id,a.stock_id
    },undef,$children);
    my (%parents,%root_ids);
    for my $row (@$rows) {$parents{$row->[0]}{$row->[1]}=1;$root_ids{$row->[1]}=1}
    my %roots=map {$_=>$result->{$_}} grep {exists($result->{$_})} keys %root_ids;
    my @missing=grep {!exists($roots{$_})} keys %root_ids;
    if (@missing) {
        # All recursive inputs are plots, so this does not recurse through a
        # descendant graph or silently substitute a descendant's local tag.
        my $more=CXGN::Trial::DesignReplication::read($schema,\@missing);
        @roots{keys %$more}=values %$more;
    }
    for my $id (@$children) {
        my @roots=sort {$a<=>$b} keys %{$parents{$id} || {}};
        my $same_context=@{$result->{$id}{field_projects}}==1 && @roots;
        for my $root (@roots) {
            my $projects=$roots{$root}{field_projects};
            $same_context=0 if @$projects!=1 || $projects->[0]!=$result->{$id}{field_projects}[0];
        }
        my %values=map {my $value=$roots{$_}{block};(defined($value) ? 'V'.$value:'N')=>1} @roots;
        $result->{$id}{block}=$same_context && keys(%values)==1 ? $roots{$roots[0]}{block}:undef;
        $result->{$id}{field_block_inherited}=1;
        # A child has one accession occurrence only through one unambiguous
        # plot source. Keep the stored value separately for drift detection
        # and normalization; do not advertise a pooled/orphan legacy label.
        $result->{$id}{occurrence}=$same_context && @roots==1 ? $roots{$roots[0]}{occurrence}:undef;
        $result->{$id}{occurrence_ready}=$same_context && @roots==1 && $roots{$roots[0]}{occurrence_ready} ? 1:0;
    }
}

=head2 set($schema, $stock_id, $value)

Set intentional design metadata, retaining an explicit NULL row when cleared.
Caller authorization and hierarchy/cache updates belong to the owning workflow.

=cut

sub set {
    my ($schema, $stock_id, $value) = @_;
    die "Stock ID must be a positive integer.\n" if !defined($stock_id) || ref($stock_id) || $stock_id !~ /^[1-9]\d*$/;
    die "Design replication must be a scalar or NULL.\n" if defined($value) && ref($value);
    my $type = _term($schema, 'design_replicate', 'stock_property');
    die "Run AddDesignReplicationStockprop before changing design replication.\n" if !defined($type);
    $schema->txn_do(sub {
        $schema->resultset('Stock::Stockprop')->search({stock_id=>$stock_id,type_id=>$type})->delete;
        $schema->resultset('Stock::Stockprop')->create({stock_id=>$stock_id,type_id=>$type,value=>$value,rank=>0});
    });
    return 1;
}

=head2 capture($schema, \@stock_ids, \%initial_values)

Fill missing snapshot rows exactly once. Optional initial values are authoritative
native layout/parent inputs; otherwise preserve the currently recorded legacy tag.
An existing NULL row is preserved. Call within the owning mutation transaction.

=cut

sub capture {
    my ($schema, $stock_ids, $initial) = @_;
    $initial ||= {};
    my $current = CXGN::Trial::DesignReplication::read($schema, $stock_ids);
    for my $id (sort {$a<=>$b} keys %$current) {
        next if $current->{$id}{recorded};
        my $value = exists($initial->{$id}) ? $initial->{$id} : $current->{$id}{value};
        set($schema, $id, $value);
    }
    return 1;
}

=head2 mark_occurrences_ready($schema, $trial_id)

Mark a whole field-layout occurrence conversion inside its owning transaction.
This version describes counter semantics, not scientific validation of legacy tags.

=cut

sub mark_occurrences_ready {
    my ($schema, $trial_id) = @_;
    my $type = _term($schema, 'accession_occurrence_version', 'project_property');
    die "Run AddDesignReplicationStockprop before normalizing accession occurrences.\n" if !defined($type);
    $schema->resultset('Project::Projectprop')->search({project_id=>$trial_id,type_id=>$type})->delete;
    $schema->resultset('Project::Projectprop')->create({project_id=>$trial_id,type_id=>$type,value=>'1',rank=>0});
    return 1;
}

1;
