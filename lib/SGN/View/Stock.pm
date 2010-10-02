package SGN::View::Stock;
use base 'Exporter';
use strict;
use warnings;

our @EXPORT_OK = qw/
    stock_link organism_link
    /;
use CatalystX::GlobalContext '$c';



sub stock_link {
    my ($stock) = @_;
    my $name = $stock->uniquename;
    my $id = $stock->stock_id;
    #return qq{<a href="/stock/view/name/$name">$name</a>};
    return qq{<a href="/phenome/stock.pl?stock_id=$id">$name</a>};
    
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
    my ($feature) = @_;
    my $name = $feature->type->name;
    my $id   = $feature->type->id;
    return qq{<a href="/chado/cvterm.pl?cvterm_id=$id">$name</a>};
}



######
1;
######
