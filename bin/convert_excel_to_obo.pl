
=head1 NAME

convert_excel_to_obo - a script to convert a spreadsheet based representation of an ontology to an obo file format

=head1 DESCRIPTION

Based on CXGN::File::Parse, this script can parse tab delimited or Excel formats (xls or xlsx) as follows:

perl convert_excel_to_obo.pl file.xlsx

=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>

October 2024

=cut

use strict;

use Getopt::Std;
use CXGN::File::Parse;

use vars ($opt_n, $opt_i, $opt_o, $opt_h);

getopts('n:i:o:h');

my $file = $opt_i;

my @col_headers = ("Variable"," Trait name", "Trait class", "Trait description", "Trait synonyms", "Main trait abbreviation", "Entity", "Attribute", "Method Name", "Method class", "Method description", "Method Abbreviation", "Formula", "Scale name", "Scale abbreviation", "Scale class", "Category 1", "Category 2", "Category 3", "Category 4", "Category 5", "Category 6", "Category 7", "Category 8", "Category 9", "Category 10", "Category 11", "Category 12" );

my $parser = CXGN::File::Parse->new( file => $file );

my $parsed = $parser->parse();

if ($parsed->{errors}) {
    die "The following errors occurred while parse file $file: $parsed->{errors}\n";
}

my $data = $parsed->{data};

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





 

    
#    my ($curation, $variable_id, $variable_name, $variable_synonyms, $context_of_use, $growth_stage, $variable_status, $variable_xref, $institution, $scientist, $date, $language, $crop, $trait_id, $trait_name, $trait_class, $trait_description, $trait_synonyms, $main_trait_abbr, $alternative_trait_abbr, $entity, $attribute, $trait_status, $trait_xref, $method_id, $method_name, $method_class, $method_description, $formula, $method_reference, $scale_id, $scale_name, $scale_class, $decimal_places, $lower_limit, $upper_limit, $scale_xref, @categories)  = split /\t/;

foreach my $d (@$data) {
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
