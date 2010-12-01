package SGN::View::Trait;
use base 'Exporter';
use strict;
use warnings;

our @EXPORT_OK = qw/
cvterm_link
/;



sub cvterm_link {
    my ($cvterm) = @_;
    my $name = $cvterm->name;
    my $id = $cvterm->cvterm_id;
    return qq{<a href="/chado/cvterm.pl?cvterm_id=$id">$name</a>};
}
