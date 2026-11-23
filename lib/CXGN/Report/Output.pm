package CXGN::Report::Output;

=head1 NAME

CXGN::Report::Output - write the files of a Report Factory report

=head1 SYNOPSIS

  use CXGN::Report::Output;

  my $out = CXGN::Report::Output->new({
      directory => $opt{o},          # output directory given by the runner
      basename  => $opt{f},          # file name prefix given by the runner
      title     => 'Phenotype quality control',
  });
  $out->add_summary('Trials checked', 12);
  $out->add_chart({ type => 'bar', title => 'Issues by type', labels => [ 'below minimum' ], values => [ 4 ] });
  $out->add_table({ name => 'Phenotype QC', columns => \@columns, rows => \@rows });
  $out->add_note('Traits without a minimum and a maximum were not checked.');
  $out->write();    # <basename>.xlsx (one sheet per table), <basename>[_<table>].csv, <basename>.results.json

  # inputs passed by the runner
  my @trial_ids = CXGN::Report::Output::read_ids($opt{t});
  my @trait_ids = CXGN::Report::Output::read_ids($opt{T});

=head1 DESCRIPTION

The xlsx and csv files are what users download. The results file is what the
Report Factory page shows: summary numbers, simple charts, notes and the first
rows of every table (preview_rows, 1000 by default).

=head1 AUTHOR

Chris Simoes <ccs263@cornell.edu>

=cut

use Moose;
use JSON;
use File::Slurp qw | read_file write_file |;
use Excel::Writer::XLSX;
use Text::CSV;

has 'directory' => ( isa => 'Str', is => 'ro', required => 1 );
has 'basename' => ( isa => 'Str', is => 'ro', required => 1 );
has 'title' => ( isa => 'Str', is => 'rw', default => '' );
has 'preview_rows' => ( isa => 'Int', is => 'rw', default => 1000 );
has 'summary' => ( isa => 'ArrayRef', is => 'ro', default => sub { [] } );
has 'charts' => ( isa => 'ArrayRef', is => 'ro', default => sub { [] } );
has 'tables' => ( isa => 'ArrayRef', is => 'ro', default => sub { [] } );
has 'notes' => ( isa => 'ArrayRef', is => 'ro', default => sub { [] } );
has 'inputs' => ( isa => 'HashRef', is => 'ro', default => sub { {} } );

sub _path {
    my ($self, $suffix) = @_;
    my $dir = $self->directory;
    $dir .= '/' if $dir ne '' && $dir !~ m{/$};
    return $dir . $self->basename . $suffix;
}

sub add_summary {
    my ($self, $label, $value, $hint) = @_;
    push @{ $self->summary }, { label => $label, value => $value, (defined($hint) ? (hint => $hint) : ()) };
    return $self;
}

