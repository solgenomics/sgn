
package SGN::Controller::StockBarcode;

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
use Barcode::Code128;
use CXGN::QRcode;
use URI::Encode qw(uri_encode uri_decode);

BEGIN { extends "Catalyst::Controller"; }

use CXGN::ZPL;

sub barcode_preview :Path('/barcode/preview') {
    my $self = shift;
    my $c = shift;
    my $uri     = URI::Encode->new( { encode_reserved => 0 } );
    my $content =  $uri->decode($c->req->param("content"));
    my $format = $uri->decode($c->req->param("type"));
    my ($type, $size) = split '_', $format;
    print STDERR "Content is $content and type is $type and size is $size\n";
    
    if ($type eq '128') {
    
        print STDERR "Creating barcode 128\n";
    
        my $barcode_object = Barcode::Code128->new();
        $barcode_object->option("scale", $size);
        $barcode_object->option("font_align", "center");
        $barcode_object->option("padding", 5);
        $barcode_object->option("show_text", 0);
        $barcode_object->barcode($content);
        my $barcode = $barcode_object->gd_image();
        
        $c->res->headers->content_type('image/png');
        $c->res->body($barcode->png());

    } elsif ($type eq 'QR') {
        
        print STDERR "Creating QR Code\n";
    
        $c->tempfiles_subdir('barcode');
        my ($file_location, $uri) = $c->tempfile( TEMPLATE => [ 'barcode', 'bc-XXXXX'], SUFFIX=>'.jpg');

        my $barcode_generator = CXGN::QRcode->new();
        my $barcode_file = $barcode_generator->get_barcode_file(
              $file_location,
              $content,
              $size
         );
         
         my $qrcode_path = $c->path_to($uri);
         
         $c->res->headers->content_type('image/jpg');
         my $output = read_file($qrcode_path);
         $c->res->body($output);
        
    }

}

# sub download_zpl_barcodes : Path('/barcode/stock/download/zpl') {
#     my $self = shift;
#     my $c = shift;
#     my $schema = $c->dbic_schema('Bio::Chado::Schema');
#     
#     # Zebra design params, hard coded to 3x10 labels for now
#     my $starting_x = 20;
#     my $starting_y = 60;
#     my $x_increment = 590;
#     my $y_increment = 213;
#     my $number_of_columns = 2; #zero index
#     my $number_of_rows = 9; #zero index
#     
#     # hard coded for now, but could be generated from a user interface like a drag and drop grid
#      my $zpl = $c->req->param("zpl_template"); #|| '^LH{ $X },{ $Y }
# # ^FO5,10^AA,{ $FONT_SIZE }^FB320,5^FD{ $ACCESSION_NAME }^FS
# # ^FO20,70^AA,28^FDPlot { $PLOT_NUMBER }, Rep { $REP_NUMBER }^AF4^FS
# # ^FO22,70^AA,28^FD     { $PLOT_NUMBER }      { $REP_NUMBER }^AF4^FS
# # ^FO20,72^AA,28^FD     { $PLOT_NUMBER }      { $REP_NUMBER }^AF4^FS
# # ^FO20,105^AA,22^FD{ $TRIAL_NAME } { $YEAR }^FS
# # ^FO10,140^AA,28^FB300,5^FD{ $CUSTOM_TEXT }^FS
# # ^FO325,5^BQ,,{ $QR_SIZE }^FD   { $PLOT_NAME }^FS
# # ';
#     my $zpl_template = Text::Template->new(
#         type => 'STRING',
#         source => $zpl,
#     );
#     
#     # retrieve variable params
#     my $trial_id = $c->req->param("trial_id");
#     my $labels_per_stock = $c->req->param("num_labels");# || 1;
#     my $custom_text = $c->req->param("custom_text") || '';
#     my $include_pedigree = $c->req->param("include_pedigree");
#     print STDERR "trial id is $trial_id\n num labels is $labels_per_stock\n zpl is $zpl\n";
#     #my $order_by = $c->req->param("custom_text") || 'plot_number';
#     
#     my $trial_rs = $schema->resultset("Project::Project")->search({ project_id => $trial_id });
#     if (!$trial_rs) {
#         my $error = "Trial with id $trial_id does not exist. Can't create labels.";
#         print STDERR $error . "\n";
#         $c->stash->{error} = $error;
#         $c->stash->{template} = '/barcode/stock_download_result.mas';
#         $c->detach;
#     }
#     my $trial_name = $trial_rs->first->name();
#     my ($trial_layout, %errors, @error_messages);
#     try {
#         $trial_layout = CXGN::Trial::TrialLayout->new({schema => $schema, trial_id => $trial_id} );
#     };
#     if (!$trial_layout) {
#         my $error = "Trial $trial_name does not have a valid field design. Can't create labels.";
#         print STDERR $error . "\n";
#         $c->stash->{error} = $error;
#         $c->stash->{template} = '/barcode/stock_download_result.mas';
#         $c->detach;
#     }
#     my %design = %{$trial_layout->get_design()};
#     
#     my $year_cvterm_id = $schema->resultset("Cv::Cvterm")->search({name=> 'project year' })->first->cvterm_id();
#     my $year = $schema->resultset("Project::Projectprop")->search({ project_id => $trial_id, type_id => $year_cvterm_id } )->first->value();
# 
#     #loop through plot data, creating and saving zpl to file
#     my $zpl_dir = $c->tempfiles_subdir('zpl');
#     my ($ZPL, $zpl_filename) = $c->tempfile(TEMPLATE=>"zpl/zpl-XXXXX", UNLINK=>0);
#     my $col_num = 0;
#     my $row_num = 0;
#     print $ZPL "^XA\n";
#     foreach my $key (sort { $a <=> $b} keys %design) {
#         print STDERR "Design key is $key\n";
#         my %design_info = %{$design{$key}};
#         
#         my $plot_name = $design_info{'plot_name'};
#         my $plot_number = $design_info{'plot_number'};
#         my $rep_number = $design_info{'rep_number'};
#         my $accession_name = $design_info{'accession_name'};
#         
#         if ($include_pedigree) {
#             $custom_text = CXGN::Stock->new ( schema => $schema, stock_id => $design_info{'accession_id'} )->get_pedigree_string('Parents');
#             print STDERR "Pedigree for $accession_name is $custom_text\n";
#         }
#         
#         #Scale font size based on accession name
#         my $font_size = 42;
#         if (length($accession_name) > 18) {
#             $font_size = 21;
#         } elsif (length($accession_name) > 13) {
#             $font_size = 28;
#         } elsif (length($accession_name) > 10) {
#             $font_size = 35;
#         }
#         #Scale QR code size based on plot name
#         my $qr_size = 7;
#         if (length($plot_name) > 30) {
#             $qr_size = 5;
#         } elsif (length($plot_name) > 15) {
#             $qr_size = 6;
#         }
#         
#         for (my $i=0; $i < $labels_per_stock; $i++) {
#             print STDERR "Working on label num $i\n";     
#             my $x = $starting_x + ($col_num * $x_increment);
#             my $y = $starting_y + ($row_num * $y_increment);
#             
#             my $label_zpl = $zpl_template->fill_in(
#                     hash => {
#                         X => $x,
#                         Y => $y,
#                         ACCESSION_NAME => $accession_name,
#                         PLOT_NAME => $plot_name,
#                         PLOT_NUMBER => $plot_number,
#                         REP_NUMBER => $rep_number,
#                         CUSTOM_TEXT => $custom_text,
#                         TRIAL_NAME => $trial_name,
#                         YEAR => $year,  
#                         FONT_SIZE => $font_size,
#                         QR_SIZE => $qr_size,
#                     },
#                 );
#             print STDERR "ZPL is $label_zpl\n";
#             print $ZPL $label_zpl;
#             
#             if ($col_num < $number_of_columns) { #next column
#                 $col_num++;
#             } else { #new row, reset col num
#                 $col_num = 0;
#                 $row_num++;
#             }
#             
#             if ($row_num > $number_of_rows) { #new oage, reset row and col num
#                 print $ZPL "\n^XZ\n^XA";
#                 $col_num = 0;
#                 $row_num = 0;
#             }
#         }
#     }
#     print $ZPL "\n^XZ"; # end file
#     close($ZPL);
#     
#     my $pdf_dir = $c->tempfiles_subdir('pdfs');
#     my ($PDF, $pdf_filename) = $c->tempfile(TEMPLATE=>"pdfs/pdf-XXXXX", SUFFIX=>".pdf", UNLINK=>0);
#     my $zpl_path = $c->path_to($zpl_filename);
#     my $pdf_path = $c->path_to($pdf_filename);
#     print STDERR "PATHS ARE: $zpl_filename is at $zpl_path and $pdf_filename is at $pdf_path\n\n\n";
#     
#     `curl --request POST http://api.labelary.com/v1/printers/8dpmm/labels/8.5x11/ --form file=\@$zpl_path --header "Accept: application/pdf" > $pdf_path`;
# 
#     #  $c->stash->{file} = $pdf_filename;
#     #  $c->stash->{filetype} = "PDF";
#     #  $c->stash->{template} = '/barcode/trial_barcodes_download_result.mas';
#      # from geno download
#      $c->res->content_type("application/text");
#      $c->res->header('Content-Disposition', qq[attachment; filename="$pdf_filename"]);
#      my $output = read_file($pdf_path);
#      $c->res->body($output);
# 
# }


