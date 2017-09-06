
package SGN::Controller::StockBarcode;

use Moose;
use File::Slurp;
use PDF::Create;
use Bio::Chado::Schema::Result::Stock::Stock;
use CXGN::Stock::StockBarcode;
use Data::Dumper;
use CXGN::Stock;
use SGN::Model::Cvterm;

BEGIN { extends "Catalyst::Controller"; }

use CXGN::ZPL;


sub download_zpl_barcodes : Path('/barcode/stock/download/zpl') :Args(0) {
    my $self = shift;
    my $c = shift;

    my $stock_names = $c->req->param("stock_names");
    my $stock_names_file = $c->req->upload("stock_names_file");

    my $complete_list = $stock_names ."\n".$stock_names_file;

    $complete_list =~ s/\r//g;

    my @names = split /\n/, $complete_list;

    my @not_found;
    my @found;
    my @labels;

    my $schema = $c->dbic_schema('Bio::Chado::Schema');

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

	push @found, $name;

	# generate new zdl label
	#
	my $label = CXGN::ZPL->new();
	$label->start_format();
	$label->barcode_code128($c->config->{identifier_prefix}.$stock_id);
	$label->end_format();
	push @labels, $label;

    }

    my $dir = $c->tempfiles_subdir('zpl');
    my ($FH, $filename) = $c->tempfile(TEMPLATE=>"zpl/zpl-XXXXX", UNLINK=>0);

    foreach my $label (@labels) {
        print $FH $label->render();
    }
    close($FH);

    $c->stash->{not_found} = \@not_found;
    $c->stash->{found} = \@found;
    $c->stash->{file} = $filename;
    $c->stash->{filetype} = "ZPL";
    $c->stash->{template} = '/barcode/stock_download_result.mas';

}


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
    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type' )->cvterm_id();
    my $plant_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant', 'stock_type' )->cvterm_id();

    # convert mm into pixels
    #
    if ($cass_print_format eq 'NCSU') {$left_margin_mm = 50, $top_margin_mm = 12, $bottom_margin_mm =  12, $right_margin_mm = 12, $labels_per_page = 10, $labels_per_row = 3, $barcode_type = "2D"; }
    if ($cass_print_format eq 'CASS') {$left_margin_mm = 112, $top_margin_mm = 10, $bottom_margin_mm =  13; }
    if ($cass_print_format eq 'MUSA') {$left_margin_mm = 112, $top_margin_mm = 10, $bottom_margin_mm =  13; }
    if ($cass_print_format eq '24A4') {$left_margin_mm = 112, $top_margin_mm = 10, $bottom_margin_mm =  13; }
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

    my ($row, $stockprop_name, $value, $fdata_block, $fdata_rep, $fdata_plot, $fdata, $accession_id, $accession_name, $parents, $tract_type_id, $label_text_5, $plot_name, $label_text_6, $musa_row_col_number, $label_text_7);

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
                $fdata_plot = "plot:".$stockprop_hash{$stock_id}->{'plot number'};
                $musa_row_col_number = "row:".$stockprop_hash{$stock_id}->{'row_number'}.' '."col:".$stockprop_hash{$stock_id}->{'col_number'};
                
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
          $musa_row_col_number = "row:".$stockprop_hash{$stock_id}->{'row_number'}.' '."col:".$stockprop_hash{$stock_id}->{'col_number'};
          
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

      push @found, [ $c->config->{identifier_prefix}.$stock_id, $name, $accession_name, $fdata, $parents, $tract_type_id, $plot_name, $synonym_string, $musa_row_col_number, $fdata_block, $fdata_rep, $fdata_plot];
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
    if ($cass_print_format eq '24A4') {$barcode_type = "2D", $labels_per_row = 4; }

    my $base_page = $pdf->new_page(MediaBox=>$pdf->get_page_size($page_format));

    my ($page_width, $page_height) = @{$pdf->get_page_size($page_format)}[2,3];
    
    ## for 10 labels per page
    my $label_height;
    if ($cass_print_format eq 'NCSU'){
        $label_height = 40;
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
        
        my $final_barcode_width = ($page_width - $right_margin - $left_margin) / $labels_per_row;
        my $scalex = $final_barcode_width / $image->{width};
        my $scaley = $label_height / $image->{height};
        
        if ($scalex < $scaley) { $scaley = $scalex; }
    	else { $scalex = $scaley; }
        
        my ($year_text, $location_text, $ypos, $label_boundary);
        if ($cass_print_format eq 'NCSU'){
            ($year_text,$location_text) = split ',', $added_text;
            my $label_height_10_per_page = 72;
     	    $label_boundary = $page_height - ($label_on_page * $label_height_10_per_page) - $top_margin;
            $ypos = $label_boundary - int( ($label_height_10_per_page - $image->{height} * $scaley) /2);
        }
        else{
            $label_boundary = $page_height - ($label_on_page * $label_height) - $top_margin;
        	$ypos = $label_boundary - int( ($label_height - $image->{height} * $scaley) /2);
        }

    	$pages[$page_nr-1]->line($page_width -100, $label_boundary, $page_width, $label_boundary);

      # my $lebel_number = scalar($#{$found[$i]});
      my $font = $pdf->font('BaseFont' => 'Courier');
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
     
     elsif ($cass_print_format eq 'NCSU' && $barcode_type eq "2D") {
         foreach my $label_count (1..$labels_per_row) {
           my $xposition = $left_margin + ($label_count -1) * $final_barcode_width - 50;
           my $yposition = $ypos -7;
           my $label_text = $found[$i]->[1];
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
           $label_text_4 = $found[$i]->[10];
           $pages[$page_nr-1]->string($font, $label_size_stock, $xposition, $yposition_8, $label_text_6);
           $pages[$page_nr-1]->string($font, $label_size, $xposition, $yposition_4, $year_text);
           $pages[$page_nr-1]->string($font, $label_size, $xposition, $yposition_3, $label_text_4);
           $pages[$page_nr-1]->string($font, $label_size, $xposition, $yposition_2, $label_text_5);
           $pages[$page_nr-1]->string($font, $label_size, $xposition, $yposition_5, $location_text);
           $pages[$page_nr-1]->string($font, $label_size_stock, $xposition, $yposition_6, $label_text);
           
           $pages[$page_nr-1]->image(image=>$image, xpos=>$left_margin + ($label_count -1) * $final_barcode_width, ypos=>$ypos, xalign=>0, yalign=>2, xscale=>$scalex, yscale=>$scaley);
 
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
