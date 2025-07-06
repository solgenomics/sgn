
=head1 NAME

convert_td_to_obo.pl - script to convert trait dictionary file from CO to obo format. Input TD file needs to be in .xlsx format

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
use warnings;
use Spreadsheet::ParseXLSX;
use Getopt::Std;
use DateTime;
use File::Slurp;

my %opts;
getopts('f:o:n:m:s:c:p:', \%opts);

die "Usage: $0 -f <input_file> -o <output_file> -p <ontology id prefix. e.g. CO_325> -n <trait namespace> -c [crop name] -m [method namespace] -s [scale namespace] \n"
    unless $opts{f} && $opts{n} && $opts{p};

my $file             = $opts{f};
my $output_file      = $opts{o} || "outfile.obo";
my $trait_namespace  = $opts{n} || $opts{c} . "_trait";
my $method_namespace = $opts{m} || $opts{c} . "_method";
my $scale_namespace  = $opts{s} || $opts{c} . "_scale";
my $prefix           = $opts{p};

my $parser = Spreadsheet::ParseXLSX->new();
my $workbook = $parser->parse($file);

die "Failed to parse Excel file: $file\n" unless defined $workbook;

my $worksheet = $workbook->worksheet(0);
die "No worksheet found in the Excel file\n" unless defined $worksheet;

my ($row_min, $row_max) = $worksheet->row_range();
my ($col_min, $col_max) = $worksheet->col_range();

my (
    $variable_id_col, $variable_name_col, $variable_synonyms_col, $variable_status_col,
    $variable_label_col, $variable_def_col, $variable_xref_col,
    $trait_id_col, $trait_name_col, $trait_class_col, $trait_def_col, $trait_synonyms_col, $trait_status_col, $trait_xref_col,
    $method_id_col, $method_name_col, $method_class_col, $method_def_col, $formula_col,
    $scale_id_col, $scale_name_col, $scale_class_col, $lower_limit_col, $upper_limit_col,
    $category_1_col, $category_2_col, $category_3_col, $category_4_col, $category_5_col,
    $category_6_col, $category_7_col, $category_8_col, $category_9_col, $category_10_col
);

my %column_map = (
    'Variable ID'          => \$variable_id_col,
    'Variable name'        => \$variable_name_col,
    'Variable synonyms'    => \$variable_synonyms_col,
    'Variable status'      => \$variable_status_col,
    'Variable label'       => \$variable_label_col,
    'Variable description' => \$variable_def_col,
    'Variable Xref'        => \$variable_xref_col,
    'Trait ID'             => \$trait_id_col,
    'Trait name'           => \$trait_name_col,
    'Trait class'          => \$trait_class_col,
    'Trait description'    => \$trait_def_col,
    'Trait synonyms'       => \$trait_synonyms_col,
    'Trait status'         => \$trait_status_col,
    'Trait Xref'           => \$trait_xref_col,
    'Method ID'            => \$method_id_col,
    'Method name'          => \$method_name_col,
    'Method class'         => \$method_class_col,
    'Method description'   => \$method_def_col,
    'Formula'              => \$formula_col,
    'Scale ID'             => \$scale_id_col,
    'Scale name'           => \$scale_name_col,
    'Scale class'          => \$scale_class_col,
    'Lower limit'          => \$lower_limit_col,
    'Upper limit'          => \$upper_limit_col,
    'Category 1'           => \$category_1_col,
    'Category 2'           => \$category_2_col,
    'Category 3'           => \$category_3_col,
    'Category 4'           => \$category_4_col,
    'Category 5'           => \$category_5_col,
    'Category 6'           => \$category_6_col,
    'Category 7'           => \$category_7_col,
    'Category 8'           => \$category_8_col,
    'Category 9'           => \$category_9_col,
    'Category 10'          => \$category_10_col,
);

for my $col ($col_min .. $col_max) {
    my $cell = $worksheet->get_cell($row_min, $col);
    next unless $cell;
    my $header = $cell->value();
    $header =~ s/^\s+|\s+\$//g;
    if (exists $column_map{$header}) {
        ${ $column_map{$header} } = $col;
    }
}

die "Error: 'Variable ID' column not found.\n"   unless defined $variable_id_col;
die "Error: 'Variable name' column not found.\n" unless defined $variable_name_col;

my $trait_class_id  = "$prefix:Trait";
my $method_class_id = "$prefix:Method";
my $scale_class_id  = "$prefix:Scale";

my @output;