sub download_pdf_labels :Path('/barcode/stock/download/pdf') :Args(0) {
    my ($self, $c) = @_;

    my $stock_names = $c->req->param("stock_names");
    my $stock_names_file = $c->req->upload("stock_names_file");
    my $labels_per_page = $c->req->param("label_rows") || 10;
    my $labels_per_row  = $c->req->param("label_cols") || 1;
    my $page_format = $c->req->param("page_format") || "letter";
    my $top_margin_mm = $c->req->param("top_margin");
    my $left_margin_mm = $c->req->param("left_margin");
    my $bottom_margin_mm = $c->req->param("bottom_margin");
    my $right_margin_mm = $c->req->param("right_margin");
    ##my $plot = $c->req->param("plots");
    my $nursery = $c->req->param("nursery");
    my $added_text = $c->req->param("text_margin");
    my $barcode_type = $c->req->param("select_barcode_type");
    my $fieldbook_barcode = $c->req->param("enable_fieldbook_2d_barcode");
    my $cass_print_format = $c->req->param("select_print_format");
    my $label_text_4;
    my $type_id;
    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    my $plot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type' )->cvterm_id();
    my $plot_number_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot number', 'stock_property' )->cvterm_id();
    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type' )->cvterm_id();
    my $plant_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant', 'stock_type' )->cvterm_id();
    my $xlabel_margin = 8;
    # convert mm into pixels
    #
    if ($cass_print_format eq 'NCSU') {$left_margin_mm = 10, $top_margin_mm = 12, $bottom_margin_mm =  12, $right_margin_mm = 10, $labels_per_page = 10, $labels_per_row = 3, $barcode_type = "2D", $page_format = "letter"; }
    if ($cass_print_format eq 'CASS') {$left_margin_mm = 112, $top_margin_mm = 10, $bottom_margin_mm =  13, $right_margin_mm = 10; }
    if ($cass_print_format eq 'IITA-3') {$left_margin_mm = 130, $top_margin_mm = 12, $bottom_margin_mm =  12, $right_margin_mm = 10, $labels_per_row = 3, $barcode_type = "2D"; }
    if ($cass_print_format eq 'MUSA') {$left_margin_mm = 112, $top_margin_mm = 10, $bottom_margin_mm =  13; }
    if ($cass_print_format eq '32A4') {$left_margin_mm = 17, $top_margin_mm = 12, $bottom_margin_mm =  12, $right_margin_mm = 10, $labels_per_page = 8, $labels_per_row = 4, $barcode_type = "2D", $page_format = "letter"; }
    if ($cass_print_format eq '20A4') {$left_margin_mm = 10, $top_margin_mm = 12, $bottom_margin_mm =  12, $right_margin_mm = 10, $labels_per_page = 10, $labels_per_row = 2, $barcode_type = "2D", $page_format = "letter"; }
    my ($top_margin, $left_margin, $bottom_margin, $right_margin) = map { $_ * 2.846 } (
            $top_margin_mm,
    		$left_margin_mm,
    		$bottom_margin_mm,
    		$right_margin_mm
        );

    # read file if upload
    #
    if ($stock_names_file) {
	     my $stock_file_contents = read_file($stock_names_file->{tempname});
	     $stock_names = $stock_names ."\n".$stock_file_contents;
    } 
    
    $stock_names =~ s/\r//g;
    my @names = split /\n/, $stock_names;

    my @not_found;
    my @found;

    my ($row, $stockprop_name, $value, $fdata_block, $fdata_rep, $fdata_plot, $fdata, $accession_id, $accession_name, $parents, $tract_type_id, $label_text_5, $plot_name, $label_text_6, $musa_row_col_number, $label_text_7, $row_col_number, $label_text_8, $fdata_plot_20A4, $fdata_rep_block);

    ## sort plot list
    my @stocks_sorted;
    my $stock_rs = $schema->resultset("Stock::Stock")->search(
        {
            uniquename => {'-in' => \@names},
            'stockprops.type_id' => $plot_number_cvterm_id
        },
        {
            join => {'stockprops'},
            '+select' => ['stockprops.value'],
            '+as' => ['plot_number'],
            'order_by' => { '-asc' => 'stockprops.value::INT' }
        }
    );
    while ( my $r = $stock_rs->next()){
        my $stock_name = $r->uniquename;
        my $stock_id = $r->stock_id;
        my $stock_type_id = $r->type_id;
        my $plot_number = $r->get_column('plot_number');
        push @stocks_sorted, $stock_name
    }

    if (scalar(@stocks_sorted) > 0){
        @names = @stocks_sorted;
    }
    
    foreach my $name (@names) {

    	# skip empty lines
    	#
    	if (!$name) {
    	    next;
    	}

    	my $stock = $schema->resultset("Stock::Stock")->find( { uniquename=>$name });

    	if (!$stock) {
    	    push @not_found, $name;
    	    next;
    	}

    	my $stock_id = $stock->stock_id();
        $type_id = $stock->type_id();

        if ($plant_cvterm_id == $type_id){
            my $dbh = $c->dbc->dbh();
            my $h = $dbh->prepare("select stock_relationship.subject_id, stock.name from stock join stock_relationship on stock.stock_id=stock_relationship.subject_id where object_id=?;");

            $h->execute($stock_id);
            while (my($plot_of_plant_id, $plant_plot_name) = $h->fetchrow_array) {
                $plot_name = $plant_plot_name;

                my $dbh = $c->dbc->dbh();
                my $h = $dbh->prepare("select name, value from cvterm inner join stockprop on cvterm.cvterm_id = stockprop.type_id where stockprop.stock_id=?;");

                $h->execute($plot_of_plant_id);

                my %stockprop_hash;
                 while (($stockprop_name, $value) = $h->fetchrow_array) {
                   $stockprop_hash{$stock_id}->{$stockprop_name} = $value;

                }
                $row = $stockprop_hash{$stock_id}->{'replicate'};
                $fdata = "rep:".$stockprop_hash{$stock_id}->{'replicate'}.' '."blk:".$stockprop_hash{$stock_id}->{'block'}.' '."plot:".$stockprop_hash{$stock_id}->{'plot number'};
                $fdata_block = "blk:".$stockprop_hash{$stock_id}->{'block'};
                $fdata_rep = "rep:".$stockprop_hash{$stock_id}->{'replicate'};
                $fdata_rep_block = "block number:".$stockprop_hash{$stock_id}->{'block'}.', '."rep number:".$stockprop_hash{$stock_id}->{'replicate'}; 
                $fdata_plot = "plot:".$stockprop_hash{$stock_id}->{'plot number'};
                $fdata_plot_20A4 = "plot number:".$stockprop_hash{$stock_id}->{'plot number'};
                $musa_row_col_number = "row number:".$stockprop_hash{$stock_id}->{'row_number'}.', '."column number:".$stockprop_hash{$stock_id}->{'col_number'};
                
                my $h_acc = $dbh->prepare("select stock.uniquename, stock.stock_id FROM stock join stock_relationship on (stock.stock_id = stock_relationship.object_id) where stock_relationship.subject_id =?;");

                $h_acc->execute($stock_id);
                ($accession_name, $accession_id) = $h_acc->fetchrow_array;
            }
        }

      if ($plot_cvterm_id == $type_id){
          my $dbh = $c->dbc->dbh();
          my $h = $dbh->prepare("select name, value from cvterm inner join stockprop on cvterm.cvterm_id = stockprop.type_id where stockprop.stock_id=?;");

          $h->execute($stock_id);

          my %stockprop_hash;
           while (($stockprop_name, $value) = $h->fetchrow_array) {
             $stockprop_hash{$stock_id}->{$stockprop_name} = $value;

          }
          $row = $stockprop_hash{$stock_id}->{'replicate'};
          $fdata = "rep:".$stockprop_hash{$stock_id}->{'replicate'}.' '."blk:".$stockprop_hash{$stock_id}->{'block'}.' '."plot:".$stockprop_hash{$stock_id}->{'plot number'};
          $fdata_block = "blk:".$stockprop_hash{$stock_id}->{'block'};
          $fdata_rep = "rep:".$stockprop_hash{$stock_id}->{'replicate'};
          $fdata_plot = "plot:".$stockprop_hash{$stock_id}->{'plot number'};
          $fdata_rep_block = "block number:".$stockprop_hash{$stock_id}->{'block'}.', '."rep number:".$stockprop_hash{$stock_id}->{'replicate'};
          $fdata_plot_20A4 = "plot number:".$stockprop_hash{$stock_id}->{'plot number'};
          $musa_row_col_number = "row number:".$stockprop_hash{$stock_id}->{'row_number'}.', '."column number:".$stockprop_hash{$stock_id}->{'col_number'};
          $row_col_number = "rw/cl:".$stockprop_hash{$stock_id}->{'row_number'}."/".$stockprop_hash{$stock_id}->{'col_number'};
          my $h_acc = $dbh->prepare("select stock.uniquename, stock.stock_id FROM stock join stock_relationship on (stock.stock_id = stock_relationship.object_id) where stock_relationship.subject_id =? and stock.type_id=?;");

          $h_acc->execute($stock_id,$accession_cvterm_id);
          ($accession_name, $accession_id) = $h_acc->fetchrow_array;
          print STDERR "Accession name for this plot is $accession_name and id is $accession_id\n";
      }
      my $synonym_string;
      if ($plot_cvterm_id == $type_id) {
          $tract_type_id = 'plot';
          $parents = CXGN::Stock->new ( schema => $schema, stock_id => $accession_id )->get_pedigree_string('Parents');
      }
      elsif ($accession_cvterm_id == $type_id){
          $tract_type_id = 'accession';
          $parents = CXGN::Stock->new ( schema => $schema, stock_id => $stock_id )->get_pedigree_string('Parents');
          my $stock_synonyms = CXGN::Stock::Accession->new({ schema => $schema, stock_id => $stock_id })->synonyms();
          $synonym_string = join ',', @$stock_synonyms;
      }
      elsif ($plant_cvterm_id == $type_id) {
          $tract_type_id = 'plant';
          $parents = CXGN::Stock->new ( schema => $schema, stock_id => $accession_id )->get_pedigree_string('Parents');
      }

      push @found, [ $c->config->{identifier_prefix}.$stock_id, $name, $accession_name, $fdata, $parents, $tract_type_id, $plot_name, $synonym_string, $musa_row_col_number, $fdata_block, $fdata_rep, $fdata_plot, $row_col_number, $fdata_plot_20A4, $fdata_rep_block];
    }

    my $dir = $c->tempfiles_subdir('pdfs');
    my ($FH, $filename) = $c->tempfile(TEMPLATE=>"pdfs/pdf-XXXXX", SUFFIX=>".pdf", UNLINK=>0);
    print STDERR "FILENAME: $filename \n\n\n";
    my $pdf = PDF::Create->new(filename=>$c->path_to($filename),
			       Author=>$c->config->{project_name},
			       Title=>'Labels',
			       CreationDate => [ localtime ],
			       Version=>1.2,
	            );

    if (!$page_format) { $page_format = "Letter"; }
    if (!$labels_per_page) { $labels_per_page = 8; }
    if ($cass_print_format eq 'CASS') {$barcode_type = "2D", $labels_per_row = 2; }
    if ($cass_print_format eq 'MUSA') {$barcode_type = "2D", $labels_per_row = 2; }

    my $base_page = $pdf->new_page(MediaBox=>$pdf->get_page_size($page_format));

    my ($page_width, $page_height) = @{$pdf->get_page_size($page_format)}[2,3];
    
    ## for 10 labels per page
    my $label_height;
    if ($cass_print_format eq '32A4'){
        $label_height = 40;
        print "LABEL HEIGHT: $label_height\n";
    }
    else {
        if ($labels_per_page == '10'){
            $label_height = int( (($page_height - $top_margin - $bottom_margin) / $labels_per_page) + 0.5 );
        }
        ## for 20 labels per page
        elsif ($labels_per_page == '20'){
            $label_height = int( (($page_height - $top_margin - $bottom_margin) / $labels_per_page) - 0.05 );
        }
        else {
            ## for 20 labels per page
            $label_height = int( ($page_height - $top_margin - $bottom_margin) / $labels_per_page);
        }
    }
    
    my @pages;
    foreach my $page (1..$self->label_to_page($labels_per_page, scalar(@found))) {
	     print STDERR "Generating page $page...\n";
	     push @pages, $base_page->new_page();
    }

    for (my $i=0; $i<@found; $i++) {
    	my $label_count = $i + 1;
    	my $page_nr = $self->label_to_page($labels_per_page, $label_count);
    	my $label_on_page = ($label_count -1) % $labels_per_page;

    	# generate barcode
    	#
      #####
      my $tempfile;
      my $plot_text = "accession: ".$found[$i]->[2]." ".$found[$i]->[3];
      if ($barcode_type eq "1D"){
         if ($found[$i]->[5] eq 'plot'){
            #$tempfile = $c->forward('/barcode/barcode_tempfile_jpg', [ $found[$i]->[0], $found[$i]->[2]." ".$found[$i]->[3],  'large',  20  ]);
            $tempfile = $c->forward('/barcode/barcode_tempfile_jpg', [ $found[$i]->[1], $plot_text,  'large',  20 ]);
         }
         elsif ($found[$i]->[5] eq 'accession'){
             $tempfile = $c->forward('/barcode/barcode_tempfile_jpg', [ $found[$i]->[1], $found[$i]->[4],  'large',  20  ]);
         }
         elsif ($found[$i]->[5] eq 'plant'){
            $tempfile = $c->forward('/barcode/barcode_tempfile_jpg', [ $found[$i]->[1], $plot_text,  'large',  20 ]);
         }
         else {
      	  $tempfile = $c->forward('/barcode/barcode_tempfile_jpg', [  $found[$i]->[0], $found[$i]->[1], 'large',  20  ]);
         }
      }
      elsif ($barcode_type eq "2D") {

        if ($found[$i]->[5] eq 'plot'){
          $parents = $found[$i]->[4];
           $tempfile = $c->forward('/barcode/barcode_qrcode_jpg', [ $found[$i]->[0], $found[$i]->[1], $found[$i]->[2]."\n".$found[$i]->[3]."\n".$found[$i]->[4]."\n".$found[$i]->[8]."\n".$added_text, $fieldbook_barcode ]);
        }
        elsif ($found[$i]->[5] eq 'accession'){
            if ($found[$i]->[7] eq ''){
                $found[$i]->[7] = "No synonym(s) available";
            }else{
                $found[$i]->[7] = "synonym(s): ".$found[$i]->[7];
            }
            $parents = $found[$i]->[4];
            $tempfile = $c->forward('/barcode/barcode_qrcode_jpg', [ $found[$i]->[0], $found[$i]->[1], $found[$i]->[4]."\n".$added_text."\n".$found[$i]->[7], $fieldbook_barcode]);
        }
        elsif ($found[$i]->[5] eq 'plant'){
            $parents = $found[$i]->[4];
            $tempfile = $c->forward('/barcode/barcode_qrcode_jpg', [ $found[$i]->[0], $found[$i]->[1], $found[$i]->[2]."\nplot:".$found[$i]->[6]."\n".$found[$i]->[3]."\n".$found[$i]->[4]."\n".$found[$i]->[8]."\n".$added_text, $fieldbook_barcode ]);
        }
        else {
         $tempfile = $c->forward('/barcode/barcode_qrcode_jpg', [  $found[$i]->[0], $found[$i]->[1], $added_text, $fieldbook_barcode ]);
        }

      }

      print STDERR "$tempfile\n";
      my $image = $pdf->image($tempfile);
      #print STDERR "IMAGE: ".Data::Dumper::Dumper($image);

    	# note: pdf coord system zero is lower left corner
    	#
        print "PAGE WIDTH: $page_width\n";
        my $final_barcode_width = ($page_width - $right_margin - $left_margin) / $labels_per_row;
        my $scalex = $final_barcode_width / $image->{width};
        my $scaley = $label_height / $image->{height};
        
        if ($scalex < $scaley) { $scaley = $scalex; }
    	else { $scalex = $scaley; }
        
        my ($year_text, $location_text, $ypos, $label_boundary);
        if ($cass_print_format eq 'NCSU'){
            ($year_text,$location_text) = split ',', $added_text;
            my $xlabel_margin = 18;
            $label_boundary = $page_height - ($label_on_page * $label_height) - $top_margin;
            $ypos = $label_boundary - int( ($label_height - $image->{height} * $scaley) /2);
            $final_barcode_width = ($page_width - $right_margin - $left_margin + (2 * $xlabel_margin)) / $labels_per_row;
        }
        elsif ($cass_print_format eq '32A4'){
            my $label_height_8_per_page = 90;
     	    $label_boundary = $page_height - ($label_on_page * $label_height_8_per_page) - $top_margin;
            $ypos = $label_boundary - int( ($label_height_8_per_page - $image->{height} * $scaley) /2);
            $final_barcode_width = ($page_width - $right_margin - $left_margin + (3 * $xlabel_margin)) / $labels_per_row;
        }
        elsif ($cass_print_format eq '20A4'){
     	    $label_boundary = $page_height - ($label_on_page * $label_height) - $top_margin;
            $ypos = $label_boundary - int( ($label_height - $image->{height} * $scaley) /2);
            $final_barcode_width = ($page_width - $right_margin - $left_margin + (4 * $xlabel_margin)) / $labels_per_row;
        }
        elsif ($cass_print_format eq 'IITA-3'){
     	    $label_boundary = $page_height - ($label_on_page * $label_height) - $top_margin;
            $ypos = $label_boundary - int( ($label_height - $image->{height} * $scaley) /2);
            $final_barcode_width = ($page_width - $right_margin - $left_margin) / ($labels_per_row + 1);
        }
        else{
            $label_boundary = $page_height - ($label_on_page * $label_height) - $top_margin;
        	$ypos = $label_boundary - int( ($label_height - $image->{height} * $scaley) /2);
        }

        if ($cass_print_format eq '32A4' || $cass_print_format eq 'NCSU' || $cass_print_format eq '20A4'){
        }
        else{
            $pages[$page_nr-1]->line($page_width -100, $label_boundary, $page_width, $label_boundary);
        }
        

      # my $lebel_number = scalar($#{$found[$i]});
      my $font = $pdf->font('BaseFont' => 'Courier-Bold');
      if ($barcode_type eq "2D" && !$cass_print_format) {
        foreach my $label_count (1..$labels_per_row) {
          my $xposition = $left_margin + ($label_count -1) * $final_barcode_width + 20;
          my $yposition = $ypos -7;
          my $label_text = $found[$i]->[1];
          my $label_size =  7;
          $pages[$page_nr-1]->image(image=>$image, xpos=>$left_margin + ($label_count -1) * $final_barcode_width, ypos=>$ypos, xalign=>0, yalign=>2, xscale=>$scalex, yscale=>$scaley);

          if ($labels_per_row == '1' ){
              my $label_count_15_xter_plot_name =  1-1;
              my $xposition = $left_margin + ($label_count_15_xter_plot_name) * $final_barcode_width + 80.63;
              my ($yposition_2, $yposition_3, $yposition_4, $yposition_5);
              if ($labels_per_page > 15){
                   $yposition_2 = $ypos - 10;
                   $yposition_3 = $ypos - 20;
                   $yposition_4 = $ypos - 30;
                   $yposition_5 = $ypos - 40;
              }else{
                   $yposition_2 = $ypos - 20;
                   $yposition_3 = $ypos - 30;
                   $yposition_4 = $ypos - 40;
                   $yposition_5 = $ypos - 50;
              }
              my $plot_pedigree_text;

              $pages[$page_nr-1]->string($font, $label_size, $xposition, $yposition_2, $label_text);
                  if ($found[$i]->[5] eq 'plot'){
                      $label_text_5 = "accession:".$found[$i]->[2]." ".$found[$i]->[3];
                      if ($parents eq ''){
                          $label_text_4 = "No pedigree for ".$found[$i]->[2];
                      }else{
                          $label_text_4 = "pedigree: ".$parents;
                      }
                  }
                  elsif ($found[$i]->[5] eq 'accession'){
                      if ($parents eq ''){
                          $label_text_4 = "No pedigree for ".$found[$i]->[1];
                      }else{
                          $label_text_4 = "pedigree: ".$parents;
                      }
                    $label_text_5 = $found[$i]->[7];
                  }
                  elsif ($found[$i]->[5] eq 'plant'){
                      $label_text_6 = "plot:".$found[$i]->[6];
                      $label_text_5 = "accession:".$found[$i]->[2]." ".$found[$i]->[3];
                      if ($parents eq ''){
                          $label_text_4 = "No pedigree for ".$found[$i]->[2];
                      }else{
                          $label_text_4 = "pedigree: ".$parents;
                      }
                  }
                  else{
                      $label_text_4 = '';
                  }

              $pages[$page_nr-1]->string($font, $label_size, $xposition, $yposition_3, $label_text_4);
              $pages[$page_nr-1]->string($font, $label_size, $xposition, $yposition_5, $label_text_6);
              $pages[$page_nr-1]->string($font, $label_size, $xposition, $yposition_4, $label_text_5);
          }
          elsif ($labels_per_row > '1'){
              if (length($label_text) <= 15){
                  $pages[$page_nr-1]->string($font, $label_size, $xposition, $yposition, $label_text);
              }
          }
        }

        if ($labels_per_row > '1'){
            my $label_text = $found[$i]->[1];
            if (length($label_text) > 15) {
              my $label_count_15_xter_plot_name =  1-1;
              my $xposition = $left_margin + ($label_count_15_xter_plot_name) * $final_barcode_width + 20;
              my $yposition = $ypos -7;
              my $label_size =  7;
              $pages[$page_nr-1]->string($font, $label_size, $xposition, $yposition, $label_text);
            }
        }
    }

     elsif ($cass_print_format eq 'CASS' && $barcode_type eq "2D") {

         foreach my $label_count (1..$labels_per_row) {
          my $label_text = $found[$i]->[1];
          my $label_size =  7;
          my $xpos = ($left_margin + ($label_count -1) * $final_barcode_width) + 85;
          my $label_count_15_xter_plot_name =  1-1;
          my $xposition = $left_margin + ($label_count_15_xter_plot_name) * $final_barcode_width - 95.63;
          my ($yposition_2, $yposition_3, $yposition_4, $yposition_5);
          if ($labels_per_page > 15){
               $yposition_2 = $ypos - 10;
               $yposition_3 = $ypos - 20;
               $yposition_4 = $ypos - 30;
               $yposition_5 = $ypos - 40;
          }else{
               $yposition_2 = $ypos - 20;
               $yposition_3 = $ypos - 30;
               $yposition_4 = $ypos - 40;
               $yposition_5 = $ypos - 50;
          }
          my $plot_pedigree_text;

          $pages[$page_nr-1]->string($font, $label_size, $xposition, $yposition_2, $label_text);
              if ($found[$i]->[5] eq 'plot'){
                  $label_text_5 = "stock:".$found[$i]->[2]." ".$found[$i]->[3];
                  if ($parents eq ''){
                      $label_text_4 = "No pedigree for ".$found[$i]->[2];
                  }else{
                      $label_text_4 = "pedigree: ".$parents;
                  }
              }
              elsif ($found[$i]->[5] eq 'accession'){
                  if ($parents eq ''){
                      $label_text_4 = "No pedigree for ".$found[$i]->[1];
                  }else{
                      $label_text_4 = "pedigree: ".$parents;
                  }
                  $label_text_5 = $found[$i]->[7];
              }
              elsif ($found[$i]->[5] eq 'plant'){
                  $label_text_6 = "plot:".$found[$i]->[6];
                  $label_text_5 = "accession:".$found[$i]->[2]." ".$found[$i]->[3];
                  if ($parents eq ''){
                      $label_text_4 = "No pedigree for ".$found[$i]->[2];
                  }else{
                      $label_text_4 = "pedigree: ".$parents;
                  }
              }
              else{
                  $label_text_4 = '';
              }
          $pages[$page_nr-1]->string($font, $label_size, $xposition, $yposition_3, $label_text_4);
          $pages[$page_nr-1]->string($font, $label_size, $xposition, $yposition_4, $label_text_5);
          $pages[$page_nr-1]->string($font, $label_size, $xposition, $yposition_5, $label_text_6);
          $pages[$page_nr-1]->image(image=>$image, xpos=>$xpos, ypos=>$ypos, xalign=>0, yalign=>2, xscale=>$scalex, yscale=>$scaley);
       }
     }
     
     elsif ($cass_print_format eq 'IITA-3' && $barcode_type eq "2D") {

         foreach my $label_count (1..$labels_per_row) {
          my $label_text = $found[$i]->[1];
          my $label_size =  7;
          my $xpos = ($left_margin + ($label_count -1) * $final_barcode_width) + 80;
          my $label_count_15_xter_plot_name =  1-1;
          my $xposition = $left_margin + ($label_count_15_xter_plot_name) * $final_barcode_width - 95.63;
          my ($yposition_2, $yposition_3, $yposition_4, $yposition_5);
          if ($labels_per_page > 15){
               $yposition_2 = $ypos - 10;
               $yposition_3 = $ypos - 20;
               $yposition_4 = $ypos - 30;
               $yposition_5 = $ypos - 40;
          }else{
               $yposition_2 = $ypos - 20;
               $yposition_3 = $ypos - 30;
               $yposition_4 = $ypos - 40;
               $yposition_5 = $ypos - 50;
          }
          my $plot_pedigree_text;

          $pages[$page_nr-1]->string($font, $label_size, $xposition, $yposition_2, $label_text);
              if ($found[$i]->[5] eq 'plot'){
                  $label_text_5 = "stock:".$found[$i]->[2]." ".$found[$i]->[3];
                  if ($parents eq ''){
                      $label_text_4 = "No pedigree for ".$found[$i]->[2];
                  }else{
                      $label_text_4 = $parents;
                  }
              }
              elsif ($found[$i]->[5] eq 'accession'){
                  if ($parents eq ''){
                      $label_text_4 = "No pedigree for ".$found[$i]->[1];
                  }else{
                      $label_text_4 = $parents;
                  }
                  $label_text_5 = $found[$i]->[7];
              }
              elsif ($found[$i]->[5] eq 'plant'){
                  $label_text_6 = "plot:".$found[$i]->[6];
                  $label_text_5 = "accession:".$found[$i]->[2]." ".$found[$i]->[3];
                  if ($parents eq ''){
                      $label_text_4 = "No pedigree for ".$found[$i]->[2];
                  }else{
                      $label_text_4 = $parents;
                  }
              }
              else{
                  $label_text_4 = '';
              }
          $pages[$page_nr-1]->string($font, $label_size, $xposition, $yposition_3, $label_text_4);
          $pages[$page_nr-1]->string($font, $label_size, $xposition, $yposition_4, $label_text_5);
          $pages[$page_nr-1]->string($font, $label_size, $xposition, $yposition_5, $label_text_6);
          $pages[$page_nr-1]->image(image=>$image, xpos=>$xpos, ypos=>$ypos, xalign=>0, yalign=>2, xscale=>$scalex, yscale=>$scaley);
       }
     }
     
     elsif ($cass_print_format eq 'NCSU' && $barcode_type eq "2D") { 
         foreach my $label_count (1..$labels_per_row) {
           my $xposition = $left_margin + ($label_count -1) * $final_barcode_width;
           my $yposition = $ypos -7;
           my $label_text = $found[$i]->[1];
           my $label_size =  7;
           my $label_size_stock =  12;
           my $yposition_8 = $ypos + 2;
           my $yposition_2 = $ypos - 10;
           my $yposition_3 = $ypos - 20;
           my $yposition_4 = $ypos - 30;
           my $yposition_5 = $ypos - 40;
           my $yposition_6 = $ypos - 50;
           my $yposition_7 = $ypos - 60;
           if ($found[$i]->[5] eq 'accession'){
               $label_text_6 = $found[$i]->[1];
               $pages[$page_nr-1]->string($font, $label_size, $xposition, $yposition_3, $parents);
               $pages[$page_nr-1]->string($font, $label_size, $xposition, $yposition_4, $year_text);
               $pages[$page_nr-1]->string($font, $label_size, $xposition, $yposition_5, $location_text);
           }else{
               $label_text_6 = $found[$i]->[2];
               $label_text_5 = $found[$i]->[11];
               $label_text_4 = $found[$i]->[10];
               $pages[$page_nr-1]->string($font, $label_size, $xposition, $yposition_5, $year_text);
               $pages[$page_nr-1]->string($font, $label_size, $xposition, $yposition_4, $label_text_4);
               $pages[$page_nr-1]->string($font, $label_size, $xposition, $yposition_3, $label_text_5);
               $pages[$page_nr-1]->string($font, $label_size, $xposition, $yposition_6, $location_text);
               $pages[$page_nr-1]->string($font, $label_size, $xposition, $yposition_7, $parents);
           }
           $pages[$page_nr-1]->string($font, $label_size_stock, $xposition, $yposition_2, $label_text_6);
           $pages[$page_nr-1]->image(image=>$image, xpos=>$left_margin + 90 + ($label_count -1) * $final_barcode_width, ypos=>$ypos, xalign=>0, yalign=>2, xscale=>$scalex, yscale=>$scaley);
         }
     }
     
     elsif ($cass_print_format eq '32A4' && $barcode_type eq "2D") {
         foreach my $label_count (1..$labels_per_row) {
           my $xposition = $left_margin + ($label_count -1) * $final_barcode_width;
           my $yposition = $ypos -7;
           my $label_text = $found[$i]->[1];
           if ($found[$i]->[5] eq 'plot'){
               $label_text = $found[$i]->[2];
           }
           my $label_size =  7;
           my $label_size_stock =  10;
           my $yposition_8 = $ypos + 2;
           my $yposition_2 = $ypos - 10;
           my $yposition_3 = $ypos - 20;
           my $yposition_4 = $ypos - 30;
           my $yposition_5 = $ypos - 40;
           my $yposition_6 = $ypos - 50;
           my $yposition_7 = $ypos - 60;
           $label_text_6 = $found[$i]->[2];
           $label_text_5 = $found[$i]->[11];
           $label_text_4 = $found[$i]->[12];
           $label_text_8 = $found[$i]->[10];
           $pages[$page_nr-1]->string($font, $label_size_stock, $xposition, $yposition_8, $label_text);
           $pages[$page_nr-1]->string($font, $label_size, $xposition, $yposition_4, $label_text_8);
           $pages[$page_nr-1]->string($font, $label_size, $xposition, $yposition_3, $label_text_4);
           $pages[$page_nr-1]->string($font, $label_size, $xposition, $yposition_2, $label_text_5);
           if ($found[$i]->[5] eq 'accession'){
               $pages[$page_nr-1]->string($font, $label_size, $xposition, $yposition_6, $parents);
           }else{
                $pages[$page_nr-1]->string($font, $label_size, $xposition, $yposition_6, $parents);
                #$pages[$page_nr-1]->string($font, $label_size, $xposition, $yposition_7, $parents);
                $pages[$page_nr-1]->string($font, $label_size, $xposition, $yposition_5, $added_text);
           }
           
           if ($found[$i]->[5] eq 'accession'){
               $pages[$page_nr-1]->image(image=>$image, xpos=>$left_margin + 20 + ($label_count -1) * $final_barcode_width, ypos=>$ypos, xalign=>0, yalign=>2, xscale=>$scalex, yscale=>$scaley);
           }else{
               $pages[$page_nr-1]->image(image=>$image, xpos=>$left_margin + 50 + ($label_count -1) * $final_barcode_width, ypos=>$ypos, xalign=>0, yalign=>2, xscale=>$scalex, yscale=>$scaley);
           }
           
         }
     }
     
     elsif ($cass_print_format eq '20A4' && $barcode_type eq "2D") {
         foreach my $label_count (1..$labels_per_row) {
           my $xposition = $left_margin + ($label_count -1) * $final_barcode_width;
           my $yposition = $ypos -7;
           my $label_text = $found[$i]->[1];
           my $label_size =  8;
           my $label_size_stock =  10;
           my $yposition_2 = $ypos - 10;
           my $yposition_3 = $ypos - 20;
           my $yposition_4 = $ypos - 30;
           my $yposition_5 = $ypos - 40;
           my $yposition_6 = $ypos - 50;
           my $yposition_7 = $ypos - 60;
           my $yposition_8 = $ypos - 70;
           if ($found[$i]->[5] eq 'accession'){}
           else{
                $label_text_6 = "accession: ".$found[$i]->[2];
           }          
           my $parents_20A4 = "pedigree: ".$parents;
           $label_text_5 = $found[$i]->[14];
           $label_text_4 = $found[$i]->[8];
           $label_text_8 = $found[$i]->[13];
           $pages[$page_nr-1]->string($font, $label_size, $xposition, $yposition_2, $label_text);
           $pages[$page_nr-1]->string($font, $label_size, $xposition, $yposition_3, $label_text_6);
           $pages[$page_nr-1]->string($font, $label_size, $xposition, $yposition_5, $label_text_5);
           $pages[$page_nr-1]->string($font, $label_size, $xposition, $yposition_4, $label_text_4);
            $pages[$page_nr-1]->string($font, $label_size, $xposition, $yposition_6, $label_text_8);
           if ($found[$i]->[5] eq 'accession'){
               $pages[$page_nr-1]->string($font, $label_size, $xposition, $yposition_3, $parents_20A4);
               $pages[$page_nr-1]->string($font, $label_size, $xposition, $yposition_4, $added_text);
           }else{
                $pages[$page_nr-1]->string($font, $label_size, $xposition, $yposition_7, $parents_20A4);
                $pages[$page_nr-1]->string($font, $label_size, $xposition, $yposition_8, $added_text);
           }
           $pages[$page_nr-1]->image(image=>$image, xpos=>$left_margin + 200 + ($label_count -1) * $final_barcode_width, ypos=>$ypos, xalign=>0, yalign=>2, xscale=>$scalex, yscale=>$scaley);
         }
     }
     
     elsif ($cass_print_format eq 'MUSA' && $barcode_type eq "2D") {

         foreach my $label_count (1..$labels_per_row) {
          my $label_text = $found[$i]->[1];
          my $label_size =  7;
          my $xpos = ($left_margin + ($label_count -1) * $final_barcode_width) + 85;
          my $label_count_15_xter_plot_name =  1-1;
          my $xposition = $left_margin + ($label_count_15_xter_plot_name) * $final_barcode_width - 95.63;
          my ($yposition_2, $yposition_3, $yposition_4, $yposition_5, $yposition_6);
          if ($labels_per_page > 15){
               $yposition_2 = $ypos - 10;
               $yposition_3 = $ypos - 20;
               $yposition_4 = $ypos - 30;
               $yposition_5 = $ypos - 40;
               $yposition_6 = $ypos - 50;
          }else{
               $yposition_2 = $ypos - 20;
               $yposition_3 = $ypos - 30;
               $yposition_4 = $ypos - 40;
               $yposition_5 = $ypos - 50;
               $yposition_6 = $ypos - 60;
          }
          my $plot_pedigree_text;

          $pages[$page_nr-1]->string($font, $label_size, $xposition, $yposition_2, $label_text);
              if ($found[$i]->[5] eq 'plot'){
                  $label_text_5 = "stock:".$found[$i]->[2]." ".$found[$i]->[3];
                  $label_text_6 = $found[$i]->[8];
                  if ($parents eq ''){
                      $label_text_4 = "No pedigree for ".$found[$i]->[2];
                  }else{
                      $label_text_4 = "pedigree: ".$parents;
                  }
              }
              elsif ($found[$i]->[5] eq 'accession'){
                  if ($parents eq ''){
                      $label_text_4 = "No pedigree for ".$found[$i]->[1];
                  }else{
                      $label_text_4 = "pedigree: ".$parents;
                  }
                  $label_text_5 = $found[$i]->[7];
              }
              elsif ($found[$i]->[5] eq 'plant'){
                  print "I HAVE ROW AND COL: $found[$i]->[8]\n";
                  $label_text_6 = "plot:".$found[$i]->[6];
                  $label_text_5 = "accession:".$found[$i]->[2]." ".$found[$i]->[3];
                  $label_text_7 = $found[$i]->[8];
                  if ($parents eq ''){
                      $label_text_4 = "No pedigree for ".$found[$i]->[2];
                  }else{
                      $label_text_4 = "pedigree: ".$parents;
                  }
              }
              else{
                  $label_text_4 = '';
              }
          $pages[$page_nr-1]->string($font, $label_size, $xposition, $yposition_3, $label_text_4);
          $pages[$page_nr-1]->string($font, $label_size, $xposition, $yposition_4, $label_text_5);
          $pages[$page_nr-1]->string($font, $label_size, $xposition, $yposition_5, $label_text_6);
          $pages[$page_nr-1]->string($font, $label_size, $xposition, $yposition_6, $label_text_7);
          $pages[$page_nr-1]->image(image=>$image, xpos=>$xpos, ypos=>$ypos, xalign=>0, yalign=>2, xscale=>$scalex, yscale=>$scaley);
       }
     }
     
    elsif ($barcode_type eq "1D") {

    	foreach my $label_count (1..$labels_per_row) {

            $pages[$page_nr-1]->image(image=>$image, xpos=>$left_margin + ($label_count -1) * $final_barcode_width, ypos=>$ypos, xalign=>0, yalign=>2, xscale=>$scalex, yscale=>$scaley);
    	}
    }
}

    $pdf->close();

    $c->stash->{not_found} = \@not_found;
    $c->stash->{found} = \@found;
    $c->stash->{file} = $filename;
    $c->stash->{filetype} = 'PDF';
    $c->stash->{template} = '/barcode/stock_download_result.mas';
}

