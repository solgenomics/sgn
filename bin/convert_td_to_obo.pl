
=head1 NAME

convert_rd_to_obo.pl - script to convert trait dictionary file from CO to obo format. Input TD file needs to be in .xls format

=head1 SYNOPSIS

perl convert_td_to_obo.pl  -f trait dictionary file <.xls format>  -o output file name <.obo format> 

=head1 DESCRIPTION

This script currently prints the following fields:

    [Term]
    id: $prefix:$accession
    name: $cvterm_name
    namespace: $namespace
    def: "$def" #if the cvterm 'definition' field is populated
    is_obsolete: true #if cvterm is_obsolete field is 'true'
    synonym: $synonym_name []  # one row for each synonym
    xref: $xref_cvterm [] # one row for each cvterm xref that is not for the cvterm is_for_definition
    is_a: $cvterm # one row for each is_a relationship object
    relationship: $typedef $cvterm # one row for each relationship type that is not is_a (e.g. variable_of, method_of, scale_of)

    --------------------------------------------

    Example:

    [Term]
    id: CO_334:0000009
    name: initial vigor assessment 1-7
    namespace: cassava_trait
    def: "Visual assessment of plant vigor during establishment scored one month after planting. 3 = Not vigorous, 5 = Medium vigor, 7 = highly vigorous." [CO:curators]
    synonym: "Can't fall when there is strong wind" EXACT []
    synonym: "IVig_IITAVisScg_1to7" EXACT []
    synonym: "vigor" EXACT []
    xref: TO:0000250
    is_a: CO_334:0001000 ! Variables
    is_a: CO_334:0002010 ! Farmer trait
    relationship: variable_of CO_334:0000386 ! Initial vigor
    relationship: variable_of CO_334:0010228 ! Visual Rating: Initial vigor_method
    relationship: variable_of CO_334:0100434 ! 7pt scale

    ------------------------------------------


=head1 AUTHOR

Naama Menda <nm249@cornell.edu>

=cut


#!/usr/bin/perl

use strict;
#use warnings;
use Spreadsheet::ParseExcel;
use Getopt::Std;
use DateTime;
use File::Slurp;

my %opts;
getopts('f:o:n:m:s:c:p:', \%opts);

# Check for required arguments
die "Usage: $0 -f <input_file> -o <output_file> -p <ontology id prefix. e.g. CO_325> -n <trait namespace> -c [crop name - can be used as prefix for the namespaces] -m [method namespace ] -s [ scale namespace ] \n" unless $opts{f} && $opts{n} && $opts{p};

my $file = $opts{f};  # Input file
my $output_file = $opts{o} || "outfile.obo";  # Output file
my $trait_namespace = $opts{n} || $opts{c} . "_trait";
my $method_namespace = $opts{m} || $opts{c} . "_method";
my $scale_namespace = $opts{s} || $opts{c} . "_scale";
my $prefix = $opts{p} ;

my $parser   = Spreadsheet::ParseExcel->new();
my $workbook = $parser->parse($file);

if ( !defined $workbook ) {
    die $parser->error(), ".\n";
}

#Data has to be in the first worksheet
my $worksheet = $workbook->worksheet(0);


#curation	Variable ID	Variable name	Variable synonyms	Context of use	Growth stage	Variable status	Variable Xref	Institution	Scientist	Date	Language	Crop
#Trait ID	Trait name	Trait class	Trait description	Trait synonyms	Main trait abbreviation	Alternative trait abbreviations	Entity	Attribute	Trait status	Trait Xref
#Method ID	Method name	Method class	Method description	Formula	Method reference
#Scale ID	Scale name	Scale class	Decimal places	Lower limit	Upper limit	Scale Xref	Category 1	Category 2	Category 3	Category 4	Category 5	Category 6	Category 7	Category 8	Category 9	Category 10

 my %column_map = (
     'Variable ID'          => 'variable_id_col',
     'Variable name'        => 'variable_name_col',
     'Variable synonyms'    => 'variable_synonyms_col',
     'Variable status'      => 'variable_status_col',
     'Variable label'       => 'variable_label_col',
     'Variable name'        => 'variable_name_col',
     'Variable description' => 'variable_def_col',
     'Variable Xref'        => 'variable_xref_col',
     'Trait ID'             => 'trait_id_col',
     'Trait name'           => 'trait_name_col',
     'Trait class'          => 'trait_class_col',
     'Trait description'    => 'trait_def_col',
     'Trait synonyms'       => 'trait_synonyms_col',
     'Trait status'         => 'trait_status_col',
     'Trait Xref'        => 'trait_xref_col',
     'Method ID'            => 'method_id_col',
     'Method name'          => 'method_name_col',
     'Method class'         => 'method_class_col',
     'Method description'   => 'method_def_col',
     'Formula'              => 'formula_col',
     'Scale ID'             => 'scale_id_col',
     'Scale name'           => 'scale_name_col',
     'Scale class'          => 'scale_class_col',
     'Lower limit'          => 'lower_limit_col',
     'Upper limit'          => 'upper_limit_col',
     'Category 1'           => 'category_1_col',
     'Category 2'           => 'category_2_col',
     'Category 3'           => 'category_3_col',
     'Category 4'           => 'category_4_col',
     'Category 5'           => 'category_5_col',
     'Category 6'           => 'category_6_col',
     'Category 7'           => 'category_7_col',
     'Category 8'           => 'category_8_col',
     'Category 9'           => 'category_9_col',
     'Category 10'          => 'category_10_col',
 );


