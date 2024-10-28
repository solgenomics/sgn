

use strict;

my $file = shift;

open(my $F, "<", $file) || die "Can't open file $file\n";

# write header
#
print <<HEADER;
format-version: 1.2
date: 10:03:2024 17:10
saved-by: Lukas_Mueller
default-namespace: bean_trait
ontology: CO_365

HEADER

# read header
#
my $header = <$F>;

print <<TERM;

[Term]
id: ROOT
name: ROOT

TERM

my %trait_classes;

while (<$F>) {
    chomp;
    my ($curation, $variable_id, $variable_name, $variable_synonyms, $context_of_use, $growth_stage, $variable_status, $variable_xref, $institution, $scientist, $date, $language, $crop, $trait_id, $trait_name, $trait_class, $trait_description, $trait_synonyms, $main_trait_abbr, $alternative_trait_abbr, $entity, $attribute, $trait_status, $trait_xref, $method_id, $method_name, $method_class, $method_description, $formula, $method_reference, $scale_id, $scale_name, $scale_class, $decimal_places, $lower_limit, $upper_limit, $scale_xref, @categories)  = split /\t/;


    print STDERR "TRAIT CLASS = $trait_class\n";
    $trait_classes{$trait_class}++;



    
    print <<TERM;
[Term]
id: $trait_id
name: $trait_name
def: $trait_description
is_a: $trait_class ! $trait_class

[Term]
id: $variable_id
name: $variable_name
def: $trait_description $method_name $scale_name
relationship: variable_of $trait_id ! $trait_name

TERM

}


foreach my $k (keys %trait_classes) {

    print <<TERM;

[Term]
id: $k
name: $k
is_a: ROOT ! ROOT

TERM


}