ROW_LOOP:
for my $row ($row_min + 1 .. $row_max) {
    my $has_data = 0;
    for my $col ($col_min .. $col_max) {
        my $cell = $worksheet->get_cell($row, $col);
        if ($cell && defined $cell->value() && $cell->value() =~ /\S/) {
            $has_data = 1;
            last;
        }
    }
    last ROW_LOOP unless $has_data;


    my %cell_values;
    for my $header (keys %column_map) {
        my $col = ${ $column_map{$header} };
        next unless defined $col;
        my $cell = $worksheet->{Cells}[$row][$col];
        $cell_values{$header} = $cell ? $cell->{Val} : undef;
    }

    my $variable_id = $cell_values{'Variable ID'};
    #next unless defined $variable_id;

    my $variable_name = $cell_values{'Variable name'};
    my $variable_def = $cell_values{'Variable description'};

    my $var_synonyms_list = '';
    if (my $variable_synonyms = $cell_values{'Variable synonyms'}) {
        my @syns = split /\s*,\s*/, $variable_synonyms;
        $var_synonyms_list .= "synonym: \"$_\" EXACT []\n" for @syns;
    }

    my $trait_id   = $cell_values{'Trait ID'};
    my $trait_name = $cell_values{'Trait name'};
    my $trait_def  = $cell_values{'Trait description'};

    my $trait_synonyms_list = '';
    if (my $trait_synonyms = $cell_values{'Trait synonyms'}) {
        my @syns = split /\s*,\s*/, $trait_synonyms;
        $trait_synonyms_list .= "synonym: \"$_\" EXACT []\n" for @syns;
    }

    my $categories = join(", ", grep { defined } map { $cell_values{"Category $_"} } 1 .. 10);
    $categories = "categories: $categories" if $categories;

    my $scale_def = join(", ", grep { defined && $_ ne '' } (
        $cell_values{'Lower limit'} ? "lower_limit: $cell_values{'Lower limit'}" : undef,
        $cell_values{'Upper limit'} ? "upper_limit: $cell_values{'Upper limit'}" : undef,
        $categories
    ));

    # Variable
    push @output, "[Term]\n";
    push @output, "id: $variable_id\n";
    push @output, "name: $variable_name\n";
    push @output, "namespace: $trait_namespace\n";
    push @output, "def: \"$variable_def\"\n" if $variable_def;
    push @output, $var_synonyms_list if $var_synonyms_list;
    push @output, "relationship: variable_of $trait_id ! $trait_name \n";
    push @output, "relationship: variable_of $cell_values{'Method ID'} ! $cell_values{'Method name'} \n" if $cell_values{'Method ID'};
    push @output, "relationship: variable_of $cell_values{'Scale ID'} ! $cell_values{'Scale name'} \n" if $cell_values{'Scale ID'};
    push @output, "xref: $cell_values{'Variable Xref'}\n" if $cell_values{'Variable Xref'};
    push @output, "is_obsolete: true\n\n" if $cell_values{'Variable status'} =~ /^\s*obsolete\s*\$/i;
    push @output, "\n";

    # Trait
    push @output, "[Term]\n";
    push @output, "id: $trait_id\n";
    push @output, "name: $trait_name\n";
    push @output, "namespace: $trait_namespace\n";
    push @output, "def: \"$trait_def\"\n" if $trait_def;
    push @output, $trait_synonyms_list if $trait_synonyms_list;
    push @output, "is_a: $trait_class_id ! $cell_values{'Trait class'} \n";
    push @output, "xref: $cell_values{'Trait Xref'}\n" if $cell_values{'Trait Xref'};
    push @output, "is_obsolete: true\n\n" if $cell_values{'Trait status'} =~ /^\s*obsolete\s*\$/i;
    push @output, "\n";

    # Method
    push @output, "[Term]\n";
    push @output, "id: $cell_values{'Method ID'}\n";
    push @output, "name: $cell_values{'Method name'}\n";
    push @output, "namespace: $method_namespace\n";
    push @output, "def: \"$cell_values{'Formula'}\"\n" if $cell_values{'Formula'};
    push @output, "is_a: $method_class_id ! $cell_values{'Method class'} \n\n" if $cell_values{'Method class'};

    # Scale
    push @output, "[Term]\n";
    push @output, "id: $cell_values{'Scale ID'}\n";
    push @output, "name: $cell_values{'Scale name'}\n";
    push @output, "namespace: $scale_namespace\n";
    push @output, "def: \"$scale_def\"\n" if $scale_def;
    push @output, "is_a: $scale_class_id ! $cell_values{'Scale class'} \n\n" if $cell_values{'Scale class'};

}
my $now = DateTime->now;
my $date_mdy = join(':', $now->month, $now->day, $now->year);
my $time_hm  = join(':', $now->hour, sprintf("%02d", $now->minute));

my $obo_header = "format-version: 1.2\ndate: $date_mdy $time_hm\ndefault-namespace: $trait_namespace\nontology: $trait_namespace\n\n";

my $trait_root_term = "[Term]\nid: $trait_class_id\nname:  $trait_namespace ontology\nnamespace: $trait_namespace\n\n";
my $method_root_term = "[Term]\nid: $method_class_id\nname:  methods\nnamespace: $method_namespace\n\n";
my $scale_root_term = "[Term]\nid: $scale_class_id\nname:  scales\nnamespace: $scale_namespace\n\n";

write_file($output_file, $obo_header . $trait_root_term . $method_root_term . $scale_root_term);
append_file($output_file, @output);

print "Conversion to obo complete. Output saved to '$output_file'.\n";
