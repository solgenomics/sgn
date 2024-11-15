
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

my $outfile = $file.".obo";
my $cvpropfile = $file.".props";

open(my $F, ">", $outfile) || die "Can't open file $outfile\n";
open(my $G, ">", $cvpropfile) || die "Can't open cvprop file $cvpropfile for writing";

my @col_headers = ("Variable"," Term Name - BB", "Trait class", "Term Definition", "Variable Full Name", "Synonyms", "Trait - CO", "Main trait abbreviation", "Entity", "Attribute", "Method Name", "Method class", "Method description", "Method Abbreviation", "Formula", "Scale name", "Scale abbreviation", "Scale class", "Category 1", "Category 2", "Category 3", "Category 4", "Category 5", "Category 6", "Category 7", "Category 8", "Category 9", "Category 10", "Category 11", "Category 12" );

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
    $trait_classes{$d->{'Trait class'}}->{count}++;
}
print STDERR "TRAIT CLASSES: ".Dumper(\%trait_classes);

foreach my $d (@$data) {
    my $trait_name = $d->{'Trait - CO'};
    print STDERR "Parsing TRAIT NAME $trait_name\n";
    if (! $trait_name) { next; }
    $traits{$trait_name}->{count}++;
    $traits{$trait_name}->{'Trait class'} = $d->{'Trait class'};

    print STDERR "TRAIT NAME $trait_name has TRAIT CLASS $d->{'Trait class'}\n";
    
    $traits{$trait_name}->{'Term Definition'} = $d->{'Term Definition'};
}
print STDERR "TRAITS: ".Dumper(\%traits);



foreach my $d (@$data) {
    my $variable_name = $d->{'Variable Full Name'};
    if (! $variable_name) { next; }
    $variables{$variable_name}->{count}++;
    $variables{$variable_name}->{'Synonym'};
    $variables{$variable_name}->{'Term Name - BB'} = $d->{'Term Name - BB'};
    $variables{$variable_name}->{'Term Definition'} = $d->{'Term Definition'};
    $variables{$variable_name}->{'Entity'} = $d->{'Entity'};
    $variables{$variable_name}->{'Attribute'} = $d->{'Attribute'};
    $variables{$variable_name}->{'Method Name'} = $d->{'Method Name'};
    $variables{$variable_name}->{'Scale abbreviation'} = $d->{'Scale abbreviation'};
    $variables{$variable_name}->{'Variable'} = $d->{'Variable'};
    $variables{$variable_name}->{'Scale name'} = $d->{'Scale name'};
    $variables{$variable_name}->{'Scale class'} = $d->{'Scale class'};
    $variables{$variable_name}->{'Categories'} = $d->{'Categories'};
    print STDERR "TERM NAME - CO IN variable = $d->{'Term Name - CO'}\n";
    $variables{$variable_name}->{'Trait - CO'} = $d->{'Trait - CO'};
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

my $root_acc = $acc;
my $root_name = "ROOT";

print $F <<TERM;

[Term]
id: $ontology_name:$acc
name: ROOT
namespace: $ontology_name

TERM


$count++;

foreach my $k (keys %trait_classes) {

    print $F format_trait(
	$ontology_name,
	$count,
	$k,
	$k,
	undef,
	$ontology_name,
	$root_name,
	)."\n";

    $trait_classes{$k}->{acc} = $count;
    $trait_classes{$k}->{name} = $k;
    
    $count++;
    
}

foreach my $k (keys %traits) {
    print $F format_trait(
	$ontology_name,
	$count,
	$k,
	$traits{$k}->{'Trait description'},
	$traits{$k}->{'Trait synonym'},     
	$trait_classes{ $traits{$k}->{'Trait class'} }->{acc},  # parent id
	$traits{$k}->{'Trait class'}, # parent trait
	)."\n";
    
    $traits{$k}->{name} = $k;
    $traits{$k}->{acc} = $count;
    $count++;
}
    


foreach my $k (keys %variables) { 

    my $parent_trait = $variables{$k}->{'Trait - CO'};
    my $parent_trait_id = $traits{$variables{$k}->{'Trait - CO'}}->{acc};
    my $parent_trait_name = $traits{ $variables{$k}->{'Trait -CO'}}->{name};

    print STDERR "VARIABLE: $k. PARENT TRAIT: $parent_trait\n";
    
    print $F format_variable(
	$ontology_name,
	$count,
	$k, ###$variables{$k}->{'Variable Full Name'},
	join(" - ", $variables{$k}->{'Term Definition'}),
	$variables{$k}->{'Synonym'},
	$traits{$variables{$k}->{'Trait - CO'}}->{acc}, # parent trait id
	$traits{$variables{$k}->{'Trait - CO'}}->{name}, # parent trait
	
	)."\n";

    print $G format_props(
	$ontology_name,
	$count,
	$variables{$k}->{'Scale Class'},
	$variables{$k}->{Categories},
	);
    
    $count++;
	
}

close($F);
close($G);

print STDERR "Script completed.\n";

sub format_props {
    my $ontology_name = shift;
    my $count = shift;
    my $trait_format = shift;
    my $categories = shift;

    my $trait_default_value = shift;
    my $trait_minimum = shift;
    my $trait_maximum = shift;
    my $trait_details = shift;

    return join ("\t", format_ontology_id($ontology_name, $count), $trait_format, $trait_default_value, $trait_minimum, $trait_maximum, $categories, $trait_details)."\n";


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
    
    my $trait_id = format_ontology_id($ontology_code, $id);
    my $parent_trait_id = format_ontology_id($ontology_code, $parent_class_id);

    my %record = (
	"[Term]" => "",
	"id:" =>  $trait_id,
	"name:" =>  $name,
	"def:" => "\"$description\" []",
	"synonym:" => $synonyms,
	"namespace:" => $ontology_name,
	"is_a:" => "$parent_trait_id ! $parent_trait",
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
    my $ontology_code = shift;
    my $id = shift;
    my $name = shift;
    my $description = shift;
    my $synonyms = shift;
    my $parent_trait_id = shift;
    my $parent_trait_name = shift;

    #print STDERR "Parent trait name: $parent_trait_name\n";

    my $variable_id = format_ontology_id($ontology_code, $id);
    my $parent_trait_id = format_ontology_id($ontology_code, $parent_trait_id);
    my %record = (
	"[Term]"  => "", 
	"id:" =>  $variable_id,
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
