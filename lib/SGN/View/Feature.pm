package SGN::View::Feature;
use base 'Exporter';
use strict;
use warnings;
use SGN::Context;

our @EXPORT_OK = qw/related_stats feature_table gbrowse_link/;
our $c = SGN::Context->new;

sub related_stats {
    my ($features) = @_;
    my $stats = { };
    my $total = scalar @$features;
    for my $f (@$features) {
            $stats->{$f->type->name}++;
    }
    my $data = [ ];
    for my $k (sort keys %$stats) {
        push @$data, [ $k => $stats->{$k} ];
    }
    push @$data, [ "Total" => $total ];
    return $data;
}

sub feature_table {
    my ($features) = @_;
    my $data = [];
    for my $f (@$features) {
        my @locations = $f->featureloc_features->all;
        # Add a row for every featureloc
        for my $loc (@locations) {
            my ($fmin,$fmax) = ($loc->fmin, $loc->fmax);
            push @$data, [
                $c->render_mason(
                    "/feature/link.mas",
                    feature => $f,
                ),
                $f->type->name,
                gbrowse_link($f,$fmin,$fmax),
                $fmax-$fmin . " bp",
                $loc->strand == 1 ? '+' : '-',
                $loc->phase,
                $loc->rank,
            ];
        }
    }
    return $data;
}

sub gbrowse_link {
    my ($feature, $fmin, $fmax) = @_;
    sprintf '<a href="/gbrowse/bin/gbrowse/ITAG1_genomic/?ref=%s;start=%s;end=%s">%s</a>',
        $feature->name, $fmin, $fmax, join(",", $fmin, $fmax),
}
1;
