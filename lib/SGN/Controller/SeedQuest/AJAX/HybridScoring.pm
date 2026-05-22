
package SGN::Controller::SeedQuest::AJAX::HybridScoring;

use Moose;
use JSON;
use Try::Tiny;
use List::Util qw(sum);
use POSIX qw(ceil);
use Excel::Writer::XLSX;
use File::Temp qw(tempfile);

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
);

# ============================================================================
# SCORING ENDPOINT
# ============================================================================

sub calculate : Path('/ajax/seedquest/hybridscoring/calculate') Args(0) ActionClass('REST') { }
sub calculate_GET  { shift->_do_calculate(@_); }
sub calculate_POST { shift->_do_calculate(@_); }

sub _do_calculate {
    my ($self, $c) = @_;

    # Defense-in-depth: verify user is logged in
    unless ($c->user()) {
        $c->stash->{rest} = { error => 'You must be logged in first!' };
        return;
    }

    my $trial_id = $c->req->param('trial_id');
    unless (defined $trial_id && $trial_id =~ /^[0-9]+$/) {
        $c->stash->{rest} = { error => 'A valid trial_id is required' };
        return;
    }

    try {
        my $dbh = $c->dbc->dbh;

        # Get trial name
        my ($trial_name) = $dbh->selectrow_array(
            "SELECT name FROM project WHERE project_id = ?",
            undef, $trial_id
        );
        unless ($trial_name) {
            $c->stash->{rest} = { error => "Trial $trial_id not found" };
            return;
        }

        # Fetch all phenotype data for this trial, excluding QC outliers
        my $sth = $dbh->prepare(q{
            SELECT
                s2.uniquename    AS accession,
                cvterm.name      AS trait,
                phenotype.value  AS val
            FROM phenotype
            JOIN nd_experiment_phenotype nep
                ON nep.phenotype_id = phenotype.phenotype_id
            JOIN nd_experiment_project nep2
                ON nep2.nd_experiment_id = nep.nd_experiment_id
            JOIN nd_experiment_stock nes
                ON nes.nd_experiment_id = nep.nd_experiment_id
            JOIN stock s ON s.stock_id = nes.stock_id
            JOIN stock_relationship sr ON sr.subject_id = nes.stock_id
            JOIN stock s2 ON s2.stock_id = sr.object_id
            JOIN cvterm ON phenotype.observable_id = cvterm.cvterm_id
            WHERE nep2.project_id = ?
              AND phenotype.value ~ '^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)([eE][+-]?[0-9]+)?$'
              AND phenotype.phenotype_id NOT IN (
                  SELECT phenotype_id FROM phenotypeprop
                  WHERE type_id IN (
                      SELECT cvterm_id FROM cvterm
                      WHERE name = 'phenotype_outlier'
                  )
              )
            ORDER BY cvterm.name, s2.uniquename
        });
        $sth->execute($trial_id);

        # Group data: trait -> accession -> [values]
        my %data;
        while (my ($accession, $trait, $val) = $sth->fetchrow_array) {
            push @{$data{$trait}{$accession}}, $val + 0;
        }

        # Process each trait
        my %results;
        for my $trait (sort keys %data) {
            my $accessions = $data{$trait};
            my @scored;

            for my $acc (sort keys %$accessions) {
                my @vals = sort { $a <=> $b } @{$accessions->{$acc}};
                my $n = scalar @vals;
                my $trimmed = _trimmed_mean(\@vals, $n);

                push @scored, {
                    name         => $acc,
                    reps         => $n,
                    trimmed_mean => $trimmed,
                };
            }

            # Filter out N/A hybrids for standard calculation
            my @valid = grep { defined $_->{trimmed_mean} } @scored;

            # Sort by trimmed_mean descending for top 2/3
            my @sorted = sort { $b->{trimmed_mean} <=> $a->{trimmed_mean} } @valid;
            my $top_count = ceil(scalar(@sorted) * 2 / 3);
            $top_count = 1 if $top_count < 1;

            my @top = @sorted[0 .. $top_count - 1];
            my $trial_standard = scalar(@top) > 0
                ? sum(map { $_->{trimmed_mean} } @top) / scalar(@top)
                : 0;

            # Calculate scores
            for my $h (@scored) {
                if (defined $h->{trimmed_mean} && $trial_standard > 0) {
                    $h->{score} = sprintf("%.1f",
                        ($h->{trimmed_mean} / $trial_standard) * 100);
                    $h->{trimmed_mean} = sprintf("%.2f", $h->{trimmed_mean});
                } else {
                    $h->{score} = undef;
                    $h->{trimmed_mean} = undef;
                }
            }

            $results{$trait} = {
                trial_standard      => sprintf("%.2f", $trial_standard),
                top_two_thirds_count => $top_count,
                total_hybrids       => scalar(@scored),
                valid_hybrids       => scalar(@valid),
                hybrids             => \@scored,
            };
        }

        $c->stash->{rest} = {
            success    => 1,
            trial_id   => $trial_id,
            trial_name => $trial_name,
            traits     => \%results,
        };
    } catch {
        $c->stash->{rest} = { error => "Calculation failed: $_" };
    };
}

# ============================================================================
# TRIMMING LOGIC
# ============================================================================