# plot phenotyping barcode
sub download_qrcode : Path('/barcode/stock/download/plot_QRcode') : Args(0) {
  my $self = shift;
  my $c = shift;

  my $stock_names = $c->req->param("stock_names_2");
  my $stock_names_file = $c->req->upload("stock_names_file_2");
  my $added_text =  $c->req->param("select_barcode_text");
  my $labels_per_page =  7;
  my $page_format = "letter";
  my $labels_per_row  = 1;
  my $top_margin_mm = 12;
  my $left_margin_mm = 70;
  my $bottom_margin_mm = 12;
  my $right_margin_mm = 20;
  my $schema = $c->dbic_schema('Bio::Chado::Schema');
  my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type' )->cvterm_id();
  my $plot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type' )->cvterm_id();
  # convert mm into pixels
  #
  my ($top_margin, $left_margin, $bottom_margin, $right_margin) = map { $_ * 2.846 } ($top_margin_mm,
                    $left_margin_mm,
                    $bottom_margin_mm,
                    $right_margin_mm);

  # read file if upload
  #
  if ($stock_names_file) {
     my $stock_file_contents = read_file($stock_names_file->{tempname});
     $stock_names = $stock_names ."\n".$stock_file_contents;
  }

  $stock_names =~ s/\r//g;
  my @names = split /\n/, $stock_names;

  my @not_found;
  my @found;

  my ($row, $stockprop_name, $value, $fdata, $accession_id, $accession_name, $parents);

  foreach my $name (@names) {

    # skip empty lines
    #
    if (!$name) {
        next;
    }

    my $stock = $schema->resultset("Stock::Stock")->find( { name=>$name });

    if (!$stock) {
        push @not_found, $name;
        next;
    }

    my $stock_id = $stock->stock_id();
    my $type_id = $stock->type_id();
    if ($type_id == $accession_cvterm_id) {
      print "You are using accessions\n";
      my $error = "used only for downloading Plot barcodes.";
      $c->stash->{error} = $error;
      $c->stash->{template} = '/barcode/stock_download_result.mas';
      $c->detach;
    }

    my $dbh = $c->dbc->dbh();
    my $h = $dbh->prepare("select name, value from cvterm inner join stockprop on cvterm.cvterm_id = stockprop.type_id where stockprop.stock_id=?;");
    $h->execute($stock_id);
    my %stockprop_hash;
     while (($stockprop_name, $value) = $h->fetchrow_array) {
       $stockprop_hash{$stock_id}->{$stockprop_name} = $value;
    }
    $row = $stockprop_hash{$stock_id}->{'replicate'};
    $fdata = "rep:".$stockprop_hash{$stock_id}->{'replicate'}.' '."block:".$stockprop_hash{$stock_id}->{'block'}.' '."plot:".$stockprop_hash{$stock_id}->{'plot number'};

    my $h_acc = $dbh->prepare("select stock.uniquename, stock.stock_id FROM stock join stock_relationship on (stock.stock_id = stock_relationship.object_id) where stock_relationship.subject_id =?;");

    $h_acc->execute($stock_id);
    ($accession_name, $accession_id) = $h_acc->fetchrow_array;

    $parents = CXGN::Stock->new ( schema => $schema, stock_id => $accession_id )->get_pedigree_string('Parents');

    push @found, [ $stock_id, $name, $accession_name, $fdata, $parents];
  }

  my $dir = $c->tempfiles_subdir('pdfs');
  my ($FH, $filename) = $c->tempfile(TEMPLATE=>"pdfs/pdf-XXXXX", SUFFIX=>".pdf", UNLINK=>0);
  print STDERR "FILENAME: $filename \n\n\n";
  my $pdf = PDF::Create->new(filename=>$c->path_to($filename),
           Author=>$c->config->{project_name},
           Title=>'Labels',
           CreationDate => [ localtime ],
           Version=>1.2,
            );

  my $base_page = $pdf->new_page(MediaBox=>$pdf->get_page_size($page_format));

  my ($page_width, $page_height) = @{$pdf->get_page_size($page_format)}[2,3];

  my $label_height = int( ($page_height - $top_margin - $bottom_margin) / $labels_per_page);

  my @pages;
  foreach my $page (1..$self->label_to_page($labels_per_page, scalar(@found))) {
     print STDERR "Generating page $page...\n";
     push @pages, $base_page->new_page();
  }

  for (my $i=0; $i<@found; $i++) {
    my $label_count = $i + 1;
    my $page_nr = $self->label_to_page($labels_per_page, $label_count);
    my $label_on_page = ($label_count -1) % $labels_per_page;

    # generate barcode

    my $tempfile;
    if ($parents =~ /NA\/NA/) {
      $tempfile = $c->forward('/barcode/phenotyping_qrcode_jpg', [ $found[$i]->[0], $found[$i]->[1], $found[$i]->[2]." ".$found[$i]->[3]." ".$added_text ]);
    }
    else {
      $tempfile = $c->forward('/barcode/phenotyping_qrcode_jpg', [ $found[$i]->[0], $found[$i]->[1], $found[$i]->[2]." ".$found[$i]->[3]." ".$found[$i]->[4]." ".$added_text]);
    }

    print STDERR "$tempfile\n";
    my $image = $pdf->image($tempfile);
    print STDERR "IMAGE: ".Data::Dumper::Dumper($image);

    # note: pdf coord system zero is lower left corner
    #
    my $final_barcode_width = ($page_width - $right_margin - $left_margin) / $labels_per_row;

    my $scalex = $final_barcode_width / $image->{width};
    my $scaley = $label_height / $image->{height};

    if ($scalex < $scaley) { $scaley = $scalex; }
    else { $scalex = $scaley; }

    my $label_boundary = $page_height - ($label_on_page * $label_height) - $top_margin;

    my $ypos = $label_boundary - int( ($label_height - $image->{height} * $scaley) /2);

    $pages[$page_nr-1]->line($page_width -100, $label_boundary, $page_width, $label_boundary);

      my $font = $pdf->font('BaseFont' => 'Times-Roman');
      foreach my $label_count (1..$labels_per_row) {
        $pages[$page_nr-1]->image(image=>$image, xpos=>$left_margin + ($label_count -1) * $final_barcode_width, ypos=>$ypos, xalign=>0, yalign=>2, xscale=>$scalex, yscale=>$scaley);
      }

      my $label_text = $found[$i]->[1];
      my $label_text_2 = "Accession: ".$found[$i]->[2];
      my $label_text_3 = $found[$i]->[3];
      my $label_text_4 = "Pedigree: ".$found[$i]->[4];

        my $label_count_15_xter_plot_name =  1-1;
        my $xposition = $left_margin + ($label_count_15_xter_plot_name) * $final_barcode_width + 118.63;
        my $yposition = $ypos - 30;
        my $yposition_2 = $ypos - 40;
        my $yposition_3 = $ypos - 50;
        my $yposition_4 = $ypos - 60;
        my $yposition_5 = $ypos - 70;
        print "My X Position: $xposition and Y Position: $ypos\n";
        my $label_size =  11;
        $pages[$page_nr-1]->string($font, $label_size, $xposition, $yposition, $label_text);
        $pages[$page_nr-1]->string($font, $label_size, $xposition, $yposition_2, $label_text_2);
        $pages[$page_nr-1]->string($font, $label_size, $xposition, $yposition_3, $label_text_3);
        if ($found[$i]->[4] =~ m/^\//){
          $label_text_4 = "Pedigree: No pedigree available for ".$found[$i]->[2];
        }
        $pages[$page_nr-1]->string($font, $label_size, $xposition, $yposition_4, $label_text_4);
        $pages[$page_nr-1]->string($font, $label_size, $xposition, $yposition_5, $added_text);
}

  $pdf->close();

  $c->stash->{not_found} = \@not_found;
  $c->stash->{found} = \@found;
  $c->stash->{file} = $filename;
  $c->stash->{filetype} = 'PDF';
  $c->stash->{template} = '/barcode/stock_download_result.mas';

}

