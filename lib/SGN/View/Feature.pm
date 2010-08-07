package SGN::View::Feature;
use base 'Exporter';
use strict;
use warnings;

our @EXPORT_OK = qw/related_stats feature_table/;
use CatalystX::GlobalContext '$c';

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
                join(",", $fmin, $fmax),
                $fmax-$fmin . " bp",
                $loc->strand,
                $loc->phase,
                $loc->rank,
            ];
        }
    }
    return $data;
}

1;
