
package CXGN::List::Validate::Plugin::LabelDesign;

use Moose;
use Data::Dumper;
use JSON::Any;
use Try::Tiny;
use Scalar::Util qw(looks_like_number);

sub name {
    return "label_design";
}

sub validate {
    my $self = shift;
    my $schema = shift;
    my $list = shift;
    my @problems = ();
    use Text::ParseWords;

    my %page_param_check = (
        "page_format" => \&check_page_format,
        "page_width" => \&check_is_numeric,
        "page_height" => \&check_is_numeric,
        "left_margin" => \&check_is_numeric,
        "top_margin" => \&check_is_numeric,
        "horizontal_gap" => \&check_is_numeric,
        "vertical_gap" => \&check_is_numeric,
        "number_of_columns" => \&check_is_numeric,
        "number_of_rows" => \&check_is_numeric,
        "copies_per_plot" => \&check_is_numeric,
        "sort_order" => \&check_sort_order,
        "label_format" => \&check_label_format,
        "label_width" => \&check_is_numeric,
        "label_height" => \&check_is_numeric,
    );

    my %element_check = (
        "x" => \&check_is_numeric,
        "y" => \&check_is_numeric,
        "height" => \&check_is_numeric,
        "width" => \&check_is_numeric,
        "value" => \&check_field,
        "type" => \&check_type,
        "font" => \&check_font,
        "size" => \&check_is_numeric,
    );

    my $JSON = "{". join(",", @$list) . "}";
    my $obj_ref;
    try {
        $obj_ref = JSON::Any->decode($JSON);
    } catch {
        push @problems, "\nInvalid JSON in list items\n";
        push @problems, "$_\n";
    };

    if ( scalar @problems ) {
        return { missing => \@problems };
    }

    my %obj = %{$obj_ref};

    foreach my $key (keys %obj) {
        my $value = $obj{$key};
        if ( $key =~ m/element/ ) {
            my %elem_hash = %{$value};
            foreach my $elem_key (keys %elem_hash) {
                my $elem_value = $elem_hash{$elem_key};
                if (exists $element_check{$elem_key}) {
                    $element_check{$elem_key}($elem_value) ? print STDERR "Check returned: ".$element_check{$elem_key}($elem_value)."\n" : push @problems, $elem_key . ":" . $elem_value;
                }
                else {
                    push @problems, "\n$elem_key : $elem_value";
                }
            }
        } else {
             #print STDERR "Key is $key and value is $value\n";
             if (exists $page_param_check{$key}) {
                 $page_param_check{$key}($value) ? print STDERR "Check returned: ".$page_param_check{$key}($value) : push @problems, $key . ":" . $value;
             }
             else {
                 push @problems, "\n$key : $value";
             }
        }
    }

    return { missing => \@problems };

}

sub check_is_numeric {
    my $num = shift;
    looks_like_number($num) ? return 1 : return 0;
}

sub check_page_format {
    my $format = shift;
    my %valid_formats = (
        "US Letter PDF" => 1,
        "A4 PDF" => 1,
        "Zebra printer file" => 1,
        "Custom" => 1
    );
    return $valid_formats{$format};
}

sub check_label_format {
    my $format = shift;
    my %valid_formats = (
        '1" x 2 5/8"' => 1,
        '1" x 4"' => 1,
        '1 1/3" x 4"' => 1,
        '2" x 2 5/8"' => 1,
        '1 1/4" x 2"' => 1,
        'Custom' => 1,
    );
    return $valid_formats{$format};
}

sub check_sort_order {
    my $order = shift;
    my %valid_orders = (
        "accession_name" => 1,
        "plot_name" => 1,
        "plot_number" => 1,
        "rep_number" => 1,
        "row_number" => 1,
        "column_number" => 1,
        "list_order" => 1
    );
    return $valid_orders{$order};
}

sub check_field {
    my $field = shift;
    my %valid_fields = (
        "accession_id" => 1,
        "accession_name" => 1,
        "block_number" => 1,
        "col_number" => 1,
        "pedigree_string" => 1,
        "plot_id" => 1,
        "plot_name" => 1,
        "plot_number" => 1,
        "range_number" => 1,
        "rep_number" => 1,
        "row_number" => 1,
        "trial_name" => 1,
        "year" => 1,
    );
    my %return_values;
    $field =~ s/\{(.*?)\}/process_field($1,\%valid_fields,\%return_values)/ge;
    foreach my $key (keys %return_values) {
        if (!$return_values{$key}) {
            return 0;
        }
    }
    return 1;
}

sub check_type {
    my $type = shift;
    my %valid_types = (
        "PDFText" => 1,
        "ZebraText" => 1,
        "Code128" => 1,
        "QRCode" => 1,
    );
    return $valid_types{$type};
}

sub check_font {
    my $font = shift;
    my %valid_fonts = (
        "Courier" => 1,
        "Courier-Bold" => 1,
        "Courier-Oblique" => 1,
        "Courier-BoldOblique" => 1,
        "Helvetica" => 1,
        "Helvetica-Bold" => 1,
        "Helvetica-Oblique" => 1,
        "Helvetica-BoldOblique" => 1,
        "Times" => 1,
        "Times-Bold" => 1,
        "Times-Italic" => 1,
        "Times-BoldItalic" => 1,
    );
    return $valid_fonts{$font};
}

sub process_field {
    my $field = shift;
    my $valid_fields = shift;
    my $return_values = shift;
    my %valid_fields = %{$valid_fields};
    my %return_values = %{$return_values};

    print STDERR "Field is $field\n";
    if ($field =~ m/Number:/) {
        our ($placeholder, $start_num, $increment) = split ':', $field;
        my $length = length($start_num);
        #print STDERR "Increment is $increment\nKey Number is $key_number\n";
        my $custom_num =  $start_num + ($increment * 1);
        my $final_num = sprintf("%0${length}d", $custom_num);
        $return_values{$field} = looks_like_number($final_num);
    } else {
        $return_values{$field} = $valid_fields{$field};
    }
}

1;
