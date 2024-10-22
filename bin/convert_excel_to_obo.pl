
=head1 NAME

convert_excel_to_obo - a script to convert a spreadsheet based representation of an ontology to an obo file format

=head1 DESCRIPTION

Based on CXGN::File::Parse, this script can parse tab delimited or Excel formats (xls or xlsx) as follows:

perl convert_excel_to_obo.pl -n CO_999 -i file.xlsx -o ontology.obo

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

my $outfile = $file.".obo";

open(my $F, ">", $outfile) || die "Can't open file $outfile\n";

my @col_headers = ("Variable"," Trait name", "Trait class", "Trait description", "Trait synonyms", "Main trait abbreviation", "Entity", "Attribute", "Method Name", "Method class", "Method description", "Method Abbreviation", "Formula", "Scale name", "Scale abbreviation", "Scale class", "Category 1", "Category 2", "Category 3", "Category 4", "Category 5", "Category 6", "Category 7", "Category 8", "Category 9", "Category 10", "Category 11", "Category 12" );

my $parser = CXGN::File::Parse->new( file => $file );

my $parsed = $parser->parse();

if ($parsed->{errors}) {
    die "The following errors occurred while parse file $file: $parsed->{errors}\n";
}

my $data = $parsed->{data};

# get all the trait classes
#
my %trait_classes;

foreach my $d (@$data) {
    $trait_classes{$d->{Trait class}}->{count}++;
}

my $root_id = 0;
my $count = $root_id;
my $acc = sprintf "%07d", $count; # the number after the ontology name and a colon

print STDERR "Starting at term $opt_n:$acc ...\n";

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
id: $acc
name: ROOT

TERM


$count++;

foreach my $k (keys %trait_classes) {

    print format_trait(
	$opt_n,
	$count,
	$k,
	undef,
	undef,
	$opt_n,
	$root_id,
	);

    $trait_classes{$k}->{acc} = $count;
    $trait_classes{$k}->{name} = $k;
    
    $count++;
    
}


foreach my $d (@$data) {
    print format_trait(
	$ontology_code,
	$count,
	$d->{Trait name},
	$d->{Trait description},
	$d->{Trait synonyms},
	$trait_classes{ $d->{Trait class} }->{id},
	$trait_classes{ $d->{Trait class} }->{name},
	);
    
    $count++;

    print format_variable(
	$ontology_code,
	$count,
	$d->{Variable},
	$d->{Trait description},
	$d->{Method name},
	$d->{Entity},
	$d->{Attribute}
	);

    $count++;
	
}



sub format_ontology_id {
    my $ontology_name = shift;
    my $acc = shift;
    
    return $ontology_name.":".sprintf "%07d", $acc;
}

sub format_trait {
    my $ontology_code = shift;
    my $id = shift;
    my $name = shift;
    my $description = shift;
    my $synonym = shift;
    my $parent_class_id = shift;
    my $parent_trait = shift;
    
    my $trait_id = format_ontology_id($ontology_code, $id);
    my $parent_trait_id = format_ontology_id($ontology_code, $parent_class_id);

    return <<TERM;
    
[Term]
id: $ontology_code:$id
name: $name
def: "$description" []
synonyms: $synonyms
is_a: $parent_trait_id ! $parent_trait

TERM

}


sub format_variable {
    my $ontology_code = shift;
    my $id = shift;
    my $name = shift;
    my $description = shift;
    my $method_name = shift;
    my $scale_name = shift;
    my $synonym = shift;
    my $relationship = shift;
    my $parent_trait_id = shift;
    my $parent_trait_name = shift;
    
    return <<TERM;
    
[Term]
id: $ontology_code:$id
name: $name	
def: "$description $method_name $scale_name" []
relationship: variable_of $parent_trait_id ! $parent_trait_name

TERM

}