# { type => 'bar', title => ..., labels => [...], values => [...] }
sub add_chart {
    my ($self, $chart) = @_;
    return $self if ref($chart) ne 'HASH' || ref($chart->{labels}) ne 'ARRAY' || ref($chart->{values}) ne 'ARRAY';
    push @{ $self->charts }, { type => ($chart->{type} // 'bar'), title => ($chart->{title} // ''), labels => $chart->{labels}, values => $chart->{values} };
    return $self;
}

# { name => 'sheet name', columns => [...], rows => [[...], ...], description => '' }
sub add_table {
    my ($self, $table) = @_;
    die "add_table needs a name and columns\n" if ref($table) ne 'HASH' || !$table->{name} || ref($table->{columns}) ne 'ARRAY';
    $table->{rows} ||= [];
    push @{ $self->tables }, $table;
    return $self;
}

sub add_note {
    my ($self, $text) = @_;
    push @{ $self->notes }, $text if defined($text) && length($text);
    return $self;
}

# input summary shown on the results page (e.g. trials => 12)
sub set_input {
    my ($self, $key, $value) = @_;
    $self->inputs->{$key} = $value;
    return $self;
}

sub _sheet_name {
    my ($name, $used) = @_;
    my $s = substr(($name =~ s{[\[\]:*?/\\]}{_}gr), 0, 31);
    $s = 'Sheet' if $s eq '';
    my $base = $s;
    my $n = 2;
    while ($used->{ lc $s }) {
        $s = substr($base, 0, 28) . "_$n";
        $n++;
    }
    $used->{ lc $s } = 1;
    return $s;
}

sub _file_tag {
    my $name = shift;
    my $t = lc($name);
    $t =~ s/[^a-z0-9]+/_/g;
    $t =~ s/^_+|_+$//g;
    return $t || 'table';
}

sub write {
    my ($self, %args) = @_;
    my %formats = map { $_ => 1 } @{ $args{formats} || [ 'xlsx', 'csv' ] };
    my @files;

    if ($formats{xlsx} && @{ $self->tables }) {
        my $file = $self->_path('.xlsx');
        my $workbook = Excel::Writer::XLSX->new($file) or die "Could not create $file: $!\n";
        my $bold = $workbook->add_format(bold => 1);
        my %used;
        foreach my $table (@{ $self->tables }) {
            my $sheet = $workbook->add_worksheet(_sheet_name($table->{name}, \%used));
            $sheet->write_row(0, 0, $table->{columns}, $bold);
            my $r = 1;
            foreach my $row (@{ $table->{rows} }) {
                # keep values as text when they look like text (e.g. plot names with leading zeros)
                for my $i (0 .. $#$row) {
                    my $v = $row->[$i];
                    if (defined($v) && $v =~ /^-?(\d+\.?\d*|\.\d+)([eE][-+]?\d+)?$/ && $v !~ /^-?0\d/) {
                        $sheet->write_number($r, $i, $v);
                    } else {
                        $sheet->write_string($r, $i, $v // '');
                    }
                }
                $r++;
            }
            $sheet->freeze_panes(1, 0);
        }
        $workbook->close();
        push @files, $file;
    }

    if ($formats{csv}) {
        my $csv = Text::CSV->new({ binary => 1, eol => "\n" });
        my $single = scalar(@{ $self->tables }) == 1;
        foreach my $table (@{ $self->tables }) {
            my $file = $self->_path($single ? '.csv' : '_' . _file_tag($table->{name}) . '.csv');
            open(my $fh, '>:encoding(UTF-8)', $file) or die "Could not write $file: $!\n";
            $csv->print($fh, $table->{columns});
            $csv->print($fh, [ map { $_ // '' } @$_ ]) for @{ $table->{rows} };
            close($fh);
            push @files, $file;
        }
    }

    my $max = $self->preview_rows;
    my $results = {
        title   => $self->title,
        summary => $self->summary,
        charts  => $self->charts,
        notes   => $self->notes,
        inputs  => $self->inputs,
        tables  => [ map {
            my $n = scalar(@{ $_->{rows} });
            {
                name        => $_->{name},
                description => ($_->{description} // ''),
                columns     => $_->{columns},
                rows        => [ @{ $_->{rows} }[ 0 .. ($n > $max ? $max : $n) - 1 ] ],
                total_rows  => $n,
                truncated   => ($n > $max ? JSON::true : JSON::false),
            }
        } @{ $self->tables } ],
    };
    my $results_file = $self->_path('.results.json');
    write_file($results_file, { binmode => ':raw' }, JSON->new->utf8->canonical->encode($results));
    push @files, $results_file;
    return \@files;
}

=head2 read_ids($file)

Ids written by the runner, one per line. Returns an empty list without a file.

=cut

sub read_ids {
    my $file = shift;
    return () if !defined($file) || $file eq '' || !-e $file;
    return grep { /^\d+$/ } map { s/^\s+|\s+$//gr } read_file($file);
}

__PACKAGE__->meta->make_immutable;

1;
