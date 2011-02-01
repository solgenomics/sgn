package SGN::View::Stock;
use base 'Exporter';
use strict;
use warnings;

our @EXPORT_OK = qw/
    stock_link organism_link cvterm_link
    stock_table related_stats
/;
our @EXPORT = ();

sub stock_link {
    my ($stock) = @_;
    my $name = $stock->uniquename;
    my $id = $stock->stock_id;
    return qq{<a href="/stock/view/id/$id">$name</a>};
}

sub organism_link {
    my ($organism) = @_;
    my $id      = $organism->organism_id;
    my $species = $organism->species;
    return <<LINK;
<span class="species_binomial">
<a href="/chado/organism.pl?organism_id=$id">$species</a>
LINK
}

sub cvterm_link {
    my ($cvterm) = @_;
    my $name = $cvterm->name;
    my $id   = $cvterm->cvterm_id;
    return qq{<a href="/chado/cvterm.pl?cvterm_id=$id">$name</a>};
}

sub stock_table {
    my ($stocks) = @_;
    my $data = [];
    for my $s (@$stocks) {
        # Add a row for every stock
        push @$data, [
            cvterm_link($s),
            stock_link($s),

        ];
    }
    return $data;
}


sub related_stats {
    my ($stocks) = @_;
    my $stats = { };
    my $total = scalar @$stocks;
    for my $s (@$stocks) {
            $stats->{cvterm_link($s)}++;
    }
    my $data = [ ];
    for my $k (sort keys %$stats) {
        push @$data, [ $stats->{$k}, $k ];
    }
    if( 1 < scalar keys %$stats ) {
        push @$data, [ $total, "<b>Total</b>" ];
    }
    return $data;
}

######
1;
######
