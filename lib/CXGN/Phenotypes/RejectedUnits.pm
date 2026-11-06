package CXGN::Phenotypes::RejectedUnits;

=head1 NAME

CXGN::Phenotypes::RejectedUnits - the observation units whose values are left out because their plot is rejected

=head1 DESCRIPTION

A rejected plot (stock property C<rejected> = 1, set with
L<CXGN::Trial::AccessionChange>) is a planted plot whose data must not be
used. Its values and those of its plants, subplots and tissue samples stay in
the database, but the phenotype searches (L<CXGN::Phenotypes::Search::Native>,
L<CXGN::Phenotypes::Search::MaterializedViewTable>,
L<CXGN::Phenotypes::HighDimensionalPhenotypesSearch>) leave them out unless
asked otherwise (C<exclude_rejected =E<gt> 0>), and so do the downloads,
datasets and analyses that read through them.

=head2 sql($schema_or_dbh, $property, $with_roots)

Accepts a Bio::Chado::Schema or an existing DBI handle and returns a parenthesized
SQL subquery with no bind values. C<$property> defaults to C<rejected>; the only
other supported property is C<not_planted>. Unsupported property names die.

By default the subquery selects distinct C<stock_id> values: marked source
stocks and their plants, subplots and tissue samples, including descendants in
other trials. With a true C<$with_roots>, it instead selects C<stock_id> and
C<root_id> pairs. C<root_id> is the stock carrying the stored flag; a descendant
can have more than one marked root. If the property cvterm is absent, the
subquery selects no rows and retains the requested column names.

=head2 not_rejected_sql($schema_or_dbh, $qualified_stock_column)

A reusable analytical-read predicate. The column must be a trusted SQL
identifier; original observations remain available through explicit raw reads.

=head2 ids($schema, \@stock_ids)

A hashref of those of the stock ids that are rejected units.

=head2 marked_ids($schema, \@stock_ids, $property)

Returns a hashref C<stock_id =E<gt> 1> containing only the requested stock IDs
whose own or inherited status matches C<$property>. The property defaults to
C<rejected> and also accepts C<not_planted>, with the same validation as C<sql>.
This method requires a Bio::Chado::Schema. Undefined or empty input lists
return an empty hashref.

=head2 status_details($schema, \@stock_ids)

Returns a hashref keyed by the requested stock IDs that have inherited
C<rejected> or C<not_planted> status. Each value contains the applicable flags
as C<1>; unaffected IDs and false flags are omitted. Where available,
C<reject_reason> contains distinct reason values from the rejected roots,
joined with C<; > in lexical order, if the resulting string is nonempty.
Undefined or empty input lists return an empty hashref.

Status inheritance follows the stored relationships. These readers do not
write status properties on descendants or change the original observations.

=cut

use strict;
use warnings;
use SGN::Model::Cvterm;

sub sql {
    my $class = shift;
    my $schema = shift;
    my $property = shift // 'rejected';
    my $with_roots = shift;
    die 'Unsupported observation-unit status property' unless $property eq 'rejected' || $property eq 'not_planted';
    # Legacy consumers such as BreederSearch own a DBI handle rather than a
    # schema. Resolve the same controlled vocabulary without a new connection.
    my $cvterm = sub {
        if ($schema->can('resultset')) {
            my $row = SGN::Model::Cvterm->get_cvterm_row($schema, @_);
            return $row ? $row->cvterm_id : undef;
        }
        return ($schema->selectrow_array('SELECT cvterm_id FROM cvterm JOIN cv USING(cv_id) WHERE cvterm.name = ? AND cv.name = ?', undef, @_))[0];
    };
    my $rejected = $cvterm->($property, 'stock_property');
    return $with_roots ? "(SELECT NULL::integer AS stock_id, NULL::integer AS root_id WHERE false)" : "(SELECT NULL::integer AS stock_id WHERE false)" if !$rejected;   # the patch has not run: nothing is rejected
    my ($plant_of, $subplot_of, $tissue_sample_of) = map { $cvterm->($_, 'stock_relationship') // 0 } qw(plant_of subplot_of tissue_sample_of);
    my ($plant, $subplot, $tissue_sample) = map { $cvterm->($_, 'stock_type') // 0 } qw(plant subplot tissue_sample);
    # downwards from the plot: plant_of and subplot_of have subject = plot and object = child,
    # tissue_sample_of has subject = sample and object = parent; the type of the child keeps
    # accessions out (a plant and a sample are linked to their accession the same way)
    my $columns = $with_roots ? 'stock_id, root_id' : 'DISTINCT stock_id';
    return "(WITH RECURSIVE rejected_units(stock_id, root_id) AS (
            SELECT stock_id, stock_id FROM stockprop WHERE type_id = $rejected AND value = '1'
          UNION
            SELECT child.stock_id, ru.root_id FROM rejected_units ru
            JOIN stock_relationship r ON (r.type_id IN ($plant_of, $subplot_of) AND r.subject_id = ru.stock_id) OR (r.type_id = $tissue_sample_of AND r.object_id = ru.stock_id)
            JOIN stock child ON child.stock_id = CASE WHEN r.type_id = $tissue_sample_of THEN r.subject_id ELSE r.object_id END AND child.type_id IN ($plant, $subplot, $tissue_sample)
        ) SELECT $columns FROM rejected_units)";
}

# A predicate for trusted SQL identifiers, shared by analytical consumers.
# The raw source rows remain available to inspection/maintenance paths.
sub not_rejected_sql {
    my ($class, $schema_or_dbh, $stock_column) = @_;
    die "Invalid stock column for rejection filter" unless defined($stock_column) && $stock_column =~ /^[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)?$/;
    return "NOT EXISTS (SELECT 1 FROM ".$class->sql($schema_or_dbh)." rejection_filter WHERE rejection_filter.stock_id = $stock_column)";
}

sub ids { return $_[0]->marked_ids($_[1], $_[2], 'rejected'); }

# Inherited status is derived from existing field ancestry, never duplicated on
# children. Both supported properties share the same relationship directions.
sub marked_ids {
    my ($class, $schema, $stock_ids, $property) = @_;
    return {} if !$stock_ids || !@$stock_ids;
    my $h = $schema->storage->dbh->prepare("SELECT r.stock_id FROM ".$class->sql($schema, $property)." r WHERE r.stock_id = ANY(?)");
    $h->execute($stock_ids);
    my %ids;
    while (my ($id) = $h->fetchrow_array()) { $ids{$id} = 1; }
    return \%ids;
}

sub status_details {
    my ($class, $schema, $stock_ids) = @_;
    return {} if !$stock_ids || !@$stock_ids;
    my %details;
    for my $property (qw(rejected not_planted)) {
        $details{$_}->{$property} = 1 for keys %{$class->marked_ids($schema, $stock_ids, $property)};
    }
    my $reason = SGN::Model::Cvterm->get_cvterm_row($schema, 'reject_reason', 'stock_property');
    if ($reason) {
        my $sql = "SELECT r.stock_id, string_agg(DISTINCT p.value, '; ' ORDER BY p.value) FROM ".$class->sql($schema, 'rejected', 1)." r JOIN stockprop p ON p.stock_id = r.root_id AND p.type_id = ? WHERE r.stock_id = ANY(?) GROUP BY r.stock_id";
        my $h = $schema->storage->dbh->prepare($sql);
        $h->execute($reason->cvterm_id, $stock_ids);
        while (my ($id, $value) = $h->fetchrow_array()) { $details{$id}->{reject_reason} = $value if defined($value) && length($value); }
    }
    return \%details;
}

1;
