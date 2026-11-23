package CXGN::Report::Catalog;

=head1 NAME

CXGN::Report::Catalog - the report scripts offered by the Report Factory, and the inputs each one takes

=head1 SYNOPSIS

  my $catalog = CXGN::Report::Catalog->new({
      basepath      => $c->config->{basepath},
      report_engine => $c->config->{report_engine},   # "script_a; script_b"
  });
  foreach my $r (@{ $catalog->reports() }) {
      print "$r->{name}: $r->{title} uses ", join(', ', grep { $r->{inputs}->{$_} } keys %{ $r->{inputs} }), "\n";
  }
  my @errors = $catalog->validate_inputs('trait_components', { trials => 1 });

=head1 DESCRIPTION

The scripts are listed in the report_engine configuration key (names separated
by ";") and live in bin/Reports/<name>.pl. Nothing else is needed to add a
report: the inputs a script takes are detected from its source code.

With Getopt::Std (getopts('H:D:U:P:o:f:s:e:t:a:T:')):

  -s / -e   start and end date (YYYY-MM-DD)    -> date range
  -t        file with trial ids, one per line  -> trial list
  -a        file with accession ids            -> accession list
  -T        file with trait (cvterm) ids       -> trait list

With Getopt::Long the same inputs are found by their long names:
start_date / end_date, trials (or trial_list), accessions (or accession_list),
traits (or trait_list).

The title is the NAME section of the script's POD ("name.pl - title"), the
description the first sentence of its DESCRIPTION section (at most 140
characters), so keep that sentence short.

Rules applied to the inputs a script takes:

=over

=item * a script that takes a trial list looks at trials: it must get the trial
list or the date range; the accession and trait lists are then filters;

=item * any other script must get at least one of the inputs it takes (a script
that takes only dates must get the dates, as all reports did before lists
existed; one that takes dates and an accession list gets either);

=item * a script that takes no input runs on the whole database.

=back

=head1 AUTHOR

Chris Simoes <ccs263@cornell.edu>

=cut

use Moose;
use File::Slurp qw | read_file |;

our @INPUTS = qw| dates trials accessions traits |;
our @LISTS = qw| trials accessions traits |;
# with a trial list, the inputs that say which trials a report looks at; the other lists are then filters
our @SCOPE = qw| dates trials |;
our %INPUT_LABELS = ( dates => 'date range', trials => 'trial list', accessions => 'accession list', traits => 'trait list' );
# Getopt::Std letter => input
our %LETTERS = ( s => 'dates', e => 'dates', t => 'trials', a => 'accessions', T => 'traits' );
# Getopt::Long name => input
our %LONG_NAMES = (
    start_date => 'dates', end_date => 'dates',
    trials => 'trials', trial_list => 'trials',
    accessions => 'accessions', accession_list => 'accessions',
    traits => 'traits', trait_list => 'traits',
);

has 'basepath' => ( isa => 'Str', is => 'ro', required => 1 );

has 'report_engine' => ( isa => 'Maybe[Str]', is => 'ro' );

has 'reports_dir' => ( isa => 'Str', is => 'ro', lazy => 1, default => sub { $_[0]->basepath . '/bin/Reports' } );

has '_reports' => ( isa => 'ArrayRef', is => 'ro', lazy => 1, builder => '_build_reports' );

sub valid_name {
    my $name = shift;
    $name = shift if defined($name) && $name eq __PACKAGE__;
    return defined($name) && !ref($name) && $name =~ /^[A-Za-z0-9_]{1,80}$/ ? 1 : 0;
}