# Map headers to columns dynamically
foreach my $col (0 .. $worksheet->col_range()) {
    my $header = $worksheet->get_cell(0, $col)->value();
    if (exists $column_map{$header}) {
        no strict 'refs'; # Allow dynamic variable names
        ${ $column_map{$header} } = $col;
    }
}

my $start_row =  1;
my $end_row   = $worksheet->row_range();

my @output;

#these are for creating is_a, method_of, and scale_of relationships.
#Need to map the actual trait, method, and scale parent terms from the TD file to the IDs that may be in the database,
#or to create them dynamically
my $trait_class_id  = $prefix . ":Trait";
my $method_class_id = $prefix . ":Method";
my $scale_class_id  = $prefix . ":Scale";


for my $row ($start_row .. $end_row) {
    my %cell_values;

    # Retrieve cell values for the current row
    foreach my $header (keys %column_map) {
        no strict 'refs'; # Allow dynamic variable names
        my $col_var = $column_map{$header};
        my $col = ${$col_var};
        my $cell = $worksheet->get_cell($row, $col);
        $cell_values{$col_var} = $cell ? $cell->value() : undef;
    }

    # Access the values for the current row
    my $variable_id   = $cell_values{'variable_id_col'};
    my $variable_name = $cell_values{'variable_name_col'};
    my $variable_def  = $cell_values{'variable_def_col'};;
    # Check if required columns are found
    die "Error: 'Variable ID' column not found.\n"   unless defined $variable_id;
    die "Error: 'Variable name' column not found.\n" unless defined $variable_name;

    my $var_synonyms_list = undef;
    my $variable_synonyms = $cell_values{'variable_synonyms_col'};
    my @var_synonyms = split(/\s*,\s*/, $variable_synonyms);
    foreach my $synonym (@var_synonyms) {
        $var_synonyms_list .= "synonym: \"$synonym\" EXACT []\n";
    }

    my $variable_status = $cell_values{'variable_status_col'};
    my $variable_xref = $cell_values{'variable_xref_col'};

    my $trait_id      = $cell_values{'trait_id_col'};
    my $trait_name    = $cell_values{'trait_name_col'};
    my $trait_class        = $cell_values{'trait_class_col'};
    my $trait_def          = $cell_values{'trait_def_col'};
    my $trait_synonyms     = $cell_values{'trait_synonyms_col'};

    my $trait_synonyms_list;
    my @trait_synonyms = split(/\s*,\s*/, $trait_synonyms) if $trait_synonyms;
    foreach my $synonym (@trait_synonyms) {
        $trait_synonyms_list .= "synonym: \"$synonym\" EXACT []\n";
    }

    my $trait_status = $cell_values{'trait_status_col'};

    my $trait_xref = $cell_values{'trait_xref_col'};

    my $method_id          = $cell_values{'method_id_col'};
    my $method_name        = $cell_values{'method_name_col'};
    my $method_class       = $cell_values{'method_class_col'};
    my $method_description = $cell_values{'method_description_col'};
    my $method_formula            = $cell_values{'formula_col'};

    my $scale_id           = $cell_values{'scale_id_col'};
    my $scale_name         = $cell_values{'scale_name_col'};
    my $scale_class        = $cell_values{'scale_class_col'};
    my $lower_limit        = $cell_values{'lower_limit_col'};
    my $upper_limit        = $cell_values{'upper_limit_col'};
    my $category_1         = $cell_values{'category_1_col'};
    my $category_2         = $cell_values{'category_2_col'};
    my $category_3         = $cell_values{'category_3_col'};
    my $category_4         = $cell_values{'category_4_col'};
    my $category_5         = $cell_values{'category_5_col'};
    my $category_6         = $cell_values{'category_6_col'};
    my $category_7         = $cell_values{'category_7_col'};
    my $category_8         = $cell_values{'category_8_col'};
    my $category_9         = $cell_values{'category_9_col'};
    my $category_10        = $cell_values{'category_10_col'};

    #print upper_value and lower_value and the scale categories in the scale definition field
    my $categories = join(", ",
        grep { defined }
        map { $cell_values{"category_${_}_col"} } (1..10)
    );
    $categories = "categories: $categories" if $categories;

    # Generate the final scale definition string
    my $scale_def = join(", ",
        grep { defined }
        (
            $cell_values{'lower_limit_col'} ? "lower_limit: $cell_values{'lower_limit_col'}" : undef,
            $cell_values{'upper_limit_col'} ? "upper_limit: $cell_values{'upper_limit_col'}" : undef,
            $categories
        )
    );


    # Add variable output in .obo format
    push @output, "[Term]\n";
    push @output, "id: $variable_id\n";
    push @output, "name: $variable_name\n";
    push @output, "namespace: $trait_namespace\n";
    push @output, "def: \"$variable_def\"\n" if $variable_def;
    push @output, $var_synonyms_list if $var_synonyms_list;
    push @output, "relationship: variable_of $trait_id ! $trait_name \n";
    push @output, "relationship: variable_of $method_id ! $method_name \n" if $method_id;
    push @output, "relationship: variable_of $scale_id ! $scale_name \n" if $scale_id;
    my $obsolete_var = $variable_status =~ /^\s*obsolete\s*$/i ? "is_obsolete: true\n\n" : "\n";
    my $xref_var = $variable_xref ? "xref: $variable_xref\n" : undef;
    push @output, $xref_var;
    push @output, $obsolete_var;

    #trait output
    push @output, "[Term]\n";
    push @output, "id: $trait_id\n";
    push @output, "name: $trait_name\n";
    push @output, "namespace: $trait_namespace\n";
    push @output, "def: \"$trait_def\"\n" if $trait_def;
    push @output, $trait_synonyms_list  if $trait_synonyms_list;
    push @output, "is_a: $trait_class_id ! $trait_class \n" ;
    my $obsolete_trait = $trait_status =~ /^\s*obsolete\s*$/i ? "is_obsolete: true\n\n" : "\n";
    my $xref_trait = $trait_xref ? "xref: $trait_xref\n" : undef;
    push @output, $xref_trait;
    push @output, $obsolete_trait;


    #method output
    push @output, "[Term]\n";
    push @output, "id: $method_id\n";
    push @output, "name: $method_name\n";
    push @output, "namespace: $method_namespace\n";
    push @output, "def: \"$method_formula\"\n" if $method_formula;
    push @output, "is_a: $method_class_id ! $method_class \n\n" if $method_class;

    #scale_output
    push @output, "[Term]\n";
    push @output, "id: $scale_id\n";
    push @output, "name: $scale_name\n";
    push @output, "namespace: $scale_namespace\n";
    push @output, "def: \"$scale_def\"\n" if $scale_def;
    push @output, "is_a: $scale_class_id ! $scale_class \n\n" if $scale_class;

}

my $now = DateTime->now;
my $date = $now;
my $date_mdy = join(':', $now->month, $now->day, $now->year);
my $time_hm = join(':', $now->hour, sprintf("%02d", $now->minute));

my $obo_header =
"format-version: 1.2
date: $date_mdy $time_hm
default-namespace: $trait_namespace
ontology: $trait_namespace\n\n";

my $trait_root_term =
"[Term]
id: $trait_class_id
name:  $trait_namespace ontology
namespace: $trait_namespace\n\n";

my $method_root_term =
"[Term]
id: $method_class_id
name:  methods
namespace: $method_namespace\n\n";

my $scale_root_term =
"[Term]
id: $scale_class_id
name:  scales
namespace: $scale_namespace\n\n";


# Write the output to a file using File::Slurp
write_file($output_file, $obo_header . $trait_root_term . $method_root_term . $scale_root_term);
append_file($output_file, @output);

print "Conversion to obo complete. Output saved to '$output_file'.\n";


#[Term]
#id: CO_325:0000021
#name: monthly leaf emission rate
#namespace: BananaTrait
#def: "A rate that expresses the number of leaves that have emerged from the pseudostem in a month." []
#synonym: "LER" EXACT []
#is_a: CO_325:1000005 ! Physiological
