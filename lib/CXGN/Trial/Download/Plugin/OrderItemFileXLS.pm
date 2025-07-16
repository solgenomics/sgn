package CXGN::Trial::Download::Plugin::OrderItemFileXLS;

=head1 NAME

CXGN::Trial::Download::Plugin::OrderItemFileXLS

=head1 SYNOPSIS

This plugin module is loaded from CXGN::Trial::Download

------------------------------------------------------------------

For downloading order item file for fieldbook data collection (as used from CXGN::Trial::Download->trial_download):

my $plugin = "OrderItemFileXLS";

my $download = CXGN::Trial::Download->new({
    bcs_schema => $schema,
    trial_id => $c->stash->{trial_id},
    filename => $tempfile,
    format => $plugin,
});
my $error = $download->download();
my $file_name = $trial_id . "_" . "$what" . ".$format";
$c->res->content_type('Application/'.$format);
$c->res->header('Content-Disposition', qq[attachment; filename="$file_name"]);
my $output = read_file($tempfile);
$c->res->body($output);


=head1 AUTHORS

=cut

use Moose::Role;
use Data::Dumper;
use Spreadsheet::WriteExcel;
use Excel::Writer::XLSX;
use CXGN::Stock::Order;

sub verify {
    return 1;
}

sub download {
    my $self = shift;
    my $schema = $self->bcs_schema,
    my $people_schema = $self->people_schema();
    my $dbh = $self->dbh();
    my $order_id = $self->trial_id;
    my $user_id = $self->user_id;
    my $ss = Spreadsheet::WriteExcel->new($self->filename());

    my $ws = $ss->add_worksheet();

    my @header = ('order_tracking_name', 'order_tracking_id', 'item_name', 'order_number', 'item_number', 'required_quantity', 'required_stage');

    my $col_count = 0;
    foreach (@header){
        $ws->write(0, $col_count, $_);
        $col_count++;
    }

    my $row_count = 1;
    my $tracking_info;
    if (!defined $order_id || $order_id eq '') {
        my $order_obj = CXGN::Stock::Order->new({ bcs_schema => $schema, dbh => $dbh, people_schema => $people_schema, order_to_id => $user_id});
        $tracking_info = $order_obj->get_active_item_tracking_info();
    } else {
        my $order_obj = CXGN::Stock::Order->new({ bcs_schema => $schema, dbh => $dbh, people_schema => $people_schema, order_to_id => $user_id, sp_order_id => $order_id});
        $tracking_info = $order_obj->get_tracking_info();
    }

    my @all_item_info = @$tracking_info;

    for my $k (0 .. $#all_item_info) {
        for my $l (0 .. $#header) {
            $ws->write($row_count, $l, $all_item_info[$k][$l]);
        }
        $row_count++;
    }

}

1;
