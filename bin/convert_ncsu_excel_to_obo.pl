
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

use utf8;
use Getopt::Std;
use Data::Dumper;
use CXGN::File::Parse;

our ($opt_n, $opt_i, $opt_o, $opt_h);

getopts('n:i:o:h');

my $file = $opt_i;
my $ontology_name = $opt_n || "GENERIC";

if (!$file) {
    die "Please privde a file using the -i parameter.";
}

print STDERR "ONTOLOGY NAME: $ontology_name\n";

my $outfile = $file.".obo";
my $cvpropfile = $file.".props";

open(my $F, ">", $outfile) || die "Can't open file $outfile\n";
open(my $G, ">", $cvpropfile) || die "Can't open cvprop file $cvpropfile for writing";

#Curation	Variable ID	Variable name	Variable label	Variable description	Variable synonyms	Context of use	Growth stage	Variable status	Variable Xref	Institution	Scientist	Date	Language	Crop	Trait ID	Entity	Attribute	Trait name	Trait class	Trait description	Trait synonyms	Main trait abbreviation	Alternative trait abbreviations	Trait status	Trait Xref	Method ID	Method name	Method class	Method description	Method Abbreviation	Formula	Method reference	Scale ID	Scale name	Scale Abbreviation	Scale class	Scale Xref	Cat 1 code	Cat 1 description	Cat 2 code	Cat 2 description	Cat 3 code	Cat 3 description	Cat 4 code	Cat 4 description	Cat 5 code	Cat 5 description	Cat 6 code	Cat 6 description	Cat 7 code	Cat 7 description	Cat 8 code	Cat 8 description	Cat 9 code	Cat 9 description	Cat 10 code	Cat 10 description

my @col_headers = ("Variable"," Term Name - BB", "Trait class", "Term Definition", "Variable Full Name", "Synonyms", "Trait - CO", "Main trait abbreviation", "Entity", "Attribute", "Method Name", "Method class", "Method description", "Method Abbreviation", "Formula", "Scale name", "Scale abbreviation", "Scale class", "Category 1", "Category 2", "Category 3", "Category 4", "Category 5", "Category 6", "Category 7", "Category 8", "Category 9", "Category 10", "Category 11", "Category 12" );

# column labels
#
my $trait_class = "Trait class";
my $trait_name = "Trait name";
my $trait_definition = "Trait description";
my $trait_synonyms = "Trait synonyms";
my $variable_synonyms = "Variable synonyms";
my $trait_id = "Trait ID";
my $variable_name = "Variable name";
my $variable_definition = "Variable description";
my $variable_label = "Variable label";
my $variable_id = "Variable ID";
my $method_id = "Method ID";
my $method_name = "Method name";
my $method_class = "Method class";
my $method_description = "Method description";
my $scale_id = "Scale ID";
my $scale_name = "Scale name";
my $scale_class = "Scale class";
my $scale_description = "Scale description";
my $scale_abbreviation = "Scale abbreviation";
my $entity = "Entity";
my $attribute = "Attribute";
my $categories = "Categories";
my $class_id = "Class ID";
my $class_name = "Class name";

my $parser = CXGN::File::Parse->new( file => $file );

my $parsed = $parser->parse();

if ($parsed->{errors}) {
    warn "The following errors occurred while parsing file $file: ".Dumper($parsed->{errors})."\n";
}

my $data = $parsed->{data};

# get all the trait classes
#
my %trait_classes;
my %traits;
my %variables;

foreach my $d (@$data) {
    $trait_classes{$d->{$trait_class}}->{count}++;
}
print STDERR "TRAIT CLASSES: ".Dumper(\%trait_classes);

foreach my $d (@$data) {
    my $tn = $d->{$trait_name};
    print STDERR "Parsing TRAIT NAME $trait_name\n";
    if (! $tn) { next; }
    $traits{$tn}->{$trait_id} = $d->{$trait_id};
    $traits{$tn}->{$trait_class} = $d->{$trait_class};

    print STDERR "TRAIT NAME $trait_name has TRAIT CLASS $d->{$trait_class}\n";
    
    $traits{$tn}->{$trait_definition} = $d->{$trait_definition};
}

print STDERR "TRAITS: ".Dumper(\%traits);



foreach my $d (@$data) {
    my $vn = $d->{$variable_name};
    if (! $vn) { next; }
    $variables{$vn}->{$variable_id} = $d->{$variable_id};
    $variables{$vn}->{$variable_synonyms} = $d->{$variable_synonyms};
    $variables{$vn}->{$trait_name} = $d->{$trait_name};
    $variables{$vn}->{$trait_definition} = $d->{$trait_definition};
    $variables{$vn}->{$entity} = $d->{$entity};
    $variables{$vn}->{$attribute} = $d->{$attribute};
    $variables{$vn}->{$method_name} = $d->{$method_name};
    $variables{$vn}->{$scale_abbreviation} = $d->{$scale_abbreviation};
    $variables{$vn}->{$variable_label} = $d->{$variable_label};
    $variables{$vn}->{$scale_name} = $d->{$scale_name};
    $variables{$vn}->{$scale_class} = $d->{$scale_class};
    $variables{$vn}->{$categories} = $d->{$categories};
    print STDERR "TERM NAME - CO IN variable = $d->{$trait_name}\n";
    $variables{$vn}->{$trait_name} = $d->{$trait_name};
    $variables{$vn}->{$trait_id} = $d->{$trait_id};
}
print STDERR "VARIABLES: ".Dumper(\%variables);

    
my $root_id = format_ontology_id($opt_n, 0);
my $count = $root_id;
my $acc = sprintf "%07d", $count; # the number after the ontology name and a colon

