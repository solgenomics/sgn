
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

open(my $F, ">", $outfile) || die "Can't open file $outfile\n";

my @col_headers = ("Variable"," Trait name", "Trait class", "Trait description", "Trait synonyms", "Main trait abbreviation", "Entity", "Attribute", "Method Name", "Method class", "Method description", "Method Abbreviation", "Formula", "Scale name", "Scale abbreviation", "Scale class", "Category 1", "Category 2", "Category 3", "Category 4", "Category 5", "Category 6", "Category 7", "Category 8", "Category 9", "Category 10", "Category 11", "Category 12" );

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
    my $trait_name = $d->{'Trait name'};
    $traits{$trait_name}->{count}++;
    $traits{$trait_name}->{'Trait class'} = $d->{'Trait class'};

    print STDERR "TRAIT NAME $trait_name has TRAIT CLASS $d->{'Trait class'}\n";
    
    $traits{$trait_name}->{'Trait description'} = $d->{'Trait description'};
    $traits{$trait_name}->{'Trait synonyms'} = $d->{'Trait synonyms'};
    $traits{$trait_name}->{'Trait abbreviation'} = $d->{'Main trait abbreviation'};
}
print STDERR "TRAITS: ".Dumper(\%traits);



foreach my $d (@$data) {
    $variables{$d->{'Variable'}}->{count}++;
    $variables{$d->{'Variable'}}->{'Trait name'} = $d->{'Trait name'};
    $variables{$d->{'Variable'}}->{'Trait description'} = $d->{'Trait description'};
    $variables{$d->{'Variable'}}->{'Entity'} = $d->{'Entity'};
    $variables{$d->{'Variable'}}->{'Attribute'} = $d->{'Attribute'};
    $variables{$d->{'Variable'}}->{'Method Name'} = $d->{'Method Name'};
    $variables{$d->{'Variable'}}->{'Scale abbreviation'} = $d->{'Scale abbreviation'};
    $variables{$d->{'Variable'}}->{'Variable'} = $d->{'Variable'};
    $variables{$d->{'Variable'}}->{'Scale name'} = $d->{'Scale name'};
}
print STDERR "VARIABLES: ".Dumper(\%variables);

    
my $root_id = format_ontology_id($opt_n, 0);
my $count = $root_id;
my $acc = sprintf "%07d", $count; # the number after the ontology name and a colon

print STDERR "Starting at term $ontology_name:$acc ...\n";

# write header
#
print <<HEADER;
format-version: 1.2
date: 10:03:2024 17:10
saved-by: Lukas_Mueller
default-namespace: $ontology_name
ontology: CO_365

HEADER

# read header
#
my $header = <$F>;

my $root_acc = $acc;
my $root_name = "ROOT";

print <<TERM;

[Term]
id: $ontology_name:$acc
name: ROOT
namespace: $ontology_name

TERM


$count++;

foreach my $k (keys %trait_classes) {

    print format_trait(
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
    print format_trait(
	$ontology_name,
	$count,
	$k,
	$traits{$k}->{'Trait description'},
	$traits{$k}->{'Trait synonym'},
	$trait_classes{ $traits{$k}->{'Trait class'} }->{acc},
	$traits{$k}->{'Trait class'},
	)."\n";
    
    $traits{$k}->{name} = $k;
    $traits{$k}->{acc} = $count;
    $count++;
}
    


foreach my $k (keys %variables) { 
    # print format_trait(
    # 	$opt_n,
    # 	$count,
    # 	$k,
    # 	$variables{ $k }->{Trait synonyms},
    # 	$trait_classes{ $k->{'Trait class'} }->{id},
    # 	$trait_classes{ $k->{'Trait class'} }->{name},
    # 	);
    
    # $count++;

    print format_variable(
	$ontology_name,
	$count,
	$variables{$k}->{'Trait name'}.", ".$variables{$k}->{'Method Name'}.", ".$variables{$k}->{'Scale name'},
	join(" - ", $variables{$k}->{'Trait description'}, $variables{$k}->{'Method Name'}, $variables{$k}->{'Scale name'}),
	$k, #$variables{$k}->{'synonyms'},
	$traits{$variables{$k}->{'Trait name'}}->{acc},
	$variables{$k}->{'Trait name'},
	
	)."\n";

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

    foreach my $k ("[Term]", "id:", "name:", "def:", "synonym:", "namespace:", "is_a:") {
	if (defined($record{$k})) {
	    print "$k $record{$k}\n";
	}
    }

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
    
    foreach my $k ("[Term]", "id:", "name:", "def:", "synonym:", "namespace:", "relationship:") {
	if (defined($record{$k})) {
	    print "$k $record{$k}\n";
	}
    }
       
}