# maps the label number to a page number
sub label_to_page {
    my $self = shift;
    my $labels_per_page = shift;
    my $label_count = shift;

    my $page_count = int( ($label_count -1) / $labels_per_page) +1;
    return $page_count;
}

sub upload_barcode_output : Path('/breeders/phenotype/upload') :Args(0) {
    my ($self, $c) = @_;
    my $upload = $c->req->upload('phenotype_file');
    my @contents = split /\n/, $upload->slurp;
    my $basename = $upload->basename;
    my $tempfile = $upload->tempname; #create a tempfile with the uploaded file
    if (! -e $tempfile) {
        die "The file does not exist!\n\n";
    }
    print STDERR "***Basename= $basename, tempfile = $tempfile \n\n"; ##OK
    my $archive_path = $c->config->{archive_path};

    $tempfile = $archive_path . "/" . $basename ;
    print STDERR "**tempfile = $tempfile \n\n"; ##OK
    #chack for write permissions in $archive_path !
    my $upload_success = $upload->copy_to($archive_path . "/" . $basename); #returns false for failure, true for success
    if (!$upload_success) { die "Could not upload!\n $upload_success" ; }
    my $sb = CXGN::Stock::StockBarcode->new( { schema=> $c->dbic_schema("Bio::Chado::Schema", 'sgn_chado') });
    my $identifier_prefix = $c->config->{identifier_prefix};
    my $db_name = $c->config->{trait_ontology_db_name};

    $sb->parse(\@contents, $identifier_prefix, $db_name);
    my $parse_errors = $sb->parse_errors;
    $sb->verify; #calling the verify function
    my $verify_errors = $sb->verify_errors;
    my @errors = (@$parse_errors, @$verify_errors);
    my $warnings = $sb->warnings;
    $c->stash->{tempfile} = $tempfile;
    $c->stash(
        template => '/stock/barcode/upload_confirm.mas',
        tempfile => $tempfile,
        errors   => \@errors,
        warnings => $warnings,
        feedback_email => $c->config->{feedback_email},
        );

}

sub store_barcode_output  : Path('/barcode/stock/store') :Args(0) {
    my ($self, $c) = @_;
    my $filename = $c->req->param('tempfile');

    my @contents = read_file($filename);

    my $sb = CXGN::Stock::StockBarcode->new( { schema=> $c->dbic_schema("Bio::Chado::Schema", 'sgn_chado') });
    my $identifier_prefix = $c->config->{identifier_prefix};
    my $db_name = $c->config->{trait_ontology_db_name};
    $sb->parse(\@contents, $identifier_prefix, $db_name);
    $sb->store;
    my $error = $sb->store_error;
    my $message = $sb->store_message;
    $c->stash(
        template => '/stock/barcode/confirm_store.mas',
        error    => $error,
        message  => $message,
        );
}

###
1;#
###
