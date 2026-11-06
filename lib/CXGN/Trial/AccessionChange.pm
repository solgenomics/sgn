package CXGN::Trial::AccessionChange;

=head1 NAME

CXGN::Trial::AccessionChange - change the accession (cross, family name) of plots in a field trial, or of wells in a genotyping plate

=head1 SYNOPSIS

    my $change = CXGN::Trial::AccessionChange->new({
        schema   => $schema,      # Bio::Chado::Schema
        trial_id => $trial_id,
    });

    # what would change, without changing anything
    my $plan = $change->plan([ { plot_id => 38866, new_stock_id => 38840 } ], { rename_plots => 'auto' });
    print join("\n", @{$plan->{errors}}) if @{$plan->{errors}};

    # the same, in one transaction; dies with the errors of the plan
    my $result = $change->apply([ { plot_id => 38866, new_stock_id => 38840 } ]);

    # every plot of one stock
    my $changes = $change->changes_for_stock($old_stock_id, $new_stock_id);


=head1 DESCRIPTION

A plot is a place in the field. Its plot number, block, replicate, row and
column describe that place and are part of the design. The accession is what
grows there. Changing the accession of a plot corrects what was planted (or
will be planted); it does not move the plot. So a change:

=over

=item *

links the plot to the new stock (C<plot_of>), and the plants, subplots and
tissue samples of the plot (C<plant_of>, C<subplot_of>, C<tissue_sample_of>),
also the samples of them in other trials, for example the wells of a
genotyping plate made from the plants of the plot: they were taken from what
grew there. The plan names those samples, and the layouts of their trials are
cached again.

=item *

keeps the plot number, block, row, column and recorded design replication tag.
The separate occurrence labels of all accessions are normalized by plot number
when membership changes, in every field design. Missing and zero legacy tags
are preserved separately before normalization; a missing occurrence is created.
An unsown planned position still occupies a place in this numbering.

=item *

renames plots if asked to (C<rename_plots =E<gt> 'auto'>, the default). A
trial with a plot name template gets the template name for every plot whose
accession or replicate changes. Otherwise the old stock name is replaced by
the new one where it is a whole part of the plot name (at the start or after
C<-> or C<_>, and at the end or before C<-> or C<_>). A name that contains
the old stock name that way more than once is left as it is and listed in
C<not_renamed>. An explicit C<new_plot_name> in a change is always used; one
that is the current name keeps it. Plants, subplots and tissue samples whose
names start with the plot name are renamed with it. All renames happen in
two passes, so a new name can be one that another plot in the same change
has now.

=item *

keeps the check plots (C<is a control>) with the check accessions: a plot
becomes a check plot when its new accession is a check in this trial (all of
its plots are check plots) and a test plot when it is not (none are). A new
accession that takes the place of another one everywhere takes over its
check marks; another accession that is new to the trial makes a test plot.
For an accession that is a check on some plots and not on others the mark is
left as it is, with a warning. Plants, subplots and tissue samples that have
a check mark get the one of their plot, and the occurrence label of their
plot, while their recorded design tags remain separate.

=item *

warns when plots already have phenotypes (the values stay with the plot, so
they count for the new accession) and when plots or their plants are parents
of crosses (the crosses keep their recorded parents).

=item *

with the option C<seedlots =E<gt> 'follow'> (the Change Accessions file, which
has a preview) or a C<seedlot_name> in a change, moves the seed transactions
(seedlot to plot) with the packets: a plot that gets another accession takes
over the transaction of a plot in the same change that lost that accession, or
of the seedlot in C<seedlot_name>. A transaction that no plot takes, for
example of a packet planted into a border, becomes seed taken from the
seedlot, so the inventory stays as it is; it keeps what it was, and goes back
to its plot when a later correction gives the plot a stock of that seedlot
again, so the packet is not recorded a second time. Without the option the
seed transactions stay where they are.

=item *

gives the new stock the entry number of the old one when the old stock leaves
the trial, the new one is new to the trial, and nothing else claims that entry
number.

=item *

regenerates the cached trial layout.

=back

The layout is always read from the database, never from the cached layout,
which may be out of date.

Genotyping plates (C<experiment_type =E<gt> 'genotyping_layout'>) work the
same way for wells (tissue samples linked to an accession with
C<tissue_sample_of>), but wells are never renamed and have no replicates.

The materialized views are not refreshed here, because that has to happen
after the transaction is committed; callers do it.

The plants, subplots and tissue samples of a plot in this trial get the
replicate number and the check mark of their plot with it; the samples in
other trials keep their own properties.

=cut

use Moose;
use JSON;
use Try::Tiny;
use Digest::MD5 qw(md5_hex);
use Encode qw(encode_utf8);
use SGN::Model::Cvterm;
use CXGN::Trial::TrialLayout;
use CXGN::Trial::DesignReplication;
use CXGN::BreedersToolbox::Projects;
use CXGN::Stock::Seedlot;
use CXGN::JSONUtils qw(decode_stored_json);

has 'schema' => ( isa => 'Bio::Chado::Schema', is => 'ro', required => 1 );

has 'trial_id' => ( isa => 'Int', is => 'ro', required => 1 );

=head2 experiment_type

'field_layout' (default) for plots of a field trial, 'genotyping_layout' for wells of a genotyping plate.

=cut

has 'experiment_type' => ( isa => 'Str', is => 'ro', default => 'field_layout' );

# Internal batch context from the owning, authorized transaction. Public
# request options cannot inject future assignments or claim project locks.
has '_final_stock_by_plot' => (isa=>'HashRef',is=>'ro',default=>sub {{}});
has '_locked_projects' => (isa=>'Maybe[HashRef]',is=>'ro');
has '_locked_seedlots' => (isa=>'Maybe[HashRef]',is=>'ro');

=head2 stock_type

Optional: 'accession', 'cross' or 'family_name'. The new stocks must be of
this type. Without it they must be of the type in the trial_stock_type
property of the trial, or, when the trial has none, of a type that the plots
of the trial have now.

=cut

has 'stock_type' => ( isa => 'Maybe[Str]', is => 'ro' );

has '_cvterm_ids' => ( isa => 'HashRef', is => 'ro', lazy => 1, builder => '_build_cvterm_ids' );

has '_trial_name' => ( isa => 'Str', is => 'ro', lazy => 1, builder => '_build_trial_name' );

has '_breeding_program_name' => ( isa => 'Str', is => 'ro', lazy => 1, builder => '_build_breeding_program_name' );

sub _build_cvterm_ids {
    my $self = shift;
    my $schema = $self->schema;
    my %ids;
    my @terms = (
        [ plot => 'plot', 'stock_type' ],
        [ plant => 'plant', 'stock_type' ],
        [ subplot => 'subplot', 'stock_type' ],
        [ tissue_sample => 'tissue_sample', 'stock_type' ],
        [ accession => 'accession', 'stock_type' ],
        [ cross => 'cross', 'stock_type' ],
        [ family_name => 'family_name', 'stock_type' ],
        [ seedlot => 'seedlot', 'stock_type' ],
        [ plot_of => 'plot_of', 'stock_relationship' ],
        [ plant_of => 'plant_of', 'stock_relationship' ],
        [ subplot_of => 'subplot_of', 'stock_relationship' ],
        [ tissue_sample_of => 'tissue_sample_of', 'stock_relationship' ],
        [ intercrop_plot_of => 'intercrop_plot_of', 'stock_relationship' ],
        [ female_plot_of => 'female_plot_of', 'stock_relationship' ],
        [ male_plot_of => 'male_plot_of', 'stock_relationship' ],
        [ female_plant_of => 'female_plant_of', 'stock_relationship' ],
        [ male_plant_of => 'male_plant_of', 'stock_relationship' ],
        [ seed_transaction => 'seed transaction', 'stock_relationship' ],
        [ collection_of => 'collection_of', 'stock_relationship' ],
        [ cross_member_of => 'cross_member_of', 'stock_relationship' ],
        [ plot_number => 'plot number', 'stock_property' ],
        [ block => 'block', 'stock_property' ],
        [ replicate => 'replicate', 'stock_property' ],
        [ design_replicate => 'design_replicate', 'stock_property' ],
        [ occurrence_version => 'accession_occurrence_version', 'project_property' ],
        [ row_number => 'row_number', 'stock_property' ],
        [ col_number => 'col_number', 'stock_property' ],
        [ range => 'range', 'stock_property' ],
        [ is_a_control => 'is a control', 'stock_property' ],
        [ phenotyping_experiment => 'phenotyping_experiment', 'experiment_type' ],
        [ field_layout => 'field_layout', 'experiment_type' ],
        [ genotyping_layout => 'genotyping_layout', 'experiment_type' ],
        [ design => 'design', 'project_property' ],
        [ plot_name_template => 'plot_autogenerated_name_metadata', 'project_property' ],
        [ entry_numbers => 'project_entry_number_map', 'project_property' ],
    );
    foreach my $t (@terms) {
        my $row = SGN::Model::Cvterm->get_cvterm_row($schema, $t->[1], $t->[2]);
        $ids{$t->[0]} = $row ? $row->cvterm_id() : undef;
    }
    return \%ids;
}

sub _is_plate {
    my $self = shift;
    return $self->experiment_type eq 'genotyping_layout';
}

# stock type and relationship of the units that carry the accession
sub _unit_type_id { my $self = shift; return $self->_cvterm_ids->{ $self->_is_plate ? 'tissue_sample' : 'plot' }; }
sub _unit_relationship_id { my $self = shift; return $self->_cvterm_ids->{ $self->_is_plate ? 'tissue_sample_of' : 'plot_of' }; }

# the stock types the new stocks may have, see stock_type
sub _allowed_stock_types {
    my $self = shift;
    my $units = shift;
    my $ids = $self->_cvterm_ids;
    my @names = $self->_is_plate ? ('accession') : ('accession', 'cross', 'family_name');
    my $wanted = $self->stock_type;
    if (!$wanted && !$self->_is_plate) {
        my $type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema, 'trial_stock_type', 'project_property');
        my $row = $type_id ? $self->schema->resultset('Project::Projectprop')->find({ project_id => $self->trial_id, type_id => $type_id->cvterm_id() }) : undef;
        $wanted = $row->value if $row;
    }
    if ($wanted) {
        # trials of crosses or family names can have accessions as checks
        return [ grep { $_ eq $wanted || $_ eq 'accession' } @names ];
    }
    my %present = map { $_->{stock_type_id} => 1 } grep { defined $_->{stock_type_id} } values %$units;
    my @present = grep { $ids->{$_} && $present{ $ids->{$_} } } @names;
    return @present ? \@present : \@names;
}

=head2 load_units()

Reads the plots (or wells) of the trial from the database. Returns a hashref
plot_id => { plot_id, plot_name, stock_id, stock_name, plot_number, block,
replicate, row_number, col_number, range, is_a_control }. A plot that is not linked to exactly one stock has no stock_id,
and stock_count instead.

=cut