print STDERR "Starting at term $ontology_name:$acc ...\n";

# write obo header
#
print $F <<HEADER;
format-version: 1.2
date: 10:03:2024 17:10
saved-by: Lukas_Mueller
default-namespace: $ontology_name
ontology: CO_365

HEADER

# write cvprops header
#
print $G join("\t", "trait_name", "trait_format", "trait_default_value", "trait_minimum", "trait_maximum", "trait_categories", "trait_details")."\n";


# read header
#
my $header = <$F>;

my $root_acc = $ontology_name.":".$acc;
my $root_name = "ROOT";

print $F <<TERM;

[Term]
id: $ontology_name:$acc
name: ROOT
namespace: $ontology_name

TERM


$count++;

foreach my $k (sort keys %trait_classes) {

    print $F format_trait(
	$ontology_name,
	$traits{$k}->{$class_id},
	$traits{$k}->{$class_name},
	$traits{$k}->{$class_name},
	undef,
	$root_acc,
	$root_name,
	)."\n";

    $trait_classes{$k}->{acc} = $class_id;
#    $trait_classes{$k}->{name} = $k;
    
    $count++;
    
}

foreach my $k (sort keys %traits) {
    print $F format_trait(
	$ontology_name,
	$traits{$k}->{$trait_id},
	$traits{$k}->{$trait_name},
	$traits{$k}->{$trait_definition},
	$traits{$k}->{$trait_synonyms},     
	$traits{$k}->{$trait_id},
	$traits{$k}->{$trait_class}, # parent trait
	)."\n";
    
    $traits{$k}->{name} = $traits{$k}->{$trait_name};
    $traits{$k}->{acc} = $traits{$k}->{$trait_id};
    $count++;
}
    


foreach my $k (sort keys %variables) { 

    my $parent_trait = $variables{$k}->{$trait_name};
    my $parent_trait_id = $traits{$variables{$k}->{'Trait - CO'}}->{acc};
    my $parent_trait_name = $traits{ $variables{$k}->{'Trait -CO'}}->{name};

    print STDERR "VARIABLE: $k. PARENT TRAIT: $parent_trait\n";
    
    print $F format_variable(
	$ontology_name,
	$variables{$k}->{$variable_id},
	$k, ###$variables{$k}->{'Variable Full Name'},
	join(" - ", $variables{$k}->{$trait_definition}),
	$variables{$k}->{$trait_synonyms},
	$variables{$k}->{$trait_id},
	$variables{$k}->{$trait_name},
	
	#$traits{$variables{$k}->{'Trait - CO'}}->{acc}, # parent trait id
	#$traits{$variables{$k}->{'Trait - CO'}}->{name}, # parent trait
	
	)."\n";

    print $G format_props(
	$k, # variable name
	$ontology_name,
	$count,
	$variables{$k}->{$scale_class},
	$variables{$k}->{$categories},
	);
    
    $count++;
	
}

close($F);
close($G);

print STDERR "Script completed.\n";

sub format_props {
    my $trait_name = shift;
    my $ontology_name = shift;
    my $count = shift;
    my $trait_format = shift;
    my $categories = shift;

    my $trait_default_value = shift;
    my $trait_minimum = shift;
    my $trait_maximum = shift;
    my $trait_details = shift;

    return join ("\t", $trait_name."|".format_ontology_id($ontology_name, $count), $trait_format, $trait_default_value, $trait_minimum, $trait_maximum, $categories, $trait_details)."\n";


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
    my $synonyms = shift;
    my $parent_class_id = shift;
    my $parent_trait = shift;
    
    my %record = (
	"[Term]" => "",
	"id:" =>  $id,
	"name:" =>  $name,
	"def:" => "\"$description\" []",
	"synonym:" => $synonyms,
	"namespace:" => $ontology_code,
	"is_a:" => "$parent_class_id ! $parent_trait",
	);

    my $data = "";
    foreach my $k ("[Term]", "id:", "name:", "def:", "synonym:", "namespace:", "is_a:") {
	if (defined($record{$k})) {
	    $data .= "$k $record{$k}\n";
	}
    }

    return $data;
}


sub format_variable {
    my $ontology_name = shift;
    my $id = shift;
    my $name = shift;
    my $description = shift;
    my $synonyms = shift;
    my $parent_trait_id = shift;
    my $parent_trait_name = shift;

    #print STDERR "Parent trait name: $parent_trait_name\n";

#    my $variable_id = format_ontology_id($ontology_code, $id);
#    my $parent_trait_id = format_ontology_id($ontology_code, $parent_trait_id);
    my %record = (
	"[Term]"  => "", 
	"id:" =>  $id,
	"name:" => $name,
	"def:"=> "\"$description\" []",
	"synonym:" =>  $synonyms,
	"namespace:" => $ontology_name,
	"relationship:" => "variable_of $parent_trait_id ! $parent_trait_name",
	);

    my $data = "";
    foreach my $k ("[Term]", "id:", "name:", "def:", "synonym:", "namespace:", "relationship:") {
	if (defined($record{$k})) {
	    $data .= "$k $record{$k}\n";
	}
    }

    return $data;
}