sub _trimmed_mean {
    my ($sorted_vals, $n) = @_;

    # $sorted_vals is sorted ascending (low -> high)
    # Rules:
    #   n >= 6 : drop 1 max (last) + 2 min (first two) -> mean of rest
    #   n 4-5  : drop 1 max + 1 min -> mean of rest
    #   n == 3 : drop max + min -> center value only
    #   n <= 2 : N/A
    return undef if $n <= 2;

    if ($n >= 6) {
        # Drop indices 0, 1 (two min) and last (max)
        my @kept = @{$sorted_vals}[2 .. $n - 2];
        return sum(@kept) / scalar(@kept);
    }
    elsif ($n >= 4) {
        # Drop index 0 (min) and last (max)
        my @kept = @{$sorted_vals}[1 .. $n - 2];
        return sum(@kept) / scalar(@kept);
    }
    else {
        # n == 3: center value
        return $sorted_vals->[1];
    }
}

# ============================================================================
# EXCEL EXPORT
# ============================================================================

sub export : Path('/ajax/seedquest/hybridscoring/export') Args(0) ActionClass('REST') { }

sub export_GET {
    my ($self, $c) = @_;

    my $trial_id = $c->req->param('trial_id');
    unless ($trial_id) {
        $c->stash->{rest} = { error => 'Missing trial_id' };
        return;
    }

    # Compute scoring data
    $self->_do_calculate($c);
    my $result = $c->stash->{rest};

    unless ($result->{success}) {
        # Leave error in rest stash for JSON serialization
        return;
    }

    # Build Excel
    my ($fh, $tmpfile) = tempfile(SUFFIX => '.xlsx', UNLINK => 1);
    close($fh);
    my $workbook = Excel::Writer::XLSX->new($tmpfile);

    my $title_fmt = $workbook->add_format(
        bold => 1, size => 14, color => '#2c3e50',
    );
    my $hdr_fmt = $workbook->add_format(
        bold => 1, bg_color => '#2c3e50', color => 'white',
        border => 1, align => 'center', valign => 'vcenter',
    );
    my $num_fmt = $workbook->add_format(
        num_format => '0.00', border => 1, align => 'center',
    );
    my $na_fmt = $workbook->add_format(
        border => 1, align => 'center', color => '#999999', italic => 1,
    );
    my $good_fmt = $workbook->add_format(
        num_format => '0.0', border => 1, align => 'center',
        bg_color => '#d5f5e3', bold => 1,
    );
    my $bad_fmt = $workbook->add_format(
        num_format => '0.0', border => 1, align => 'center',
        bg_color => '#fadbd8',
    );

    my $trial_name = $result->{trial_name};
    $trial_name =~ s/[^a-zA-Z0-9_()-]/_/g;

    for my $trait (sort keys %{$result->{traits}}) {
        my $tdata = $result->{traits}{$trait};
        # Excel worksheet names cannot contain []:*?/\
        (my $ws_name = $trait) =~ s/[\[\]:*?\/\\]/_/g;
        $ws_name = substr($ws_name, 0, 31);
        my $ws = $workbook->add_worksheet($ws_name);
        $ws->set_landscape();

        $ws->merge_range('A1:E1', "$trial_name - $trait", $title_fmt);
        my $info = sprintf("Standard: %s | Top 2/3: %d of %d hybrids",
            $tdata->{trial_standard}, $tdata->{top_two_thirds_count},
            $tdata->{total_hybrids});
        $ws->write(1, 0, $info);

        my @headers = ('Hybrid', 'Reps', 'Trimmed Mean', 'Score (%)', 'vs Standard');
        for my $i (0 .. $#headers) {
            $ws->write(3, $i, $headers[$i], $hdr_fmt);
        }
        $ws->set_column(0, 0, 20);
        $ws->set_column(1, 1, 8);
        $ws->set_column(2, 2, 14);
        $ws->set_column(3, 3, 12);
        $ws->set_column(4, 4, 14);

        my @hybrids = sort {
            (defined $b->{score} ? $b->{score} : -999)
            <=> (defined $a->{score} ? $a->{score} : -999)
        } @{$tdata->{hybrids}};

        my $row = 4;
        for my $h (@hybrids) {
            $ws->write_string($row, 0, $h->{name});
            $ws->write_number($row, 1, $h->{reps}, $num_fmt);

            if (defined $h->{trimmed_mean}) {
                $ws->write_number($row, 2, $h->{trimmed_mean}, $num_fmt);
                my $score = $h->{score} + 0;
                my $fmt = $score >= 100 ? $good_fmt : $bad_fmt;
                $ws->write_number($row, 3, $score, $fmt);
                my $diff = sprintf("%.1f", $score - 100);
                $ws->write_string($row, 4, ($diff >= 0 ? "+$diff" : $diff) . '%', $num_fmt);
            } else {
                $ws->write_string($row, 2, 'N/A', $na_fmt);
                $ws->write_string($row, 3, 'N/A', $na_fmt);
                $ws->write_string($row, 4, '-', $na_fmt);
            }
            $row++;
        }

        $ws->autofilter(3, 0, $row - 1, $#headers);
        $ws->freeze_panes(4, 1);
    }

    $workbook->close();

    my $filename = "scoring_${trial_name}.xlsx";
    open(my $in, '<:raw', $tmpfile) or die "Cannot read temp file: $!";
    my $data = do { local $/; <$in> };
    close($in);

    # Clear REST stash and send binary response directly
    delete $c->stash->{rest};
    $c->res->content_type('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    $c->res->header('Content-Disposition' => "attachment; filename=\"$filename\"");
    $c->res->body($data);
}

1;
