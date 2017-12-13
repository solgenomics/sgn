
package CXGN::List::Validate::Plugin::LabelDesign;

use Moose;
use Data::Dumper;
use Scalar::Util qw(looks_like_number);

# Example List Contents
# "page_format":"US Letter PDF"
# "page_width":611
# "page_height":790.7
# "left_margin":13.68
# "top_margin":36.7
# "horizontal_gap":10
# "vertical_gap":0
# "number_of_columns":3
# "number_of_rows":10
# "copies_per_plot":"1"
# "sort_order":"plot_number"
# "label_format":"1\" x 2 5/8\""
# "label_width":189
# "label_height":72
# "element0": {"x":"54.83245849609375","y":"20.835063934326172","height":66.1875,"width":422.4375,"scale":["1","1"],"value":"{accession_name}","type":"PDFText","font":"Times","size":"59"}
# "element1": {"x":"14.753715515136719","y":"61.99702453613281","height":126,"width":126,"scale":["1","1"],"value":"{plot_name}","type":"QRCode","font":null,"size":"6"}
# "element2": {"x":"189.15045166015625","y":"168.15155029296875","height":48.140625,"width":270.453125,"scale":["1","1"],"value":"{trial_name}","type":"PDFText","font":"Times","size":"43"}
# "element3": {"x":"188.06724548339844","y":"100.9925765991211","height":36.09375,"width":68.59375,"scale":["1","1"],"value":"Plot: ","type":"PDFText","font":"Times","size":"32"}
# "element4": {"x":"269.30792236328125","y":"95.57652282714844","height":80.625,"width":74.609375,"scale":["1","1"],"value":"{plot_number}","type":"PDFText","font":"Times","size":"73"}

sub name {
    return "label_design";
}

sub validate {
    my $self = shift;
    my $schema = shift;
    my $list = shift;
    my @problems = ();

    my %page_param_check = (
        "page_format" => \&check_page_format,
        "page_width" => \&looks_like_number,
        "page_height" => \&looks_like_number,
        "left_margin" => \&looks_like_number,
        "top_margin" => \&looks_like_number,
        "horizontal_gap" => \&looks_like_number,
        "vertical_gap" => \&looks_like_number,
        "number_of_columns" => \&looks_like_number,
        "number_of_rows" => \&looks_like_number,
        "copies_per_plot" => \&looks_like_number,
        "sort_order" => \&check_sort_order,
        "label_format" => \&check_label_format,
        "label_width" => \&looks_like_number,
        "label_height" => \&looks_like_number,
    );

    my %element_check = (
        "x" => \&looks_like_number,
        "y" => \&looks_like_number,
        "height" => \&looks_like_number,
        "width" => \&looks_like_number,
        "scale" => \&check_scale,
        "value" => \&check_field,
        "type" => \&check_type,
        "font" => \&check_font,
        "size" => \&looks_like_number,
    );

    foreach my $list_item (@$list) {
        #print STDERR "List item is: ".Dumper($list_item)."\n";

        my ($key, $value) = split(":", $list_item);
        if ( $key =~ m/element/ ) {
            print STDERR "Key $key matched element\n";
            # split again and run element checks
            my @element_items = split(",", $value);
            print STDERR "Element items are @element_items\n";
            foreach my $element_item (@element_items) {
                print STDERR "Element item is $element_item\n";
                my ($key, $value) = split(":", $list_item);
                print STDERR "Element item Key is $key and value is $value\n";
                $element_check{$key}($value) ? print STDERR "Check returned: ".$element_check{$key}($value) : push @problems, $list_item;
            }
        } else {
            # run page param checks
            $page_param_check{$key}($value) ? print STDERR "Check returned: ".$page_param_check{$key}($value) : push @problems, $list_item;
        }
    }

    # print STDERR "Total missing = ".Dumper(@missing)."\n";
    return { missing => \@problems };

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
    );
    return $valid_orders{$order};
}

sub check_scale {
    my $scale = shift;
    my ($x,$y) = split ",", $scale;
    looks_like_number($x) ? 1 : return 0;
    looks_like_number($y) ? return 1 : return 0;
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
    return $valid_fields{$field};
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

1;
