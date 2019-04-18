
package CXGN::Trial::TrialDesign::Plugin::genotyping_plate;

use Moose::Role;

sub create_design {
    sub _get_genotyping_plate {
    my $self = shift;
    my %gt_design;
    my @stock_list;

    if ($self->has_stock_list()) {
        @stock_list = @{$self->get_stock_list()};
        my $number_of_stocks = scalar(@stock_list);
        if ($number_of_stocks > $self->get_block_size) {
            die "Too many to fit on one plate! $number_of_stocks > ".$self->get_block_size;
        }
    }
    else {
        die "No stock list specified\n";
    }

    my $blank = $self->get_blank ? $self->get_blank : ' ';

    if ($self->get_block_size == '96'){
        foreach my $row ("A".."H") {
            foreach my $col (1..12) {
                my $well= sprintf "%s%02d", $row, $col;

                if ($well eq $blank) {
                    $gt_design{$well} = {
                        plot_name => $self->get_trial_name()."_".$well."_BLANK",
                        stock_name => "BLANK",
                        plot_number => $well,
                        row_number => $row,
                        col_number => $col,
                        is_blank => 1
                    };
                }
                elsif (@stock_list) {
                    $gt_design{$well} = {
                        plot_name => $self->get_trial_name()."_".$well,
                        stock_name => shift(@stock_list),
                        plot_number => $well,
                        row_number => $row,
                        col_number => $col,
                        is_blank => 0
                    };
                }
            }
        }
    }
    if ($self->get_block_size == '384'){
        foreach my $row ("A".."P") {
            foreach my $col (1..24) {
                my $well= sprintf "%s%02d", $row, $col;

                if ($well eq $blank) {
                    $gt_design{$well} = {
                        plot_name => $self->get_trial_name()."_".$well."_BLANK",
                        stock_name => "BLANK",
                        plot_number => $well,
                        row_number => $row,
                        col_number => $col,
                        is_blank => 1
                    };
                }
                elsif (@stock_list) {
                    $gt_design{$well} = {
                        plot_name => $self->get_trial_name()."_".$well,
                        stock_name => shift(@stock_list),
                        plot_number => $well,
                        row_number => $row,
                        col_number => $col,
                        is_blank => 0
                    };
                }
            }
        }
    }

    return \%gt_design;
}

1;
