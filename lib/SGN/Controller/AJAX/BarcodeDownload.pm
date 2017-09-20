
=head1 NAME

=head1 DESCRIPTION

=head1 AUTHOR

=cut

package SGN::Controller::AJAX::BarcodeDownload;

use Moose;
use File::Slurp;
use PDF::Create;
use Bio::Chado::Schema::Result::Stock::Stock;
use CXGN::Stock::StockBarcode;
use Data::Dumper;
use CXGN::Stock;
use SGN::Model::Cvterm;
use Text::Template;
use Try::Tiny;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );

sub download_zpl_barcodes : Path('/barcode/download/zpl') : ActionClass('REST') {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    
    # Zebra design params, hard coded to 3x10 labels for now
    my $starting_x = 20;
    my $starting_y = 60;
    my $x_increment = 590;
    my $y_increment = 213;
    my $number_of_columns = 2; #zero index
    my $number_of_rows = 9; #zero index
    
    # hard coded for now, but could be generated from a user interface like a drag and drop grid
     my $zpl = $c->req->param("zpl_template"); #|| '^LH{ $X },{ $Y }
# ^FO5,10^AA,{ $FONT_SIZE }^FB320,5^FD{ $ACCESSION_NAME }^FS
# ^FO20,70^AA,28^FDPlot { $PLOT_NUMBER }, Rep { $REP_NUMBER }^AF4^FS
# ^FO22,70^AA,28^FD     { $PLOT_NUMBER }      { $REP_NUMBER }^AF4^FS
# ^FO20,72^AA,28^FD     { $PLOT_NUMBER }      { $REP_NUMBER }^AF4^FS
# ^FO20,105^AA,22^FD{ $TRIAL_NAME } { $YEAR }^FS
# ^FO10,140^AA,28^FB300,5^FD{ $CUSTOM_TEXT }^FS
# ^FO325,5^BQ,,{ $QR_SIZE }^FD   { $PLOT_NAME }^FS
# ';
    my $zpl_template = Text::Template->new(
        type => 'STRING',
        source => $zpl,
    );
    
    # retrieve variable params
    my $trial_id = $c->req->param("trial_id");
    my $labels_per_stock = $c->req->param("num_labels");# || 1;
    my $custom_text = $c->req->param("custom_text") || '';
    my $include_pedigree = $c->req->param("include_pedigree");
    print STDERR "trial id is $trial_id\n num labels is $labels_per_stock\n zpl is $zpl\n";
    #my $order_by = $c->req->param("custom_text") || 'plot_number';
    
    my $trial_rs = $schema->resultset("Project::Project")->search({ project_id => $trial_id });
    if (!$trial_rs) {
        my $error = "Trial with id $trial_id does not exist. Can't create labels.";
        print STDERR $error . "\n";
        $c->stash->{error} = $error;
        $c->stash->{template} = '/barcode/stock_download_result.mas';
        $c->detach;
    }
    my $trial_name = $trial_rs->first->name();
    my ($trial_layout, %errors, @error_messages);
    try {
        $trial_layout = CXGN::Trial::TrialLayout->new({schema => $schema, trial_id => $trial_id} );
    };
    if (!$trial_layout) {
        my $error = "Trial $trial_name does not have a valid field design. Can't create labels.";
        print STDERR $error . "\n";
        $c->stash->{error} = $error;
        $c->stash->{template} = '/barcode/stock_download_result.mas';
        $c->detach;
    }
    my %design = %{$trial_layout->get_design()};
    
    my $year_cvterm_id = $schema->resultset("Cv::Cvterm")->search({name=> 'project year' })->first->cvterm_id();
    my $year = $schema->resultset("Project::Projectprop")->search({ project_id => $trial_id, type_id => $year_cvterm_id } )->first->value();

    #loop through plot data, creating and saving zpl to file
    my $zpl_dir = $c->tempfiles_subdir('zpl');
    my ($ZPL, $zpl_filename) = $c->tempfile(TEMPLATE=>"zpl/zpl-XXXXX", UNLINK=>0);
    my $col_num = 0;
    my $row_num = 0;
    print $ZPL "^XA\n";
    foreach my $key (sort { $a <=> $b} keys %design) {
        print STDERR "Design key is $key\n";
        my %design_info = %{$design{$key}};
        
        my $plot_name = $design_info{'plot_name'};
        my $plot_number = $design_info{'plot_number'};
        my $rep_number = $design_info{'rep_number'};
        my $accession_name = $design_info{'accession_name'};
        
        if ($include_pedigree) {
            $custom_text = CXGN::Stock->new ( schema => $schema, stock_id => $design_info{'accession_id'} )->get_pedigree_string('Parents');
            print STDERR "Pedigree for $accession_name is $custom_text\n";
        }
        
        #Scale font size based on accession name
        my $font_size = 42;
        if (length($accession_name) > 18) {
            $font_size = 21;
        } elsif (length($accession_name) > 13) {
            $font_size = 28;
        } elsif (length($accession_name) > 10) {
            $font_size = 35;
        }
        #Scale QR code size based on plot name
        my $qr_size = 7;
        if (length($plot_name) > 30) {
            $qr_size = 5;
        } elsif (length($plot_name) > 15) {
            $qr_size = 6;
        }
        
        for (my $i=0; $i < $labels_per_stock; $i++) {
            print STDERR "Working on label num $i\n";     
            my $x = $starting_x + ($col_num * $x_increment);
            my $y = $starting_y + ($row_num * $y_increment);
            
            my $label_zpl = $zpl_template->fill_in(
                    hash => {
                        X => $x,
                        Y => $y,
                        ACCESSION_NAME => $accession_name,
                        PLOT_NAME => $plot_name,
                        PLOT_NUMBER => $plot_number,
                        REP_NUMBER => $rep_number,
                        CUSTOM_TEXT => $custom_text,
                        TRIAL_NAME => $trial_name,
                        YEAR => $year,  
                        FONT_SIZE => $font_size,
                        QR_SIZE => $qr_size,
                    },
                );
            print STDERR "ZPL is $label_zpl\n";
            print $ZPL $label_zpl;
            
            if ($col_num < $number_of_columns) { #next column
                $col_num++;
            } else { #new row, reset col num
                $col_num = 0;
                $row_num++;
            }
            
            if ($row_num > $number_of_rows) { #new oage, reset row and col num
                print $ZPL "\n^XZ\n^XA";
                $col_num = 0;
                $row_num = 0;
            }
        }
    }
    print $ZPL "\n^XZ"; # end file
    close($ZPL);
    
    my $pdf_dir = $c->tempfiles_subdir('pdfs');
    my ($PDF, $pdf_filename) = $c->tempfile(TEMPLATE=>"pdfs/pdf-XXXXX", SUFFIX=>".pdf", UNLINK=>0);
    my $zpl_path = $c->path_to($zpl_filename);
    my $pdf_path = $c->path_to($pdf_filename);
    print STDERR "PATHS ARE: $zpl_filename is at $zpl_path and $pdf_filename is at $pdf_path\n\n\n";
    
    `curl --request POST http://api.labelary.com/v1/printers/8dpmm/labels/8.5x11/ --form file=\@$zpl_path --header "Accept: application/pdf" > $pdf_path`;

    $c->stash->{rest} = { filename => $pdf_filename };

}

sub _parse_list_from_json {
  my $list_json = shift;
  my $json = new JSON;
  if ($list_json) {
    my $decoded_list = $json->allow_nonref->utf8->relaxed->escape_slash->loose->allow_singlequote->allow_barekey->decode($list_json);
    #my $decoded_list = decode_json($list_json);
    my @array_of_list_items = @{$decoded_list};
    return \@array_of_list_items;
  }
  else {
    return;
  }
}

#########
1;
#########
