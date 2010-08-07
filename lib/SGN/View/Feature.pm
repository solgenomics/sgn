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
            my ($srcfeature) = $loc->srcfeature;
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
    my $gb = $c->enabled_feature('gbrowse2');
    return '' unless $gb;
    # TODO: render multiple URLs
    my ($url) = map { $_->url } $gb->xrefs($feature->name);
    unless ( $url ) {
        my @locs = $feature->featureloc_features->all;
        my $fl = $locs[0];
        #die Dumper [ $url ];
        my $plaintext = $fl->srcfeature->name . ':'.$fl->fmin . '..' . $fl->fmax;
        ($url) = map { $_->url } $gb->xrefs($plaintext);
    }
    if (defined $fmin && defined $fmax) {
        return sprintf('<a href="%s">%s</a>', $url, join(",", $fmin, $fmax)),
    } else {
        return $url;
    }
}
1;