sub configured_names {
    my $self = shift;
    my %seen;
    return grep { valid_name($_) && !$seen{$_}++ } map { s/^\s+|\s+$//gr } split /[;,]/, ($self->report_engine // '');
}

sub _build_reports {
    my $self = shift;
    return [ map { $self->_describe($_) } $self->configured_names() ];
}

sub reports { return $_[0]->_reports }

sub report {
    my ($self, $name) = @_;
    return if !valid_name($name);
    my ($r) = grep { $_->{name} eq $name } @{ $self->_reports };
    return $r;
}

sub _article {
    my $label = shift;
    return ($label =~ /^[aeiou]/i ? 'an ' : 'a ') . $label;
}

sub _humanize {
    my $t = shift() =~ s/_/ /gr;
    return ucfirst($t);
}

sub _describe {
    my ($self, $name) = @_;
    my $script = $self->reports_dir . "/$name.pl";
    my $r = {
        name        => $name,
        title       => _humanize($name),
        description => '',
        installed   => 0,
        inputs      => { map { $_ => 0 } @INPUTS },
    };
    return $r if !-f $script;
    my $source = eval { read_file($script, binmode => ':utf8') };
    return $r if !defined($source);
    $r->{installed} = 1;
    my $detected = detect_inputs($source);
    $r->{inputs}->{$_} = 1 for keys %$detected;
    my ($title, $description) = _pod_text($source, $name);
    $r->{title} = $title if $title;
    $r->{description} = $description if $description;
    return $r;
}

=head2 detect_inputs($source)

The inputs (dates, trials, accessions, traits) read by a script, from the
option specification it gives to getopts() or GetOptions(). Returns a hash ref
input => 1.

=cut

sub detect_inputs {
    my $source = shift // '';
    $source = shift if $source eq __PACKAGE__;
    my %found;
    # code only: options mentioned in the POD do not count
    my $code = join("\n", grep { !/^\s*#/ } split /\n/, ($source =~ s/^=[a-zA-Z].*?(?:^=cut\b[^\n]*|\z)//gmsr));

    while ($code =~ /\bgetopts?\s*\(\s*(['"])([^'"]*)\1/g) {
        my $spec = $2;
        while ($spec =~ /([A-Za-z])(:?)/g) {
            # only letters that take a value (a file or a date) are inputs
            $found{ $LETTERS{$1} } = 1 if $2 && $LETTERS{$1};
        }
    }
    while ($code =~ /\bGetOptions\s*\((.*?)\)\s*(?:;|or\b|\|\||\bdie\b)/gs) {
        my $args = $1;
        while ($args =~ /(['"])([A-Za-z_|]+)(?:[=:][sif][@%]?)?\1/g) {
            foreach my $alias (split /\|/, $2) {
                $found{ $LONG_NAMES{$alias} } = 1 if $LONG_NAMES{$alias};
            }
        }
    }
    return \%found;
}

sub _pod_text {
    my ($source, $name) = @_;
    my ($title, $description) = ('', '');
    if ($source =~ /^=head1\s+NAME\s*\n(.*?)(?=^=)/ms) {
        my $text = $1;
        $text =~ s/^\s+|\s+$//g;
        if ($text =~ /^\S*\Q$name\E(?:\.pl)?\s+-+\s+(.+)$/m) {
            $title = ucfirst($1);
        }
    }
    if ($source =~ /^=head\d\s+DESCRIPTION\s*\n(.*?)(?=^=|\z)/ms) {
        my ($first) = grep { /\S/ } split /\n\s*\n/, $1;
        if (defined $first) {
            $first =~ s/\s+/ /g;
            $first =~ s/^\s+|\s+$//g;
            $first =~ s/[A-Z]<([^>]*)>/$1/g;    # B<x>, C<x>
            # first sentence only: the page shows a one-line description
            $first = $1 if $first =~ /^(.+?[.!?])(?:\s|$)/;
            $first = substr($first, 0, 139) . "\x{2026}" if length($first) > 140;
            $description = $first;
        }
    }
    return ($title, $description);
}

=head2 validate_inputs($name_or_report, \%given)

%given holds a true value for every input the user filled in (dates, trials,
accessions, traits). Returns the list of problems, empty when the report can run.

=cut

sub validate_inputs {
    my ($self, $report, $given) = @_;
    $report = $self->report($report) if !ref($report);
    return ('Unknown report.') if !$report;
    return ("The report script $report->{name}.pl is not installed on this server.") if !$report->{installed};
    $given ||= {};
    my @needed = $report->{inputs}->{trials}
        ? (grep { $report->{inputs}->{$_} } @SCOPE)
        : (grep { $report->{inputs}->{$_} } @INPUTS);
    if (@needed && !grep { $given->{$_} } @needed) {
        return ("$report->{title} needs " . join(' or ', map { _article($INPUT_LABELS{$_}) } @needed) . ".");
    }
    return ();
}

__PACKAGE__->meta->make_immutable;

1;