sub load_units {
    my $self = shift;
    my $dbh = $self->schema->storage->dbh;
    my $ids = $self->_cvterm_ids;
    my $experiment_type_id = $ids->{ $self->experiment_type } or die "Unknown experiment type ".$self->experiment_type."\n";

    my $units_q = "SELECT DISTINCT unit.stock_id, unit.uniquename
        FROM nd_experiment_project nep
        JOIN nd_experiment ne ON ne.nd_experiment_id = nep.nd_experiment_id AND ne.type_id = ?
        JOIN nd_experiment_stock nes ON nes.nd_experiment_id = ne.nd_experiment_id
        JOIN stock unit ON unit.stock_id = nes.stock_id AND unit.type_id = ?
        WHERE nep.project_id = ?";
    my $h = $dbh->prepare($units_q);
    $h->execute($experiment_type_id, $self->_unit_type_id, $self->trial_id);
    my %units;
    while (my ($stock_id, $name) = $h->fetchrow_array()) {
        $units{$stock_id} = { plot_id => $stock_id, plot_name => $name, stocks => [] };
    }
    my @unit_ids = keys %units;
    return {} if !@unit_ids;

    my $stocks_q = "SELECT r.subject_id, r.object_id, s.uniquename, s.type_id
        FROM stock_relationship r
        JOIN stock s ON s.stock_id = r.object_id
        WHERE r.type_id = ? AND r.subject_id = ANY(?) AND s.type_id = ANY(?)";
    $h = $dbh->prepare($stocks_q);
    $h->execute($self->_unit_relationship_id, \@unit_ids, $self->_primary_stock_type_ids());
    while (my ($unit_id, $stock_id, $stock_name, $type_id) = $h->fetchrow_array()) {
        push @{$units{$unit_id}->{stocks}}, { stock_id => $stock_id, stock_name => $stock_name, type_id => $type_id };
    }

    my %prop_names = map { $ids->{$_} => $_ } grep { $ids->{$_} } qw(plot_number block replicate row_number col_number range is_a_control);
    my $props_q = "SELECT stock_id, type_id, value FROM stockprop WHERE stock_id = ANY(?) AND type_id = ANY(?) ORDER BY rank";
    $h = $dbh->prepare($props_q);
    $h->execute(\@unit_ids, [ keys %prop_names ]);
    while (my ($unit_id, $type_id, $value) = $h->fetchrow_array()) {
        $units{$unit_id}->{ $prop_names{$type_id} } //= $value;
    }

    my $replication = CXGN::Trial::DesignReplication::read($self->schema, \@unit_ids);
    foreach my $unit (values %units) {
        my $rep = $replication->{$unit->{plot_id}};
        $unit->{design_replicate}=$rep->{value};
        $unit->{design_rep_recorded}=$rep->{recorded};
        $unit->{occurrence_ready}=$rep->{occurrence_ready};
        $unit->{field_projects}=$rep->{field_projects};
        my $stocks = delete $unit->{stocks};
        if (scalar(@$stocks) == 1) {
            $unit->{stock_id} = $stocks->[0]->{stock_id};
            $unit->{stock_name} = $stocks->[0]->{stock_name};
            $unit->{stock_type_id} = $stocks->[0]->{type_id};
        } else {
            $unit->{stock_count} = scalar(@$stocks);
        }
    }
    return \%units;
}

# stock types a unit can be linked to with its relationship: all of them, so
# that a unit linked to a stock of another type is found (and reported)
sub _primary_stock_type_ids {
    my $self = shift;
    my $ids = $self->_cvterm_ids;
    my @names = $self->_is_plate ? ('accession') : ('accession', 'cross', 'family_name');
    return [ map { $ids->{$_} } grep { $ids->{$_} } @names ];
}

=head2 changes_for_stock($old_stock_id, $new_stock_id)

The list of changes that replaces a stock in every plot of the trial, to pass
to plan() or apply(). Empty when the stock is in no plot of the trial.

=cut

sub changes_for_stock {
    my $self = shift;
    my $old_stock_id = shift;
    my $new_stock_id = shift;
    my $units = $self->load_units();
    return [ map { { plot_id => $_->{plot_id}, new_stock_id => $new_stock_id, old_stock_id => $old_stock_id } }
             sort { $a->{plot_id} <=> $b->{plot_id} }
             grep { defined($_->{stock_id}) && $_->{stock_id} == $old_stock_id } values %$units ];
}

=head2 find_stock($name)

The stock with the name that a plot of this trial may get: of several stocks
with the name, one of an allowed type (see stock_type) and not obsolete, as
for a new_stock_name in plan(). Returns the stock ({ stock_id, uniquename,
type_id, is_obsolete }), or undef and an error message.

=cut

sub find_stock {
    my $self = shift;
    my $name = shift // '';
    $name =~ s/^\s+|\s+$//g;
    my $ids = $self->_cvterm_ids;
    my %allowed_type = map { $ids->{$_} => 1 } grep { $ids->{$_} } @{ $self->_allowed_stock_types({}) };
    my $found = $self->_find_stocks([ { new_stock_name => $name } ], {}, \%allowed_type);
    return (undef, "More than one active stock is named $name; choose an unambiguous stock.") if $found->{ambiguous_names}->{$name};
    my $stock = length($name) ? $found->{by_name}->{$name} : undef;
    return $stock ? ($stock) : (undef, "Could not find $name in the database.");
}

# the stocks of the changes in one query: by id (new_stock_id, and the current stocks of the
# plots) and by name (new_stock_name), as { by_id => { stock_id => stock }, by_name => { name =>
# stock } }, a stock being { stock_id, uniquename, type_id, is_obsolete }. Of several stocks
# with a name, one of an allowed type is taken, and one that is not obsolete.
sub _find_stocks {
    my $self = shift;
    my $changes = shift;
    my $units = shift;
    my $allowed_type = shift;
    my %ids = map { $_ => 1 } grep { defined($_) && /^\d+$/ }
        map { ($_->{new_stock_id}, (defined($_->{plot_id}) && $units->{ $_->{plot_id} }) ? $units->{ $_->{plot_id} }->{stock_id} : undef) } @$changes;
    my %names = map { $_ => 1 } grep { length } map { my $n = $_->{new_stock_name} // ''; $n =~ s/^\s+|\s+$//g; $n } @$changes;
    my %stocks = ( by_id => {}, by_name => {}, ambiguous_names => {} );
    return \%stocks if !%ids && !%names;
    my $h = $self->schema->storage->dbh->prepare("SELECT stock_id, uniquename, type_id, is_obsolete FROM stock WHERE stock_id = ANY(?) OR uniquename = ANY(?)");
    $h->execute([ keys %ids ], [ keys %names ]);
    my %candidates;
    while (my ($stock_id, $name, $type_id, $is_obsolete) = $h->fetchrow_array()) {
        my $stock = { stock_id => $stock_id, uniquename => $name, type_id => $type_id, is_obsolete => ($is_obsolete && $is_obsolete ne 'f') ? 1 : 0 };
        $stocks{by_id}->{$stock_id} = $stock;
        push @{ $candidates{$name} }, $stock if $names{$name};
    }
    foreach my $name (keys %candidates) {
        my @active = grep { $allowed_type->{$_->{type_id}} && !$_->{is_obsolete} } @{$candidates{$name}};
        if (@active > 1) {
            $stocks{ambiguous_names}->{$name} = 1;
            next;
        }
        ($stocks{by_name}->{$name}) = sort {
            ($allowed_type->{ $a->{type_id} } ? 0 : 1) <=> ($allowed_type->{ $b->{type_id} } ? 0 : 1)
            || $a->{is_obsolete} <=> $b->{is_obsolete}
            || $a->{stock_id} <=> $b->{stock_id}
        } @{ $candidates{$name} };
    }
    return \%stocks;
}

=head2 field_trial_of_plot($schema, $plot_id)

Class method: the id of the field trial the plot belongs to, or undef.

=cut

sub field_trial_of_plot {
    my $class = shift;
    my $schema = shift;
    my $plot_id = shift;
    return if !defined($plot_id) || $plot_id !~ /^\d+$/;
    my $field_layout = SGN::Model::Cvterm->get_cvterm_row($schema, 'field_layout', 'experiment_type')->cvterm_id();
    my $trials = $schema->storage->dbh->selectcol_arrayref("SELECT DISTINCT nep.project_id FROM nd_experiment_stock nes
        JOIN nd_experiment ne ON ne.nd_experiment_id = nes.nd_experiment_id AND ne.type_id = ?
        JOIN nd_experiment_project nep ON nep.nd_experiment_id = ne.nd_experiment_id
        WHERE nes.stock_id = ? ORDER BY nep.project_id", undef, $field_layout, $plot_id);
    die "Plot $plot_id belongs to multiple field layouts; correct its layout membership first.\n" if @$trials > 1;
    return $trials->[0];
}

=head2 plan($changes, $options)

$changes is an arrayref of { plot_id, new_stock_id, new_plot_name (optional) }.
A plot can be given as plot_name instead of plot_id, and the new stock as
new_stock_name instead of new_stock_id (of several stocks with the name, one
of an allowed type, see stock_type, and not obsolete). The plots and the new
stocks of all changes are read in one query each, and the changes are planned
in the order of the plot numbers. A change whose new stock is the current one
only renames the plot (when it has a new_plot_name) or does nothing.

$options: { rename_plots => 'auto' (default) or 'none', seedlots => 'follow',
curator => 0 }. Raw observations are preserved; the old delete_phenotypes
option does not authorize deletion through an accession correction. With 'none' plots are only renamed to an explicit
new_plot_name. With seedlots 'follow' the seed transactions follow the packets
(see above). With curator 0 (a user who is not a curator) changes that only a
curator may make are errors: plots with phenotypes or high-dimensional data,
and plots with samples in other trials (the wells of a genotyping plate made
from them would get the new accession too).

A change can carry old_stock_id, the stock the caller saw on the plot; when
the plot has another stock now (someone changed it in the meantime), the plan
has an error.

Returns a hashref:

    errors        => [ messages ]; nothing may be changed when there are any
    warnings      => [ messages ]
    changes       => [ { plot_id, plot_name, old_stock_id, old_stock_name, new_stock_id, new_stock_name } ]
    unchanged     => [ plot names whose stock is already the new one ]
    replicates    => [ { plot_id, plot_name, old, new } ]
    checks        => [ { plot_id, plot_name, old, new } ]; 1 for a check plot, 0 for a test plot
    external_samples => [ { plot_name, stock_id, name } ]; samples in other trials that get the new stock too
    phenotypes_to_delete   => empty compatibility structure; no raw observations are deleted
    plots_with_phenotypes => the number of changed plots that have phenotypes
    renames       => [ { stock_id, type => 'plot'|'plant'|'subplot'|'tissue_sample', old_name, new_name } ]
    not_renamed   => [ { plot_name, reason } ]
    entry_numbers => [ { stock_id, stock_name, entry_number, from_stock_id } ]

Each error and warning is listed once, also when it concerns many plots.

=cut

sub plan {
    my $self = shift;
    my $plan = $self->_plan(@_);
    foreach my $list ('errors', 'warnings') {
        my %seen;
        @{$plan->{$list}} = grep { !$seen{$_}++ } @{$plan->{$list}};
    }
    return $plan;
}

sub _plan {
    my $self = shift;
    my $changes = shift || [];
    my $options = shift || {};
    my $rename_mode = $options->{rename_plots} // 'auto';
    my $schema = $self->schema;
    my $ids = $self->_cvterm_ids;

    my %plan = ( errors => [], warnings => [], changes => [], unchanged => [], replicates => [], renames => [], not_renamed => [], entry_numbers => [], checks => [], plots_with_phenotypes => 0, external_samples => [], seedlots => [], phenotypes_to_delete => { phenotype_ids => [], nd_experiment_ids => [] } );
    my $errors = $plan{errors};

    if ($rename_mode ne 'auto' && $rename_mode ne 'none') {
        push @$errors, "Unknown rename_plots option '$rename_mode'.";
        return \%plan;
    }
    if (ref($changes) ne 'ARRAY' || (!@$changes && !$options->{normalize_occurrences})) {
        push @$errors, "Nothing to change.";
        return \%plan;
    }

    if (grep { ref($_) ne 'HASH' } @$changes) {
        push @$errors, 'Each correction must be an object.';
        return \%plan;
    }
    my $units = $self->load_units();
    $plan{_before_units_json} = JSON->new->canonical->encode($units);
    my $allowed_types = $self->_allowed_stock_types($units);
    my %allowed_type = map { $ids->{$_} => 1 } grep { $ids->{$_} } @$allowed_types;

    # the plots by name, the stocks by id and by name (one query), in the order of the plot numbers
    my %unit_by_name = map { $_->{plot_name} => $_->{plot_id} } values %$units;
    my @changes = map { { %$_ } } @$changes;
    foreach my $change (@changes) {
        if ((!defined($change->{plot_id}) || $change->{plot_id} !~ /^\d+$/) && defined($change->{plot_name}) && exists($unit_by_name{ $change->{plot_name} })) {
            $change->{plot_id} = $unit_by_name{ $change->{plot_name} };
        }
    }
    my $stocks = $self->_find_stocks(\@changes, $units, \%allowed_type);
    @changes = sort {
        _compare_plot_numbers(map { defined($_->{plot_id}) && $units->{ $_->{plot_id} } ? $units->{ $_->{plot_id} }->{plot_number} : undef } ($a, $b))
        || ($a->{plot_name} // '') cmp ($b->{plot_name} // '')
    } @changes;

    # validate the changes
    my %new_stock_by_unit;
    my %seedlot_name;
    my %explicit_name;
    my %keep_name;
    my %seen_unit;
    my @missing_stocks;
    foreach my $change (@changes) {
        my $unit_id = $change->{plot_id};
        if (!defined($unit_id) || $unit_id !~ /^\d+$/ || !$units->{$unit_id}) {
            push @$errors, "Plot ".($change->{plot_name} // $unit_id // '(none)')." is not part of this trial.";
            next;
        }
        my $unit = $units->{$unit_id};
        my @invalid_scalars = grep { defined($change->{$_}) && ref($change->{$_}) } qw(plot_name new_stock_name new_stock_id old_stock_id new_plot_name seedlot_name);
        if (@invalid_scalars) {
            push @$errors, "Plot $unit->{plot_name}: ".join(', ', @invalid_scalars)." must be scalar values.";
            next;
        }
        if ($seen_unit{$unit_id}++) {
            push @$errors, "Plot $unit->{plot_name} is listed more than once.";
            next;
        }
        if (!defined($unit->{stock_id})) {
            push @$errors, "Plot $unit->{plot_name} is linked to ".($unit->{stock_count} // 0)." stocks; it must be linked to exactly one.";
            next;
        }
        if (defined($change->{old_stock_id}) && $change->{old_stock_id} =~ /^\d+$/ && $change->{old_stock_id} != $unit->{stock_id}) {
            push @$errors, "Plot $unit->{plot_name} was changed by someone else in the meantime (it has $unit->{stock_name} now); nothing was changed.";
            next;
        }
        my @unsupported = grep {exists($change->{$_})} qw(not_planted rejected reject_reason);
        if (@unsupported) {
            push @$errors, "Unsupported correction field(s): ".join(', ', @unsupported).".";
            next;
        }
        if (defined($change->{seedlot_name}) && $change->{seedlot_name} =~ /\S/) {
            if ($self->_is_plate) {
                push @$errors, "Wells of a genotyping plate have no seedlots here.";
                next;
            }
            ($seedlot_name{$unit_id} = $change->{seedlot_name}) =~ s/^\s+|\s+$//g;
        }
        my $new_stock_id = $change->{new_stock_id};
        if ((!defined($new_stock_id) || $new_stock_id eq '') && defined($change->{new_stock_name}) && $change->{new_stock_name} =~ /\S/) {
            (my $name = $change->{new_stock_name}) =~ s/^\s+|\s+$//g;
            if ($stocks->{ambiguous_names}->{$name}) {
                push @$errors, "More than one active stock is named $name; choose an unambiguous stock.";
                next;
            }
            if (!$stocks->{by_name}->{$name}) {
                push @missing_stocks, $name;
                next;
            }
            $new_stock_id = $stocks->{by_name}->{$name}->{stock_id};
        }
        if ((!defined($new_stock_id) || $new_stock_id eq '') && ((defined($change->{new_plot_name}) && $change->{new_plot_name} =~ /\S/) || exists($seedlot_name{$unit_id}))) {
            $new_stock_id = $unit->{stock_id};   # only the explicit name or seedlot changes
        }
        my $new_stock = (defined($new_stock_id) && $new_stock_id =~ /^\d+$/) ? $stocks->{by_id}->{$new_stock_id} : undef;
        if (!$new_stock) {
            push @$errors, "The new stock for plot $unit->{plot_name} does not exist.";
            next;
        }
        # a plot that keeps its stock keeps it, whatever has become of the stock since
        if ($new_stock_id != $unit->{stock_id}) {
            if ($new_stock->{is_obsolete}) {
                push @$errors, "Stock $new_stock->{uniquename} is obsolete.";
                next;
            }
            if (!$allowed_type{ $new_stock->{type_id} }) {
                push @$errors, "Stock $new_stock->{uniquename} is not ".stock_type_description(@$allowed_types).".";
                next;
            }
        }
        if (defined($change->{new_plot_name}) && $change->{new_plot_name} =~ /\S/) {
            if ($self->_is_plate) {
                push @$errors, "Wells of a genotyping plate cannot be renamed here.";
                next;
            }
            (my $name = $change->{new_plot_name}) =~ s/^\s+|\s+$//g;
            if ($name ne $unit->{plot_name}) {
                $explicit_name{$unit_id} = $name;
            } else {
                $keep_name{$unit_id} = 1;
            }
        }
        if ($new_stock_id == $unit->{stock_id}) {
            push @{$plan{unchanged}}, $unit->{plot_name} if !exists($explicit_name{$unit_id});
            next;
        }
        $new_stock_by_unit{$unit_id} = $new_stock_id;
        push @{$plan{changes}}, {
            plot_id => $unit_id + 0,
            plot_name => $unit->{plot_name},
            old_stock_id => $unit->{stock_id} + 0,
            old_stock_name => $unit->{stock_name},
            new_stock_id => $new_stock_id + 0,
            new_stock_name => $new_stock->{uniquename},
        };
    }
    if (@missing_stocks) {
        my %seen;
        my @missing = grep { !$seen{$_}++ } @missing_stocks;
        push @$errors, @missing == 1 ? "Could not find $missing[0] in the database." : "The following accessions were not found in the database: ".join(", ", @missing).".";
    }
    return \%plan if @$errors;

    # the state after the change
    my %after = map { $_ => { %{$units->{$_}} } } keys %$units;
    foreach my $unit_id (keys %new_stock_by_unit) {
        $after{$unit_id}->{stock_id} = $new_stock_by_unit{$unit_id};
        $after{$unit_id}->{stock_name} = $stocks->{by_id}->{ $new_stock_by_unit{$unit_id} }->{uniquename};
    }
    # An occurrence is an accession's position count, not a design factor.
    # Normalize the whole trial on membership changes: otherwise untouched
    # legacy group labels could remain mixed with modern occurrence numbers.
    my %new_replicate;
    if (!$self->_is_plate && (@{$plan{changes}} || $options->{normalize_occurrences})) {
        if (!$ids->{design_replicate} || !$ids->{occurrence_version}) {
            push @$errors, 'Run AddDesignReplicationStockprop before normalizing field accession occurrences.';
            return \%plan;
        }
        for my $unit (values %after) {
            if (!defined($unit->{stock_id})) {
                push @$errors, "Plot $unit->{plot_name} has no unambiguous accession; its occurrence cannot be normalized.";
            }
            if (@{$unit->{field_projects} || []} != 1) {
                push @$errors, "Plot $unit->{plot_name} must belong to exactly one field layout before occurrence normalization.";
            }
        }
        return \%plan if @$errors;
        $plan{_normalize_occurrences}=1;
        my %stocks = map {$_->{stock_id}=>1} values %after;
        for my $stock_id (sort {$a<=>$b} keys %stocks) {
            my @plots=sort {_compare_plot_numbers($a->{plot_number},$b->{plot_number}) || $a->{plot_id}<=>$b->{plot_id}}
                grep {$_->{stock_id}==$stock_id} values %after;
            my $number=0;
            for my $plot (@plots) {
                ++$number;
                if (!defined($plot->{replicate}) || $plot->{replicate} ne "$number") {
                    push @{$plan{replicates}},{plot_id=>$plot->{plot_id}+0,plot_name=>$plot->{plot_name},old=>$plot->{replicate},new=>$number};
                    $new_replicate{$plot->{plot_id}}=$number;
                    $plot->{replicate}=$number;
                }
            }
        }
        @{$plan{replicates}}=sort {$a->{plot_id}<=>$b->{plot_id}} @{$plan{replicates}};
    }

    # new plot names
    my %new_name = %explicit_name;
    if ($rename_mode eq 'auto' && !$self->_is_plate) {
        my $template = $self->plot_name_template();
        my %touched = (%new_stock_by_unit, %new_replicate);
        foreach my $unit_id (sort { $a <=> $b } keys %touched) {
            next if exists($new_name{$unit_id}) || $keep_name{$unit_id};
            my $unit = $units->{$unit_id};
            if ($template) {
                my $name = $self->_template_name($template, $after{$unit_id});
                if (!length($name)) {
                    push @{$plan{not_renamed}}, { plot_name => $unit->{plot_name}, reason => "the plot name template gives an empty name" };
                } elsif ($name ne $unit->{plot_name}) {
                    $new_name{$unit_id} = $name;
                }
            } elsif (exists($new_stock_by_unit{$unit_id})) {
                my ($name, $reason) = replace_name_part($unit->{plot_name}, $unit->{stock_name}, $after{$unit_id}->{stock_name});
                if (defined($reason)) {
                    push @{$plan{not_renamed}}, { plot_name => $unit->{plot_name}, reason => $reason };
                } elsif ($name ne $unit->{plot_name}) {
                    $new_name{$unit_id} = $name;
                }
            }
        }
    }

    $self->_plan_checks(\%plan, $units, \%after) if !$self->_is_plate;
    $self->_plan_design_warnings(\%plan, $units, \%after) if !$self->_is_plate && @{$plan{changes}};

    # the units' own samples, and samples of them in other trials; _execute takes them from the plan
    my %touched_unit = map { $_ => 1 } keys %new_stock_by_unit, keys %new_name, map { $_->{plot_id} } @{$plan{replicates}}, @{$plan{checks}};
    my $children = $self->_is_plate ? {} : $self->_children([ $plan{_normalize_occurrences} ? keys(%$units) : keys(%touched_unit) ]);
    $plan{_children} = $children;

    if ($plan{_normalize_occurrences}) {
        my %initial = map {$_=>$units->{$_}{design_replicate}} keys %$units;
        my %field_children;
        for my $parent (keys %$children) {
            $field_children{$_->{stock_id}}=$_ for @{$children->{$parent}{in_trial} || []};
        }
        for my $child (values %field_children) {
            push @$errors,"Unit $child->{name} belongs to multiple field layouts; review its study membership before normalizing accession occurrences."
                if @{$child->{field_projects}}!=1;
        }
        return \%plan if @$errors;
        my %roots = map {$_=>1} map {@{$_->{plot_parents}}} values %field_children;
        my $groups = CXGN::Trial::DesignReplication::read($schema,[keys %roots]);
        for my $id (keys %field_children) {
            my $child=$field_children{$id};
            my %tags=map {my $value=$groups->{$_}{value}; (defined($value) ? 'V'.$value : 'N')=>1} @{$child->{plot_parents}};
            my $single_layout=@{$child->{field_projects}}==1 && $child->{field_projects}[0]==$self->trial_id;
            for my $root (@{$child->{plot_parents}}) {
                $single_layout=0 if @{$groups->{$root}{field_projects}}!=1 || $groups->{$root}{field_projects}[0]!=$self->trial_id;
            }
            $initial{$id}=keys(%tags)==1 && $single_layout ? $groups->{$child->{plot_parents}[0]}{value} : undef;
        }
        my @snapshot_ids=sort {$a<=>$b} keys %initial;
        my $snapshot=CXGN::Trial::DesignReplication::read($schema,\@snapshot_ids);
        $plan{_design_before_json}=JSON->new->canonical->encode($snapshot);
        $plan{_design_stock_ids}=\@snapshot_ids;
        $plan{_design_initial_values}=\%initial;
        # Normalize descendants even when the parent's number already matched.
        # A pooled unit has no single plot occurrence, including equal-numbered
        # parents. Preserve that ambiguity instead of letting the last write win.
        my %desired=map {$_=>$after{$_}{replicate}} keys %after;
        for my $id (keys %field_children) {
            my $child=$field_children{$id};
            my @parents=@{$child->{plot_parents}};
            $desired{$id}=@parents==1 && exists($after{$parents[0]}) && @{$child->{field_projects}}==1
                ? $after{$parents[0]}{replicate} : undef;
        }
        $plan{_occurrence_updates}=[map {{stock_id=>$_+0,value=>$desired{$_}}}
            grep {defined($desired{$_}) != defined($snapshot->{$_}{occurrence_raw}) ||
                  (defined($desired{$_}) && $desired{$_} ne $snapshot->{$_}{occurrence_raw})}
            sort {$a<=>$b} keys %desired];
    }
    $self->_plan_child_identities(\%plan,$children,\%new_stock_by_unit,$self->_final_stock_by_plot) if @{$plan{changes}} && !$self->_is_plate;

    # renames of the plots and of their plants, subplots and tissue samples
    foreach my $unit_id (sort { $a <=> $b } keys %new_name) {
        my $old = $units->{$unit_id}->{plot_name};
        my $new = $new_name{$unit_id};
        push @{$plan{renames}}, { stock_id => $unit_id + 0, type => 'plot', old_name => $old, new_name => $new };
        foreach my $child (@{ $children->{$unit_id}->{in_trial} || [] }) {
            next if index($child->{name}, $old) != 0;
            push @{$plan{renames}}, { stock_id => $child->{stock_id} + 0, type => $child->{type}, old_name => $child->{name}, new_name => $new.substr($child->{name}, length($old)) };
        }
    }
    $self->_check_new_names($plan{renames}, $errors);
    # labels in the field and files with the old names would point to the other plot
    my %plot_named = map { $_->{plot_name} => $_->{plot_id} } values %$units;
    my @taken_names = grep { $_->{type} eq 'plot' && exists($plot_named{ $_->{new_name} }) && $plot_named{ $_->{new_name} } != $_->{stock_id} } @{$plan{renames}};
    if (@taken_names) {
        push @{$plan{warnings}}, scalar(@taken_names)." plot(s) get a name that another plot has now (for example $taken_names[0]->{old_name} gets the name $taken_names[0]->{new_name}): labels and files with the old names would point to the wrong plot. Keep the plot names if labels are in the field or data was collected with them.";
    }

    # warnings
    foreach my $c (@{$plan{changes}}) {
        my $external = $children->{ $c->{plot_id} }->{external} || [];
        if (@$external) {
            push @{$plan{warnings}}, scalar(@$external)." sample(s) of plot $c->{plot_name} in other trials (for example ".$external->[0]->{name}.") get $c->{new_stock_name} too.";
            push @{$plan{external_samples}}, map { { plot_name => $c->{plot_name}, stock_id => $_->{stock_id} + 0, name => $_->{name} } } @$external;
        }
    }
    if (!$self->_is_plate) {
        $self->_plan_phenotype_and_cross_warnings(\%plan, $children, \%after);
        $self->_plan_seedlots(\%plan, $units, \%after, \%seedlot_name, $options);
        my %extra_seed_units;
        foreach my $packet (@{$plan{seedlots}}) {
            foreach my $id ($packet->{plot_id}, $packet->{from_plot_id}) {
                next if !defined($id) || !$units->{$id};
                $extra_seed_units{$id} = 1 if !$touched_unit{$id};
                $touched_unit{$id} = 1;
            }
        }
        if (%extra_seed_units) {
            my $extra = $self->_children([keys %extra_seed_units]);
            $children->{$_} = $extra->{$_} for keys %$extra;
        }
        my %seedlot_changed = map { $_->{plot_name} => 1 } @{$plan{seedlots}};
        $plan{unchanged} = [ grep { !$seedlot_changed{$_} } @{$plan{unchanged}} ];
    }
    my %affected_stock = map { $_ => 1 } keys %touched_unit;
    foreach my $parent_id (keys %$children) {
        $affected_stock{$_->{stock_id}} = 1 for @{$children->{$parent_id}->{in_trial} || []}, @{$children->{$parent_id}->{external} || []};
    }
    if (@{$plan{changes}}) {
        for my $parent (keys %$children) {
            for my $child (@{$children->{$parent}{in_trial} || []},@{$children->{$parent}{external} || []}) {
                $affected_stock{$_}=1 for @{$child->{plot_parents} || []};
            }
        }
    }
    my $affected_projects = keys(%affected_stock) ? $schema->storage->dbh->selectcol_arrayref('SELECT DISTINCT nep.project_id FROM nd_experiment_stock nes JOIN nd_experiment_project nep USING(nd_experiment_id) WHERE nes.stock_id = ANY(?)', undef, [keys %affected_stock]) : [];
    my %affected_project = map {$_ => 1} @$affected_projects;
    $affected_project{$self->trial_id} = 1;
    $plan{affected_project_ids} = [ sort { $a <=> $b } keys %affected_project ];
    $plan{affected_plots} = [ sort map { $units->{$_}->{plot_name} } grep { $units->{$_} } keys %touched_unit ];

    # what only a curator may change: the samples in other trials belong to trials whose rights are
    # not checked here, and the layout check of the trial page does not see high-dimensional data
    if (defined($options->{curator}) && !$options->{curator}) {
        if (@{$plan{external_samples}}) {
            my $first = $plan{external_samples}->[0];
            push @$errors, scalar(@{$plan{external_samples}})." sample(s) in other trials were taken from these plots (for example $first->{name} from plot $first->{plot_name}); they would get the new accession too, so only a curator can make this change.";
        }
        if ($plan{plots_with_phenotypes}) {
            push @$errors, "$plan{plots_with_phenotypes} plot(s) already have phenotypes or high-dimensional data (NIRS, transcriptomics, metabolomics); only a curator can change their accession.";
        }
    }
    if (!$self->_is_plate) {
        my $intercropped = $self->_intercropped([ keys %new_stock_by_unit ]);
        foreach my $unit_id (keys %new_stock_by_unit) {
            if ($intercropped->{$unit_id}->{ $new_stock_by_unit{$unit_id} }) {
                push @$errors, "Plot $units->{$unit_id}->{plot_name} already has ".$after{$unit_id}->{stock_name}." as an intercrop.";
            }
        }
    }

    # entry numbers
    $self->_plan_entry_numbers(\%plan, $units, \%after);

    return \%plan;
}

=head2 apply($changes, $options)

Plans the changes (see plan()) and carries them out in one transaction. Dies
with the errors of the plan, or with a database error; nothing is changed
then. With the option plan_digest (from the summary of a preview) it also
dies when the plan is not the one of the preview any more, for example
because someone changed the trial in between. Returns the plan.

The trial is locked for other calls of apply() (an advisory lock on the
trial id) until the transaction ends: two corrections at the same time
would each be planned on the trial as it was before the other.

=cut

# Only an explicit transaction reassignment changes lot totals. Packet moves
# within a lot retain their signed quantities and need no inventory recount.
sub _recount_seedlot_ids {
    my ($plan)=@_;
    my %ids;
    for my $transaction (@{$plan->{seedlots} || []}) {
        next if $transaction->{type} ne 'seedlot';
        $ids{$_}=1 for grep {defined($_)} @{$transaction}{qw(old_seedlot_id seedlot_id)};
    }
    return [sort {$a<=>$b} keys %ids];
}

=head2 seedlot_ids_for_plan($plan)

Return the canonical lot union for every packet mutation, including self-lot
restoration/taken metadata edits. This is the lock scope, not just lots whose
cached quantity changes. Callers use it before observation/relationship locks.

=cut

sub seedlot_ids_for_plan {
    my ($self,$plan)=@_;
    my %ids;
    for my $transaction (@{$plan->{seedlots} || []}) {
        $ids{$_}=1 for grep {defined($_)} @{$transaction}{qw(old_seedlot_id seedlot_id)};
    }
    return [sort {$a<=>$b} keys %ids];
}

sub apply {
    my $self = shift;
    my $changes = shift;
    my $options = shift || {};
    my $schema = $self->schema;
    my $plan;
    $schema->txn_do(sub {
        my $initial=$self->plan($changes,$options);
        my %locked=map {$_=>1} @{$initial->{affected_project_ids} || []},$self->trial_id;
        if (defined($self->_locked_projects)) {
            die "The correction's project membership changed while locking the batch; retry the request.\n"
                if grep {!$self->_locked_projects->{$_}} keys %locked;
        } else {
            for my $project (sort {$a<=>$b} keys %locked) {
                $schema->storage->dbh->selectrow_array('SELECT project_id FROM project WHERE project_id=? FOR UPDATE',undef,$project);
            }
        }
        $schema->storage->dbh->do("SELECT pg_advisory_xact_lock(hashtext('CXGN::Trial::AccessionChange'), ?)",undef,$self->trial_id);
        my %locked_lot;
        if (defined($self->_locked_seedlots)) {
            %locked_lot=%{$self->_locked_seedlots};
            die "The correction's packet lots changed while locking the batch; retry its preview.\n"
                if grep {!$locked_lot{$_}} @{$self->seedlot_ids_for_plan($initial)};
        } else {
            my $locked_lots=CXGN::Stock::Seedlot::lock_for_recount($schema,$self->seedlot_ids_for_plan($initial));
            %locked_lot=map {$_=>1} @$locked_lots;
        }
        $plan=$self->plan($changes,$options);
        die "A planting transaction changed its seedlot while the correction was locked; retry its preview.\n"
            if grep {!$locked_lot{$_}} @{$self->seedlot_ids_for_plan($plan)};
        die "The layout membership changed while locking the correction; retry its preview.\n"
            if grep {!$locked{$_}} @{$plan->{affected_project_ids} || []};
        if (@{$plan->{errors}}) {
            die join("\n", @{$plan->{errors}})."\n";
        }
        if (defined($options->{plan_digest}) && length($options->{plan_digest}) && $options->{plan_digest} ne $self->plan_digest($plan)) {
            die "The trial changed after the preview, so the changes are not the ones you saw; check them again.\n";
        }
        $self->_execute($plan);
    });
    return $plan;
}

=head2 plan_digest($plan)

A digest of what a plan changes, to make sure that apply() carries out the
plan the user saw in a preview. It names the old stock of every plot too: a
plot that someone else changed after the preview would get the new stock
with the same plan otherwise, and that change would be lost unseen.

=cut

sub plan_digest {
    my $self = shift;
    my $plan = shift;
    my $to_delete = $plan->{phenotypes_to_delete} || {};
    my @parts = (
        "before units ".($plan->{_before_units_json} // ''),
        "before seeds ".JSON->new->canonical->encode($plan->{_seedlot_before} || []),
        "before design replication ".($plan->{_design_before_json} // ''),
        "normalize occurrences ".($plan->{_normalize_occurrences} ? 1 : 0),
        "child identities ".JSON->new->canonical->encode($plan->{_child_identities} || []),
        (map { "change $_->{plot_id} $_->{old_stock_id} $_->{new_stock_id}" } @{$plan->{changes}}),
        (map { "replicate $_->{plot_id} $_->{new}" } @{$plan->{replicates}}),
        (map { "rename $_->{stock_id} $_->{old_name} $_->{new_name}" } @{$plan->{renames}}),
        (map { "check $_->{plot_id} $_->{new}" } @{$plan->{checks}}),
        (map { "entry $_->{stock_id} $_->{entry_number}" } @{$plan->{entry_numbers}}),
        (map { "seedlot $_->{type} $_->{transaction_id} $_->{plot_id} $_->{seedlot_id}" } @{$plan->{seedlots}}),
        (map { "delete phenotype $_" } @{ $to_delete->{phenotype_ids} || [] }),
        (map { "delete experiment $_" } @{ $to_delete->{nd_experiment_ids} || [] }),
    );
    return md5_hex(encode_utf8(join("\n", sort @parts)));
}

sub _execute {
    my $self = shift;
    my $plan = shift;
    my $dbh = $self->schema->storage->dbh;
    my $ids = $self->_cvterm_ids;
    my $legacy_delete = $plan->{phenotypes_to_delete} || {};
    die "Raw observations cannot be deleted by an accession correction.\n"
        if @{$legacy_delete->{phenotype_ids} || []} || @{$legacy_delete->{nd_experiment_ids} || []};

    # stocks of the units and of their plants, subplots and tissue samples, also the samples in other trials;
    # the replicates and check marks of this trial are only for the children in this trial
    my $children = $plan->{_children} // ($self->_is_plate ? {} : $self->_children([ map { $_->{plot_id} } @{$plan->{changes}}, @{$plan->{replicates}}, @{$plan->{checks}} ]));
    my $children_of = sub { return [ map { $_->{stock_id} } @{ $children->{ $_[0] }->{in_trial} || [] } ]; };
    if ($plan->{_normalize_occurrences}) {
        CXGN::Trial::DesignReplication::capture($self->schema,$plan->{_design_stock_ids},$plan->{_design_initial_values});
    }
    my @external_ids;
    my $unit_h = $dbh->prepare("UPDATE stock_relationship SET object_id = ? WHERE subject_id = ? AND object_id = ? AND type_id = ?");
    foreach my $c (@{$plan->{changes}}) {
        my $rows = $unit_h->execute($c->{new_stock_id}, $c->{plot_id}, $c->{old_stock_id}, $self->_unit_relationship_id);
        if ($rows != 1) {
            die "Plot $c->{plot_name} was changed by someone else in the meantime; nothing was changed.\n";
        }
        my @external = map { $_->{stock_id} } @{ $children->{ $c->{plot_id} }->{external} || [] };
        push @external_ids, @external;
    }

    # Resolve the validated final source identity once per descendant. Mixed
    # final identities were refused before any write to this transaction.
    for my $child (@{$plan->{_child_identities} || []}) {
        my %wanted=map {$_=>1} @{$child->{after}};
        my $rows=$self->schema->resultset('Stock::StockRelationship')->search({
            subject_id=>$child->{stock_id},type_id=>$child->{type_id},object_id=>{in=>[ @{$child->{before}}, @{$child->{after}} ]},
        });
        my (%existing,@obsolete);
        while (my $row=$rows->next) {
            if ($wanted{$row->object_id}) {$existing{$row->object_id}=1}
            else {push @obsolete,$row}
        }
        my @missing=grep {!$existing{$_}} @{$child->{after}};
        while (@obsolete && @missing) {
            my $row=shift @obsolete;
            $row->update({object_id=>shift @missing});
        }
        $_->delete for @obsolete;
        for my $stock_id (@missing) {
            $self->schema->resultset('Stock::StockRelationship')->create({subject_id=>$child->{stock_id},object_id=>$stock_id,type_id=>$child->{type_id},rank=>0});
        }
    }

    # seed transactions follow the packets (see _plan_seedlots)
    if (@{$plan->{seedlots}}) {
        my $seed_transaction = $ids->{seed_transaction};
        my $rank_h = $dbh->prepare("SELECT COALESCE(MAX(rank), -1) + 1 FROM stock_relationship WHERE subject_id = ? AND object_id = ? AND type_id = ?");
        my $next_rank = sub { $rank_h->execute(@_, $seed_transaction); return ($rank_h->fetchrow_array())[0]; };
        my $value_h = $dbh->prepare("SELECT value FROM stock_relationship WHERE stock_relationship_id = ?");
        my $update_h = $dbh->prepare("UPDATE stock_relationship SET subject_id = ?, object_id = ?, rank = ?, value = COALESCE(?, value)
            WHERE stock_relationship_id = ? AND subject_id = ? AND object_id = ? AND type_id = ?");
        my %recount=map {$_=>1} @{_recount_seedlot_ids($plan)};
        foreach my $s (@{$plan->{seedlots}}) {
            my ($subject, $object, $value) = ($s->{plot_id}, $s->{seedlot_id}, undef);
            my ($old_subject, $old_object) = ($s->{plot_id}, $s->{seedlot_id});
            if ($s->{type} eq 'move') {
                $old_subject = $s->{from_plot_id};
            } elsif ($s->{type} eq 'restore') {
                # seed taken back to the plot it was linked to, as it was before
                $old_subject = $s->{seedlot_id};
                $value_h->execute($s->{transaction_id});
                my ($json) = $value_h->fetchrow_array();
                my $v = decode_stored_json($json // '{}');
                my $taken = delete($v->{taken}) || {};
                foreach my $key ('factor', 'description') {
                    if (defined($taken->{$key})) { $v->{$key} = $taken->{$key}; } else { delete $v->{$key}; }
                }
                $value = encode_json($v);
            } elsif ($s->{type} eq 'seedlot') {
                $old_object = $s->{old_seedlot_id};
            } else {
                # seed taken from the seedlot: a transaction from the seedlot to itself
                $subject = $s->{seedlot_id};
                $value_h->execute($s->{transaction_id});
                my ($json) = $value_h->fetchrow_array();
                # the amount must stay, or the inventory would change
                my $v = decode_stored_json($json // '{}');
                # what it was, so that it can go back to the plot if a later correction plants it there
                $v->{taken} = { plot_id => $s->{plot_id} + 0, factor => $v->{factor}, description => $v->{description} };
                $v->{factor} = -1;
                $v->{description} = join(' ', grep { defined($_) && length($_) } $v->{description}, "(Correction of trial ".$self->_trial_name.": no plot has this packet; it was linked to plot $s->{plot_name}.)");
                $value = encode_json($v);
            }
            my $rows = $update_h->execute($subject, $object, $next_rank->($subject, $object), $value, $s->{transaction_id}, $old_subject, $old_object, $seed_transaction);
            if ($rows != 1) {
                die "The seed transaction of plot ".($s->{from_plot_name} // $s->{plot_name})." was changed by someone else in the meantime; nothing was changed.\n";
            }
        }
        foreach my $seedlot_id (sort { $a <=> $b } keys %recount) {
            my $seedlot = CXGN::Stock::Seedlot->new(schema => $self->schema, seedlot_id => $seedlot_id);
            $seedlot->recalculate_current_properties();
        }
    }

    # Upsert only changed values, including missing child counters and explicit
    # NULL for pooled descendants. External studies keep their local metadata.
    for my $update (@{$plan->{_occurrence_updates} || []}) {
        $self->schema->resultset('Stock::Stockprop')->search({stock_id=>$update->{stock_id},type_id=>$ids->{replicate}})->delete;
        $self->schema->resultset('Stock::Stockprop')->create({stock_id=>$update->{stock_id},type_id=>$ids->{replicate},value=>$update->{value},rank=>0});
    }
    CXGN::Trial::DesignReplication::mark_occurrences_ready($self->schema,$self->trial_id) if $plan->{_normalize_occurrences};

    # check marks of the plots, and of their plants, subplots and tissue samples that have one
    # (plants are created without one, so a plant without a mark stays without)
    my $uncheck_h = $dbh->prepare("DELETE FROM stockprop WHERE stock_id = ANY(?) AND type_id = ?");
    my $check_children_h = $dbh->prepare("UPDATE stockprop SET value = '1' WHERE stock_id = ANY(?) AND type_id = ?");
    foreach my $k (@{$plan->{checks}}) {
        my $child_ids = $children_of->($k->{plot_id});
        $uncheck_h->execute([ $k->{plot_id}, ($k->{new} ? () : @$child_ids) ], $ids->{is_a_control});
        if ($k->{new}) {
            $self->schema->resultset('Stock::Stockprop')->create({ stock_id => $k->{plot_id}, type_id => $ids->{is_a_control}, value => '1', rank => 0 });
            $check_children_h->execute($child_ids, $ids->{is_a_control}) if @$child_ids;
        }
    }

    # two passes, so that a new name may be one that another renamed stock has now
    my $rename_h = $dbh->prepare("UPDATE stock SET uniquename = ?, name = ? WHERE stock_id = ? AND uniquename = ?");
    foreach my $r (@{$plan->{renames}}) {
        my $temporary = "__accession_change_".$r->{stock_id}."_".$$;
        my $rows = $rename_h->execute($temporary, $temporary, $r->{stock_id}, $r->{old_name});
        if ($rows != 1) {
            die "$r->{old_name} was renamed by someone else in the meantime; nothing was changed.\n";
        }
        $r->{_temporary} = $temporary;
    }
    foreach my $r (@{$plan->{renames}}) {
        $rename_h->execute($r->{new_name}, $r->{new_name}, $r->{stock_id}, delete $r->{_temporary});
    }

    if (@{$plan->{entry_numbers}}) {
        my $map = $self->_entry_number_map() || {};
        foreach my $e (@{$plan->{entry_numbers}}) {
            delete $map->{ $e->{from_stock_id} };
            $map->{ $e->{stock_id} } = $e->{entry_number};
        }
        my $row = $self->schema->resultset('Project::Projectprop')->find({ project_id => $self->trial_id, type_id => $ids->{entry_numbers} });
        $row->update({ value => encode_json($map) });
    }

    if ($plan->{_normalize_occurrences} || @{$plan->{changes}} || @{$plan->{replicates}} || @{$plan->{renames}} || @{$plan->{checks}} || @{$plan->{seedlots}}) {
        my $layout = CXGN::Trial::TrialLayout->new({
            schema => $self->schema,
            trial_id => $self->trial_id,
            experiment_type => $self->experiment_type,
        });
        $layout->generate_and_cache_layout();
    }
    # the other trials (genotyping plates, sampling trials) with samples of the changed plots
    my $other_layouts = @external_ids ? $self->_layout_projects(\@external_ids) : {};
    foreach my $project_id (sort { $a <=> $b } keys %$other_layouts) {
        next if $project_id == $self->trial_id;
        CXGN::Trial::TrialLayout->new({
            schema => $self->schema,
            trial_id => $project_id,
            experiment_type => $other_layouts->{$project_id},
        })->generate_and_cache_layout();
    }
}

=head2 stock_type_description(@stock_types)

'an accession', 'a cross or a family name', ...; 'an accession, cross or family name' without types.

=cut

sub stock_type_description {
    my @stock_types = grep { defined && length } @_;
    my %description = ( accession => 'an accession', cross => 'a cross', family_name => 'a family name' );
    my @descriptions = map { $description{$_} // $_ } @stock_types;
    return @descriptions ? join(' or ', @descriptions) : 'an accession, cross or family name';
}

=head2 replace_name_part($name, $old_part, $new_part)

Replaces $old_part by $new_part in $name where it is a whole part of the name:
at the start or after "-" or "_", and at the end or before "-" or "_". Returns
the new name (the same name when it has no such part), or (undef, reason) when
it has that part more than once.

=cut

sub replace_name_part {
    my ($name, $old_part, $new_part) = @_;
    return ($name) if !defined($old_part) || !length($old_part);
    my @positions;
    while ($name =~ /(?:^|(?<=[-_]))\Q$old_part\E(?=[-_]|$)/g) {
        push @positions, $-[0];
        pos($name) = $-[0] + 1;
    }
    return ($name) if !@positions;
    return (undef, "the plot name contains $old_part more than once") if @positions > 1;
    substr($name, $positions[0], length($old_part)) = $new_part;
    return ($name);
}

=head2 design_type()

The design of the trial ('CRD', 'RCBD', ...), or undef.

=cut

sub design_type {
    my $self = shift;
    my $row = $self->schema->resultset('Project::Projectprop')->find({ project_id => $self->trial_id, type_id => $self->_cvterm_ids->{design} });
    return $row ? $row->value : undef;
}

=head2 plot_name_template()

The name attributes of the trial's plot name template, or undef.

=cut

sub plot_name_template {
    my $self = shift;
    my $type_id = $self->_cvterm_ids->{plot_name_template} or return;
    my $row = $self->schema->resultset('Project::Projectprop')->find({ project_id => $self->trial_id, type_id => $type_id });
    return if !$row;
    my $template = try { decode_json($row->value) } catch { undef };
    return if ref($template) ne 'HASH';
    my ($format) = keys %$template;
    return if !$format || ref($template->{$format}) ne 'HASH';
    my $attributes = $template->{$format}->{name_attributes};
    return (ref($attributes) eq 'ARRAY' && @$attributes) ? $attributes : undef;
}

# the same as CXGN::Trial::TrialDesign::_build_plot_names
sub _template_name {
    my $self = shift;
    my $attributes = shift;
    my $unit = shift;
    my %source = (
        breedingProgram => $self->_breeding_program_name(),
        trialName       => $self->_trial_name(),
        accessionName   => $unit->{stock_name} // '',
        plotNumber      => $unit->{plot_number} // '',
        blockNumber     => $unit->{block} // '',
        repNumber       => $unit->{replicate} // '',
        rangeNumber     => $unit->{range} // '',
        rowNumber       => $unit->{row_number} // '',
        colNumber       => $unit->{col_number} // '',
    );
    return join('_', map { ref($_) eq 'HASH' ? ($_->{text} // '') : ($source{$_} // '') } @$attributes);
}

sub _build_trial_name {
    my $self = shift;
    return $self->schema->resultset('Project::Project')->find({ project_id => $self->trial_id })->name;
}

sub _build_breeding_program_name {
    my $self = shift;
    my $programs = CXGN::BreedersToolbox::Projects->new({ schema => $self->schema })->get_breeding_programs_by_trial($self->trial_id);
    return ($programs && $programs->[0]) ? ($programs->[0]->[1] // '') : '';
}

sub _compare_plot_numbers {
    my ($x, $y) = @_;
    $x //= '';
    $y //= '';
    if ($x =~ /^-?\d+(?:\.\d+)?$/ && $y =~ /^-?\d+(?:\.\d+)?$/) {
        return $x <=> $y;
    }
    return $x cmp $y;
}

# the trials, genotyping plates and sampling trials of the stocks: project_id => experiment type
sub _layout_projects {
    my $self = shift;
    my $stock_ids = shift;
    my $h = $self->schema->storage->dbh->prepare("SELECT DISTINCT nep.project_id, type.name
        FROM nd_experiment_stock nes
        JOIN nd_experiment e ON e.nd_experiment_id = nes.nd_experiment_id
        JOIN cvterm type ON type.cvterm_id = e.type_id
        JOIN nd_experiment_project nep ON nep.nd_experiment_id = nes.nd_experiment_id
        WHERE nes.stock_id = ANY(?) AND type.name IN ('field_layout', 'genotyping_layout', 'sampling_layout')");
    $h->execute($stock_ids);
    my %projects;
    while (my ($project_id, $type) = $h->fetchrow_array()) { $projects{$project_id} = $type; }
    return \%projects;
}

# plants, subplots and tissue samples of the units; in_trial are those that belong to this trial,
# external the samples in other trials (the wells of a genotyping plate made from the plants)
sub _children {
    my ($self,$unit_ids)=@_;
    return {} if !@$unit_ids;
    my $dbh=$self->schema->storage->dbh;
    my $rows=$dbh->selectall_arrayref(q{
        WITH RECURSIVE descendants(root_id, stock_id) AS (
            SELECT id,id FROM unnest(?::integer[]) id
          UNION
            SELECT d.root_id,child.stock_id FROM descendants d
            JOIN stock parent ON parent.stock_id=d.stock_id
            JOIN cvterm pt ON pt.cvterm_id=parent.type_id
            JOIN stock_relationship r ON
                (pt.name='plot' AND r.subject_id=d.stock_id) OR r.object_id=d.stock_id
            JOIN cvterm rt ON rt.cvterm_id=r.type_id
            JOIN stock child ON child.stock_id=CASE WHEN r.object_id=d.stock_id THEN r.subject_id ELSE r.object_id END
            JOIN cvterm ct ON ct.cvterm_id=child.type_id
            WHERE (pt.name='plot' AND r.subject_id=d.stock_id AND
                      ((rt.name='plant_of' AND ct.name='plant') OR (rt.name='subplot_of' AND ct.name='subplot')))
               OR (pt.name IN ('plot','plant','subplot','tissue_sample') AND r.object_id=d.stock_id AND
                      rt.name='tissue_sample_of' AND ct.name='tissue_sample')
        ) SELECT DISTINCT d.root_id,s.stock_id,s.uniquename,ct.name FROM descendants d
          JOIN stock s ON s.stock_id=d.stock_id JOIN cvterm ct ON ct.cvterm_id=s.type_id
          WHERE d.root_id<>d.stock_id ORDER BY d.root_id,s.stock_id
    },undef,$unit_ids);
    return {} if !@$rows;
    my %child_ids=map {$_->[1]=>1} @$rows;
    my $ancestors=$self->_plot_ancestors([keys %child_ids]);
    my $replication=CXGN::Trial::DesignReplication::read($self->schema,[keys %child_ids]);
    my %children;
    for my $row (@$rows) {
        my ($root,$id,$name,$type)=@$row;
        my @projects=@{$replication->{$id}{field_projects}};
        my $in_trial=grep {$_==$self->trial_id} @projects;
        push @{$children{$root}{$in_trial ? 'in_trial':'external'}},{
            stock_id=>$id,name=>$name,type=>$type,unit=>$root,
            plot_parents=>$ancestors->{$id} || [],field_projects=>\@projects,
        };
    }
    return \%children;
}

# Every plot source, including roots outside this trial, matters for a pool.
sub _plot_ancestors {
    my ($self,$stock_ids)=@_;
    return {} if !@$stock_ids;
    my $rows=$self->schema->storage->dbh->selectall_arrayref(q{
        WITH RECURSIVE ancestry(unit_id, stock_id) AS (
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
    },undef,$stock_ids);
    my %result;
    push @{$result{$_->[0]}},$_->[1] for @$rows;
    return \%result;
}

sub _plan_child_identities {
    my ($self,$plan,$children,$new_stock,$batch_stock)=@_;
    $batch_stock ||= {};
    my %affected;
    for my $parent (keys %$new_stock) {
        $affected{$_->{stock_id}}=$_ for @{$children->{$parent}{in_trial} || []},@{$children->{$parent}{external} || []};
    }
    return if !%affected;
    my %roots=map {$_=>1} map {@{$_->{plot_parents}}} values %affected;
    my $ids=$self->_cvterm_ids;
    my $rows=$self->schema->storage->dbh->selectall_arrayref(
        'SELECT r.subject_id,r.object_id FROM stock_relationship r JOIN stock s ON s.stock_id=r.object_id WHERE r.subject_id=ANY(?) AND r.type_id=? AND s.type_id=ANY(?)',
        undef,[keys %roots],$ids->{plot_of},$self->_primary_stock_type_ids);
    my %source;
    $source{$_->[0]}{$_->[1]}=1 for @$rows;
    my $identity_rows=$self->schema->storage->dbh->selectall_arrayref(
        'SELECT r.subject_id,r.object_id FROM stock_relationship r JOIN stock s ON s.stock_id=r.object_id WHERE r.subject_id=ANY(?) AND r.type_id=ANY(?) AND s.type_id=ANY(?) ORDER BY r.subject_id,r.object_id',
        undef,[keys %affected],[grep {defined} @{$ids}{qw(plant_of subplot_of tissue_sample_of)}],$self->_primary_stock_type_ids);
    my %before_by_child;
    $before_by_child{$_->[0]}{$_->[1]}=1 for @$identity_rows;
    my @changes;
    for my $id (sort {$a<=>$b} keys %affected) {
        my $child=$affected{$id};
        my %final;
        for my $root (@{$child->{plot_parents}}) {
            if (keys(%{$source{$root} || {}})!=1) {
                push @{$plan->{errors}},"Sample $child->{name} has a source plot with ambiguous accession membership; correct the source layout first.";
                next;
            }
            my $final=exists($new_stock->{$root}) ? $new_stock->{$root}
                : exists($batch_stock->{$root}) ? $batch_stock->{$root} : (keys %{$source{$root}})[0];
            $final{$final}=1;
        }
        my $type=$ids->{$child->{type} eq 'plant' ? 'plant_of' : $child->{type} eq 'subplot' ? 'subplot_of':'tissue_sample_of'};
        my $before=[sort {$a<=>$b} keys %{$before_by_child{$id} || {}}];
        my @after=sort {$a<=>$b} keys %final;
        if (@after!=1) {
            push @{$plan->{errors}},"Pooled sample $child->{name} would have multiple germplasm identities. This layout and its BrAPI/analysis records require one germplasm per unit; review the sample provenance or correct its source plots together when they have one final identity.";
            next;
        }
        next if join(',',@$before) eq join(',',@after);
        push @changes,{stock_id=>$id,type_id=>$type,before=>$before,after=>\@after};
    }
    $plan->{_child_identities}=\@changes;
}

sub _intercropped {
    my $self = shift;
    my $unit_ids = shift;
    my %intercropped;
    my $type_id = $self->_cvterm_ids->{intercrop_plot_of};
    return \%intercropped if !@$unit_ids || !$type_id;
    my $h = $self->schema->storage->dbh->prepare("SELECT subject_id, object_id FROM stock_relationship WHERE subject_id = ANY(?) AND type_id = ?");
    $h->execute($unit_ids, $type_id);
    while (my ($unit_id, $stock_id) = $h->fetchrow_array()) { $intercropped{$unit_id}->{$stock_id} = 1; }
    return \%intercropped;
}

# new names must be unique among themselves and in the database, except for
# names that stocks renamed in this change have now
sub _check_new_names {
    my $self = shift;
    my $renames = shift;
    my $errors = shift;
    return if !@$renames;
    my %renamed_ids = map { $_->{stock_id} => 1 } @$renames;
    my %count;
    foreach my $r (@$renames) {
        if (!length($r->{new_name})) {
            push @$errors, "The new name of $r->{old_name} is empty.";
        }
        $count{ $r->{new_name} }++;
    }
    foreach my $name (sort grep { $count{$_} > 1 } keys %count) {
        push @$errors, "$count{$name} stocks would be named $name.";
    }
    my $h = $self->schema->storage->dbh->prepare("SELECT stock_id, uniquename FROM stock WHERE uniquename = ANY(?)");
    $h->execute([ keys %count ]);
    while (my ($stock_id, $name) = $h->fetchrow_array()) {
        next if $renamed_ids{$stock_id};
        push @$errors, "Plot name $name already exists in the database.";
    }
}

sub _entry_number_map {
    my $self = shift;
    my $type_id = $self->_cvterm_ids->{entry_numbers} or return;
    my $row = $self->schema->resultset('Project::Projectprop')->find({ project_id => $self->trial_id, type_id => $type_id });
    return if !$row;
    return try { decode_json($row->value) } catch { undef };
}

# An old stock that leaves the trial hands its entry number to the new stock
# that takes its plots, when that stock is new to the trial and has none.
sub _plan_entry_numbers {
    my $self = shift;
    my $plan = shift;
    my $units = shift;
    my $after = shift;
    return if $self->_is_plate || !@{$plan->{changes}};
    my $map = $self->_entry_number_map();
    return if ref($map) ne 'HASH' || !%$map;

    my %before_stocks = map { $_->{stock_id} => 1 } grep { defined $_->{stock_id} } values %$units;
    my %after_stocks = map { $_->{stock_id} => 1 } grep { defined $_->{stock_id} } values %$after;
    my %takers;   # old stock => { new stock => 1 }
    my %new_name;
    foreach my $c (@{$plan->{changes}}) {
        $takers{ $c->{old_stock_id} }->{ $c->{new_stock_id} } = 1;
        $new_name{ $c->{new_stock_id} } = $c->{new_stock_name};
    }
    my %given;
    foreach my $old (sort { $a <=> $b } keys %takers) {
        my @new = keys %{$takers{$old}};
        next if $after_stocks{$old} || !exists($map->{$old}) || @new != 1;
        my $new = $new[0];
        next if $before_stocks{$new} || exists($map->{$new}) || $given{$new}++;
        push @{$plan->{entry_numbers}}, { stock_id => $new + 0, stock_name => $new_name{$new}, entry_number => $map->{$old}, from_stock_id => $old + 0 };
    }
    foreach my $new (sort keys %new_name) {
        if (!exists($map->{$new}) && !$given{$new}) {
            push @{$plan->{warnings}}, "$new_name{$new} has no entry number in this trial.";
        }
    }
}

sub _is_true {
    my $value = shift;
    return (defined($value) && $value =~ /^\s*(1|true|yes|t|y)\s*$/i) ? 1 : 0;
}

# check marks: a plot is a check plot when its accession is a check accession of this trial
sub _plan_checks {
    my $self = shift;
    my $plan = shift;
    my $units = shift;
    my $after = shift;
    return if !@{$plan->{changes}};

    my (%total, %checked);
    foreach my $u (values %$units) {
        next if !defined($u->{stock_id});
        $total{ $u->{stock_id} }++;
        $checked{ $u->{stock_id} }++ if _is_true($u->{is_a_control});
    }
    my %after_stocks = map { $_->{stock_id} => 1 } grep { defined $_->{stock_id} } values %$after;
    my %takers;
    foreach my $c (@{$plan->{changes}}) {
        $takers{ $c->{old_stock_id} }->{ $c->{new_stock_id} } = 1;
    }
    my %mixed_warned;
    foreach my $c (@{$plan->{changes}}) {
        my $is_check = _is_true($units->{ $c->{plot_id} }->{is_a_control});
        my $new = $c->{new_stock_id};
        my $should_be_check;
        if ($total{$new}) {
            if (($checked{$new} // 0) == $total{$new}) {
                $should_be_check = 1;
            } elsif (!$checked{$new}) {
                $should_be_check = 0;
            } else {
                push @{$plan->{warnings}}, "$c->{new_stock_name} is a check on some plots of this trial and not on others, so the check marks of its new plots are left as they are." if !$mixed_warned{$new}++;
                next;
            }
        } elsif (!$after_stocks{ $c->{old_stock_id} } && scalar(keys %{ $takers{ $c->{old_stock_id} } }) == 1) {
            # the new accession takes the place of the old one everywhere
            $should_be_check = $is_check;
        } else {
            $should_be_check = 0;
        }
        if ($should_be_check != $is_check) {
            push @{$plan->{checks}}, { plot_id => $c->{plot_id}, plot_name => $c->{plot_name}, old => $is_check, new => $should_be_check };
        }
    }
}

# Warnings when the change breaks the design: an accession twice in a block of an RCBD (or in a
# replicate of an incomplete block design), accessions with unequal numbers of plots where they
# were equal, an accession without plots. The change is allowed: the preview shows the warnings
# before the user confirms. Check plots do not count in the biological design-balance warnings.
my %ONCE_PER_BLOCK = map { $_ => 'block' } qw(rcbd);
my %ONCE_PER_REPLICATE = map { $_ => 'replicate' } qw(alpha lattice rrc drrc);
my %NOT_BALANCED = map { $_ => 1 } qw(augmented mad madii madiii madiv greenhouse splitplot p-rep prep westcott urdd);
sub _plan_design_warnings {
    my $self = shift;
    my $plan = shift;
    my $units = shift;
    my $after = shift;
    my $design = lc($self->design_type // '');
    my %new_check = map { $_->{plot_id} => $_->{new} } @{$plan->{checks}};
    my $counted = sub {   # [ stock_id, block, replicate ] of the plots that count, before or after the change
        my ($state, $is_after) = @_;
        my @plots;
        foreach my $u (values %$state) {
            next if !defined($u->{stock_id});
            my $check = ($is_after && exists($new_check{ $u->{plot_id} })) ? $new_check{ $u->{plot_id} } : _is_true($u->{is_a_control});
            next if $check;
            push @plots, $u;
        }
        return \@plots;
    };
    my ($before, $now) = ($counted->($units, 0), $counted->($after, 1));
    my %changed = map { ($_->{old_stock_id} => 1, $_->{new_stock_id} => 1) } @{$plan->{changes}};
    my %name = map { ($_->{old_stock_id} => $_->{old_stock_name}, $_->{new_stock_id} => $_->{new_stock_name}) } @{$plan->{changes}};
    my $alternatives = "To keep the design, use an accession that is not in the trial yet or review the intended physical design before applying the correction.";
    my @warnings;

    # once per block (RCBD) or per replicate (alpha, lattice, row-column designs)
    my $unit_of_design = $ONCE_PER_BLOCK{$design} || $ONCE_PER_REPLICATE{$design};
    if ($unit_of_design) {
        my $key = $unit_of_design eq 'block' ? 'block' : 'design_replicate';
        my $twice = sub {
            my %n;
            foreach my $u (@{$_[0]}) { next if !defined($u->{$key}) || $u->{$key} eq ''; $n{ $u->{stock_id} }->{ $u->{$key} }++; }
            return { map { my $s = $_; ($s => [ grep { $n{$s}->{$_} > 1 } sort { $a <=> $b } keys %{$n{$s}} ]) } keys %n };
        };
        my ($twice_before, $twice_now) = ($twice->($before), $twice->($now));
        foreach my $stock_id (sort { ($name{$a} // '') cmp ($name{$b} // '') } grep { $changed{$_} } keys %$twice_now) {
            my %was = map { $_ => 1 } @{ $twice_before->{$stock_id} || [] };
            my @new = grep { !$was{$_} } @{ $twice_now->{$stock_id} };
            next if !@new;
            push @warnings, "$name{$stock_id} will be in more than one plot of $unit_of_design ".join(', ', @new).": in this design (".$self->design_type.") each accession is once in each $unit_of_design, so the analysis cannot separate it from the $unit_of_design effect there.";
        }
    }

    # equal numbers of plots per accession, counted over the planned plots (a plot that was not
    # planted is still a place of the design)
    my $count = sub {
        my ($state, $is_after) = @_;
        my %n;
        foreach my $u (values %$state) {
            next if !defined($u->{stock_id});
            next if ($is_after && exists($new_check{ $u->{plot_id} })) ? $new_check{ $u->{plot_id} } : _is_true($u->{is_a_control});
            $n{ $u->{stock_id} }++;
        }
        return \%n;
    };
    my ($n_before, $n_now) = ($count->($units, 0), $count->($after, 1));
    if ($design ne '' && !$NOT_BALANCED{$design}) {
        my %sizes = map { $_ => 1 } values %$n_before;
        if (scalar(keys %sizes) == 1) {
            my ($k) = keys %sizes;
            # more plots than the others: what the design cannot absorb (one plot fewer is a missing value)
            my @more = grep { $changed{$_} && $n_now->{$_} > $k } keys %$n_now;
            if (@more) {
                push @warnings, "Every accession had $k plot(s); after the change ".join(', ', map { "$name{$_} has ".$n_now->{$_} } sort { $name{$a} cmp $name{$b} } @more).". The design is no longer balanced, and analyses that assume it (replicates, blocks) are harder to interpret.";
            }
        }
    }
    # an accession that leaves the trial, in any design; not when all its plots go to accessions
    # that were not in the trial (Replace Accession by a new one keeps the design)
    my %in_trial_before = map { (defined($_->{stock_id}) ? ($_->{stock_id} => 1) : ()) } values %$units;
    my %went_to;
    foreach my $change (@{$plan->{changes}}) { $went_to{ $change->{old_stock_id} }->{ $change->{new_stock_id} } = 1; }
    my @gone = sort { $name{$a} cmp $name{$b} } grep { $changed{$_} && !$n_now->{$_} && grep({ $in_trial_before{$_} } keys %{ $went_to{$_} || {} }) } keys %$n_before;
    push @warnings, join(', ', map { $name{$_} } @gone)." will have no plot left in this trial." if @gone;
    if (@warnings) {
        push @{$plan->{warnings}}, map { "Design: $_" } @warnings;
        push @{$plan->{warnings}}, "Design: $alternatives";
    }
}

# the condition on nd_experiment_stock nes that the stock has a phenotype other than a treatment,
# or high-dimensional data (NIRS, transcriptomics, metabolomics)
sub _has_values_sql {
    return "(EXISTS (SELECT 1 FROM nd_experiment_phenotype nep JOIN phenotype p ON p.phenotype_id = nep.phenotype_id
                LEFT JOIN cvterm trait ON trait.cvterm_id = p.cvalue_id
                LEFT JOIN dbxref x ON x.dbxref_id = trait.dbxref_id
                LEFT JOIN db ON db.db_id = x.db_id
                WHERE nep.nd_experiment_id = nes.nd_experiment_id AND COALESCE(right(db.name, 10), '') <> '_TREATMENT')
            OR EXISTS (SELECT 1 FROM phenome.nd_experiment_md_json j WHERE j.nd_experiment_id = nes.nd_experiment_id))";
}

=head2 has_phenotypes()

Whether a plot of the trial, or a plant, subplot or tissue sample of one, has
a phenotype other than a treatment, or high-dimensional data: the values the
plan warns about. Data was collected with the plot names then, so the dialogs
keep the names by default.

=cut

sub has_phenotypes {
    my $self = shift;
    my @plot_ids = keys %{ $self->load_units() };
    return 0 if !@plot_ids;
    my $children = $self->_is_plate ? {} : $self->_children(\@plot_ids);
    my @stock_ids = (@plot_ids, map { map { $_->{stock_id} } @{ $children->{$_}->{in_trial} || [] } } @plot_ids);
    my ($found) = $self->schema->storage->dbh->selectrow_array("SELECT 1 FROM nd_experiment_stock nes WHERE nes.stock_id = ANY(?) AND "._has_values_sql." LIMIT 1", undef, \@stock_ids);
    return $found ? 1 : 0;
}

# phenotypes and crosses of the changed plots and of their plants, subplots and tissue samples
sub _plan_phenotype_and_cross_warnings {
    my $self = shift;
    my $plan = shift;
    my $children = shift;
    my $after = shift;
    my @plot_ids = map { $_->{plot_id} } @{$plan->{changes}};
    return if !@plot_ids;
    my $dbh = $self->schema->storage->dbh;
    my $ids = $self->_cvterm_ids;

    my %plot_of = map { $_ => $_ } @plot_ids;
    foreach my $plot_id (@plot_ids) {
        $plot_of{ $_->{stock_id} } = $plot_id for @{ $children->{$plot_id}->{in_trial} || [] };
    }
    my @stock_ids = keys %plot_of;
    my %plot_name = map { $_->{plot_id} => $_->{plot_name} } @{$plan->{changes}};
    my %old_stock = map { $_->{plot_id} => $_->{old_stock_name} } @{$plan->{changes}};

    # phenotypes other than treatments, or high-dimensional data
    my $h = $dbh->prepare("SELECT DISTINCT nes.stock_id FROM nd_experiment_stock nes WHERE nes.stock_id = ANY(?) AND "._has_values_sql);
    $h->execute(\@stock_ids);
    my %phenotyped_plots;
    while (my ($stock_id) = $h->fetchrow_array()) { $phenotyped_plots{ $plot_of{$stock_id} } = 1; }
    $plan->{plots_with_phenotypes} = scalar(keys %phenotyped_plots);
    if (%phenotyped_plots) {
        push @{$plan->{warnings}}, scalar(keys %phenotyped_plots)." plot(s) already have phenotypes. The values stay with their plot, so they count for the new accession; run the analyses of this trial again.";
        if (grep { $_->{type} eq 'plot' && $phenotyped_plots{ $_->{stock_id} } } @{$plan->{renames}}) {
            push @{$plan->{warnings}}, "Phenotype files and Field Book files with the old plot names will not match the renamed plots. Keep the plot names to avoid that.";
        }
    }

    my %role = map { ($ids->{$_} // -1) => ($_ =~ /^female/ ? 'female' : 'male') } qw(female_plot_of female_plant_of male_plot_of male_plant_of);
    my @cross_types = grep { defined } map { $ids->{$_} } qw(female_plot_of female_plant_of male_plot_of male_plant_of);
    return if !@cross_types;
    $h = $dbh->prepare("SELECT r.subject_id, r.type_id, c.uniquename FROM stock_relationship r
        JOIN stock c ON c.stock_id = r.object_id
        WHERE r.subject_id = ANY(?) AND r.type_id = ANY(?) ORDER BY c.uniquename");
    $h->execute(\@stock_ids, \@cross_types);
    while (my ($stock_id, $type_id, $cross_name) = $h->fetchrow_array()) {
        my $plot_id = $plot_of{$stock_id};
        push @{$plan->{warnings}}, "Cross $cross_name used plot $plot_name{$plot_id} as $role{$type_id} parent. The cross keeps its recorded $role{$type_id} parent ($old_stock{$plot_id} when it was made from this plot); correct the cross if needed.";
    }
}

sub _plan_seedlots {
    my $self = shift;
    my $plan = shift;
    my $units = shift;
    my $after = shift;
    my $seedlot_name = shift || {};
    my $options = shift || {};
    my $ids = $self->_cvterm_ids;
    return if !$ids->{seed_transaction} || !$ids->{seedlot} || !$ids->{collection_of};
    my $dbh = $self->schema->storage->dbh;

    my %changed = map { $_->{plot_id} => 1 } @{$plan->{changes}};
    my %plot_ids = map { $_ => 1 } (keys %changed, keys %$seedlot_name);
    return if !%plot_ids;

    my @harvested_from = grep { $changed{$_} } keys %plot_ids;
    if (@harvested_from) {
        my $harvest_h = $dbh->prepare("SELECT r.object_id, s.uniquename FROM stock_relationship r
            JOIN stock s ON s.stock_id = r.subject_id AND s.type_id = ?
            WHERE r.type_id = ? AND r.object_id = ANY(?) ORDER BY s.uniquename");
        $harvest_h->execute($ids->{seedlot}, $ids->{seed_transaction}, \@harvested_from);
        while (my ($plot_id, $name) = $harvest_h->fetchrow_array()) {
            my $state = $after->{$plot_id};
            push @{$plan->{warnings}}, "Seedlot $name was harvested from plot $state->{plot_name}, which has $state->{stock_name} now; correct the seedlot if needed.";
        }
    }

    # Packet movement is an explicit planting-file/seedlot reconciliation.
    return if ($options->{seedlots} // '') ne 'follow' && !%$seedlot_name;

    # the planting transactions of these plots, with the stock their seedlot holds
    my $h = $dbh->prepare("SELECT r.stock_relationship_id, r.subject_id, s.stock_id, s.uniquename, MIN(c.subject_id), r.value
        FROM stock_relationship r
        JOIN stock s ON s.stock_id = r.object_id AND s.type_id = ?
        LEFT JOIN stock_relationship c ON c.object_id = s.stock_id AND c.type_id = ?
        WHERE r.type_id = ? AND r.subject_id = ANY(?)
        GROUP BY r.stock_relationship_id, r.subject_id, s.stock_id, s.uniquename, r.value ORDER BY r.stock_relationship_id");
    $h->execute($ids->{seedlot}, $ids->{collection_of}, $ids->{seed_transaction}, [ keys %plot_ids ]);
    my %own;
    while (my ($transaction_id, $plot_id, $seedlot_id, $name, $content_id, $value) = $h->fetchrow_array()) {
        push @{ $own{$plot_id} }, { transaction_id => $transaction_id, plot_id => $plot_id, seedlot_id => $seedlot_id, seedlot_name => $name, content_id => $content_id };
        push @{$plan->{_seedlot_before}}, [$transaction_id, $plot_id, $seedlot_id, $content_id, $value];
    }

    # the seedlots named in the change
    my %seedlot;
    if (%$seedlot_name) {
        my $seedlot_h = $dbh->prepare("SELECT s.stock_id, s.uniquename, MIN(c.subject_id) FROM stock s
            LEFT JOIN stock_relationship c ON c.object_id = s.stock_id AND c.type_id = ?
            WHERE s.uniquename = ANY(?) AND s.type_id = ? GROUP BY s.stock_id, s.uniquename");
        $seedlot_h->execute($ids->{collection_of}, [ values %$seedlot_name ], $ids->{seedlot});
        while (my ($seedlot_id, $name, $content_id) = $seedlot_h->fetchrow_array()) {
            if ($seedlot{$name} && $seedlot{$name}->{seedlot_id} != $seedlot_id) {
                push @{$plan->{errors}}, "More than one seedlot is named $name; choose an unambiguous seedlot.";
                next;
            }
            $seedlot{$name} = { seedlot_id => $seedlot_id, content_id => $content_id };
        }
    }

    # packets that an earlier correction turned into seed taken from their seedlot (marked with the
    # plot they were linked to): they go back to that plot when it needs a packet of what the
    # seedlot holds, instead of being recorded a second time. Only the seedlots that hold what the
    # plots need (or a family's crosses) are looked at.
    my %taken_for;
    my @needed_stocks = grep { defined } map { $after->{$_}->{stock_id} } keys %plot_ids;
    if (@needed_stocks) {
        my $taken_h = $dbh->prepare("SELECT r.stock_relationship_id, s.stock_id, s.uniquename, MIN(c.subject_id), r.value
            FROM stock_relationship r
            JOIN stock s ON s.stock_id = r.subject_id AND s.type_id = ?
            LEFT JOIN stock_relationship c ON c.object_id = s.stock_id AND c.type_id = ?
            WHERE r.type_id = ? AND r.object_id = r.subject_id AND r.subject_id IN (
                SELECT h.object_id FROM stock_relationship h WHERE h.type_id = ? AND (h.subject_id = ANY(?)
                    OR h.subject_id IN (SELECT m.subject_id FROM stock_relationship m WHERE m.type_id = ? AND m.object_id = ANY(?))))
            GROUP BY r.stock_relationship_id, s.stock_id, s.uniquename, r.value");
        $taken_h->execute($ids->{seedlot}, $ids->{collection_of}, $ids->{seed_transaction}, $ids->{collection_of}, \@needed_stocks, $ids->{cross_member_of} // 0, \@needed_stocks);
        while (my ($transaction_id, $seedlot_id, $name, $content_id, $json) = $taken_h->fetchrow_array()) {
            my $taken = eval { decode_stored_json($json // '{}')->{taken} };
            next if ref($taken) ne 'HASH' || !defined($taken->{plot_id}) || !$plot_ids{ $taken->{plot_id} };
            push @{ $taken_for{ $taken->{plot_id} } }, { transaction_id => $transaction_id, seedlot_id => $seedlot_id, seedlot_name => $name, content_id => $content_id };
            push @{$plan->{_seedlot_before}}, [$transaction_id, $seedlot_id, $seedlot_id, $content_id, $json];
        }
    }

    # what a seedlot holds counts for its stock and, for a cross, for the families the cross is a member of
    # (plots of a family name are planted from seedlots of its crosses)
    my %holds;
    my @contents = grep { defined } map { $_->{content_id} } (values %seedlot, map { @$_ } values %own, values %taken_for);
    $holds{$_}->{$_} = 1 for @contents;
    if (@contents && $ids->{cross_member_of}) {
        my $family_h = $dbh->prepare("SELECT subject_id, object_id FROM stock_relationship WHERE type_id = ? AND subject_id = ANY(?)");
        $family_h->execute($ids->{cross_member_of}, \@contents);
        while (my ($cross_id, $family_id) = $family_h->fetchrow_array()) { $holds{$cross_id}->{$family_id} = 1; }
    }
    my $holds = sub { my ($content_id, $stock_id) = @_; return defined($content_id) && $holds{$content_id}->{$stock_id}; };

    # What each plot needs now: a given seedlot or one holding its accession.
    my $by_number = sub { _compare_plot_numbers($units->{ $_[0] }->{plot_number}, $units->{ $_[1] }->{plot_number}) || $_[0] <=> $_[1] };
    my %want;
    foreach my $plot_id (sort { $by_number->($a, $b) } keys %plot_ids) {
        my $state = $after->{$plot_id};
        my $name = $seedlot_name->{$plot_id};
        # the seedlot the plot has now is no change (a cell left as it was)
        if (defined($name) && !grep { $_->{seedlot_name} eq $name } @{ $own{$plot_id} || [] }) {
            my $s = $seedlot{$name};
            if (!$s) {
                push @{$plan->{errors}}, "Seedlot $name (plot $state->{plot_name}) does not exist.";
            } elsif (!$holds->($s->{content_id}, $state->{stock_id})) {
                # a cell that was not changed with the accession (or a file uploaded again after the
                # packets moved): not used; a note only if the plot is left without a seedlot of its accession
                if (!grep { $holds->($_->{content_id}, $state->{stock_id}) } @{ $own{$plot_id} || [] }) {
                    push @{$plan->{warnings}}, "Seedlot $name, given for plot $state->{plot_name}, does not hold $state->{stock_name}, its accession, so it is not used.";
                }
                $want{$plot_id} = { content_id => $state->{stock_id} } if $changed{$plot_id};
            } else {
                $want{$plot_id} = { seedlot_id => $s->{seedlot_id}, seedlot_name => $name };
            }
        } elsif ($changed{$plot_id}) {
            $want{$plot_id} = { content_id => $state->{stock_id} };
        }
    }
    return if @{$plan->{errors}};
    my $fits = sub {
        my ($t, $want) = @_;
        return 0 if !$want;
        return $t->{seedlot_id} == $want->{seedlot_id} if $want->{seedlot_id};
        return $holds->($t->{content_id}, $want->{content_id});
    };

    # transactions that do not fit their plot any more are free for the plots that need one
    my (@free, @need);
    foreach my $plot_id (sort { $by_number->($a, $b) } keys %want) {
        my $own = $own{$plot_id} || [];
        next if grep { $fits->($_, $want{$plot_id}) } @$own;
        push @free, @$own;
        push @need, $plot_id if $want{$plot_id};
    }
    my $distance = sub {
        my ($m, $n) = map { $units->{$_}->{plot_number} } @_;
        return (defined($m) && defined($n) && $m =~ /^\d+$/ && $n =~ /^\d+$/) ? abs($m - $n) : 0;
    };
    # the plots with a given seedlot first, so that the others do not take their transactions
    @need = ((grep { $want{$_}->{seedlot_id} } @need), (grep { !$want{$_}->{seedlot_id} } @need));
    foreach my $plot_id (@need) {
        my $want = $want{$plot_id};
        my $plot_name = $units->{$plot_id}->{plot_name};
        my @fitting = sort { $distance->($a->{plot_id}, $plot_id) <=> $distance->($b->{plot_id}, $plot_id) || $a->{transaction_id} <=> $b->{transaction_id} } grep { $fits->($_, $want) } @free;
        my $t = $fitting[0];
        if ($t) {
            if (!$want->{seedlot_id} && @fitting > 1 && $distance->($fitting[1]->{plot_id}, $plot_id) == $distance->($t->{plot_id}, $plot_id)) {
                # two packets of the accession as near: the nearest-by-number rule cannot tell which one went in
                push @{$plan->{warnings}}, "More than one source packet fits plot $plot_name equally well.";
                push @{$plan->{errors}}, "The source packet for plot $plot_name is ambiguous. Give its seedlot explicitly or correct the packet assignment before applying this file.";
                next;
            }
            @free = grep { $_ != $t } @free;
            push @{$plan->{seedlots}}, { %$t, type => 'move', from_plot_id => $t->{plot_id}, from_plot_name => $units->{ $t->{plot_id} }->{plot_name}, plot_id => $plot_id, plot_name => $plot_name };
            next;
        }
        # its own packet, that an earlier correction turned into seed taken (also the packet of a
        # plot whose earlier packet assignment was corrected)
        my ($r) = sort { $b->{transaction_id} <=> $a->{transaction_id} } grep { $fits->($_, $want) } @{ $taken_for{$plot_id} || [] };
        if ($r) {
            push @{$plan->{seedlots}}, { %$r, type => 'restore', plot_id => $plot_id, plot_name => $plot_name };
            next;
        }
        if (!$want->{seedlot_id}) {
            next;
        }
        # another seedlot of the plot's accession: the plot's own transaction gets it
        ($t) = grep { $_->{plot_id} == $plot_id } @free;
        if ($t) {
            @free = grep { $_ != $t } @free;
            push @{$plan->{seedlots}}, { %$t, type => 'seedlot', plot_name => $units->{$plot_id}->{plot_name}, old_seedlot_id => $t->{seedlot_id}, old_seedlot_name => $t->{seedlot_name}, seedlot_id => $want->{seedlot_id}, seedlot_name => $want->{seedlot_name} };
        } else {
            push @{$plan->{warnings}}, "Plot $units->{$plot_id}->{plot_name} has no seed transaction, so seedlot $want->{seedlot_name} is not recorded for it; record it with Upload Seedlots Planted In Trial.";
        }
    }
    foreach my $t (sort { $a->{transaction_id} <=> $b->{transaction_id} } @free) {
        push @{$plan->{seedlots}}, { %$t, type => 'taken', plot_name => $units->{ $t->{plot_id} }->{plot_name} };
    }
}


=head2 summary($plan)

A short, JSON-safe summary of a plan for AJAX responses.

=cut

sub summary {
    my $self = shift;
    my $plan = shift;
    my %final_name=map {($_->{old_name}=>$_->{new_name})} grep {$_->{type} eq 'plot'} @{$plan->{renames}};
    return {
        changed => scalar(@{$plan->{changes}}),
        changes => [ map { { plot_name => $_->{plot_name}, old_stock_name => $_->{old_stock_name}, new_stock_name => $_->{new_stock_name} } } @{$plan->{changes}} ],
        unchanged => $plan->{unchanged},
        replicates_changed => scalar(@{$plan->{replicates}}),
        affected_plots => [map {$final_name{$_} // $_} @{$plan->{affected_plots} || []}],
        affected_project_ids => $plan->{affected_project_ids} || [ $self->trial_id ],
        renamed => [ map { { old_name => $_->{old_name}, new_name => $_->{new_name} } } grep { $_->{type} eq 'plot' } @{$plan->{renames}} ],
        not_renamed => $plan->{not_renamed},
        entry_numbers => [ map { { stock_name => $_->{stock_name}, entry_number => $_->{entry_number} } } @{$plan->{entry_numbers}} ],
        checks => [ map { { plot_name => $_->{plot_name}, check => $_->{new} } } @{$plan->{checks}} ],
        seedlots => [ map { my $s = $_; +{ map { $_ => $s->{$_} } grep { defined($s->{$_}) } qw(type seedlot_name plot_name from_plot_name old_seedlot_name) } } @{$plan->{seedlots}} ],
        phenotypes_deleted => scalar(@{ $plan->{phenotypes_to_delete}->{phenotype_ids} }) + scalar(@{ $plan->{phenotypes_to_delete}->{md_experiment_ids} || [] }),
        plots_with_phenotypes => $plan->{plots_with_phenotypes},
        warnings => $plan->{warnings},
        plan_digest => $self->plan_digest($plan),
    };
}

__PACKAGE__->meta->make_immutable;

1;
