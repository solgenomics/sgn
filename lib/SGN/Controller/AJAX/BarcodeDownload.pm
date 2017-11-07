
=head1 NAME

=head1 DESCRIPTION

=head1 AUTHOR

=cut

package SGN::Controller::AJAX::BarcodeDownload;

use Moose;
use File::Slurp;
use Bio::Chado::Schema::Result::Stock::Stock;
use CXGN::Stock::StockBarcode;
use Data::Dumper;
use CXGN::Stock;
use SGN::Model::Cvterm;
use Text::Template;
use Try::Tiny;
use JSON;
use Barcode::Code128;
use PDF::API2;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );

   sub download_pdf_barcodes : Path('/barcode/download/pdf') : ActionClass('REST') { }

   sub download_pdf_barcodes_POST : Args(0) {
       my $self = shift;
       my $c = shift;
       my $schema = $c->dbic_schema('Bio::Chado::Schema');
       
       # retrieve params
       my $trial_id = $c->req->param("trial_id");
       my $label_json = $c->req->param("label_json");
       my $page_json = $c->req->param("page_json");
       my $dl_token = $c->req->param("download_token") || "no_token";
       my $dl_cookie = "download".$dl_token;
       my $dots_to_pixels_conversion_factor = 2.83; # for converting from 8 dots per mmm to 2.83 per mm (72 per inch)
       
       #decode json
       my $json = new JSON;
       my $label_params =  $json->allow_nonref->utf8->relaxed->escape_slash->loose->allow_singlequote->allow_barekey->decode($label_json);
       my $page_params =  $json->allow_nonref->utf8->relaxed->escape_slash->loose->allow_singlequote->allow_barekey->decode($page_json);
       my @label_params = @{$label_params};
       my %page_params = %{$page_params};
       #print STDERR "Label params are @label_params\n";
       
       #get trial details
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

       # Create a blank PDF file
       my $dir = $c->tempfiles_subdir('labels');
       my ($FH, $filename) = $c->tempfile(TEMPLATE=>"labels/$trial_name-XXXXX", SUFFIX=>".pdf", UNLINK=>0);
       
       my $pdf = PDF::API2->new();
       my $page = $pdf->page();    
       $page->mediabox($page_params{'width'}, $page_params{'height'});
       
       #loop through plot data, creating and saving labels to pdf
       my $col_num = 0;
       my $row_num = 0;
       
       foreach my $key (sort { $a <=> $b} keys %design) {
           
           print STDERR "Design key is $key\n";
           my %design_info = %{$design{$key}};
           
           for (my $i=0; $i < $page_params{'num_labels'}; $i++) {
               #print STDERR "Working on label num $i\n";     
               my $x = $page_params{'starting_x'} + ($col_num * $page_params{'x_increment'});
               my $y = $page_params{'starting_y'} + ($row_num * $page_params{'y_increment'});
               my $pedigree;

              foreach my $element (@label_params) {
                  my %element = %$element;
                  my $elementx = $x + ( $element{'x'} / $dots_to_pixels_conversion_factor  ); # / 2.83;
                  my $elementy = $y - ( $element{'y'} / $dots_to_pixels_conversion_factor  ); # / 2.83;

                  if ($element{'value'} eq '{$Pedigree_String}') {
                      $pedigree = CXGN::Stock->new ( schema => $schema, stock_id => $design_info{'accession_id'} )->get_pedigree_string('Parents');
                  }
                  
                #   print STDERR "Element ".$element{'type'}."_".$element{'size'}." value is ".$element{'value'}." and coords are $elementx and $elementy\n\n";
                  
                  my $label_template = Text::Template->new(
                      type => 'STRING',
                      source => $element{'value'},
                  );
               
               my $filled_value = $label_template->fill_in(
                       hash => {
                           'Accession' => $design_info{'accession_name'},
                           'Plot_Name' => $design_info{'plot_name'},
                           'Plot_Number' => $design_info{'plot_number'},
                           'Rep_Number' => $design_info{'rep_number'},
                           'Row_Number' => $design_info{'row_number'},
                           'Col_Number' => $design_info{'col_number'},
                           'Trial_Name' => $trial_name,
                           'Year' => $year,  
                           'Pedigree_String' => $pedigree,
                       },
                   );
                  
                  if ( $element{'type'} eq "128" || $element{'type'} eq "QR" ) {
       
                       if ( $element{'type'} eq "128" ) {
       
                          my $barcode_object = Barcode::Code128->new();
                          $c->tempfiles_subdir('barcode');
                          my ($png_location, $png_uri) = $c->tempfile( TEMPLATE => [ 'barcode', 'bc-XXXXX'], SUFFIX=>'.png');
                          open(PNG, ">", $png_location) or die "Can't write $png_location: $!\n";
                          binmode(PNG);
                          
                          $barcode_object->option("scale", $element{'size'});
                          $barcode_object->option("font_align", "center");
                          $barcode_object->option("padding", 5);
                          $barcode_object->barcode($filled_value);
                          my $barcode = $barcode_object->gd_image();
                          
                          print PNG $barcode->png();
                          close(PNG);
       
                           my $gfx = $page->gfx;
                           my $image = $pdf->image_png($png_location);

                           my $height = $element{'height'} / $dots_to_pixels_conversion_factor ; # scale to 72 pts per inch
                           my $width = $element{'width'} / $dots_to_pixels_conversion_factor ; # scale to 72 pts per inch
                           my $elementy = $elementy - $height; # adjust for img position sarting at bottom
                           
                           $gfx->image($image, $elementx, $elementy, $width, $height);
       
                       
                     } else {
                         $c->tempfiles_subdir('barcode');
                         my ($jpeg_location, $jpeg_uri) = $c->tempfile( TEMPLATE => [ 'barcode', 'bc-XXXXX'], SUFFIX=>'.jpg');
       
                         my $barcode_generator = CXGN::QRcode->new();
                         my $barcode_file = $barcode_generator->get_barcode_file(
                               $jpeg_location,
                               $filled_value,
                               $element{'size'}
                          );
                          
                          my $gfx = $page->gfx;
                          my $image = $pdf->image_jpeg($jpeg_location);
                        
                          my $height = $element{'height'} / $dots_to_pixels_conversion_factor ; # scale to 72 pts per inch
                          my $width = $element{'width'} / $dots_to_pixels_conversion_factor ; # scale to 72 pts per inch
                          my $elementy = $elementy - $height; # adjust for img position sarting at bottom
                          #print STDERR "Element ".$element{'type'}."_".$element{'size'}." new y is $elementy\n";

                          $gfx->image($image, $elementx, $elementy, $width, $height);
       
                     }
                  } 
                  else {
                       # Add a built-in font to the PDF
                       my $font = $pdf->corefont($element{'type'});
       
                       # Add text to the page
                       my $text = $page->text();
                       my $adjusted_size = $element{'size'} / $dots_to_pixels_conversion_factor; # scale to 72 pts per inch
                       $text->font($font, $adjusted_size);
                       my $midpoint= ($element{'height'} / $dots_to_pixels_conversion_factor ) / 2;
                       my $elementy = $elementy - $midpoint; # adjust for position starting at middle
                       #print STDERR "Element ".$element{'type'}."_".$element{'size'}." new y is $elementy\n";
                       $text->translate($elementx, $elementy);
                       $text->text($filled_value);
       
                  }
                  
              }
                
               if ($col_num < $page_params{'number_of_columns'}) { #next column
                   $col_num++;
               } else { #new row, reset col num
                   $col_num = 0;
                   $row_num++;
               }
               
               if ($row_num > $page_params{'number_of_rows'}) { #new page, reset row and col num
                   $page = $pdf->page();
                   $col_num = 0;
                   $row_num = 0;
               }
           }
       }
    
       print STDERR "Saving the PDF . . .\n";
       $pdf->saveas($FH);
       close($FH);
       $c->res->cookies->{$dl_cookie} = {
         value => $dl_token,
         expires => '+1m',
       };
       print STDERR "Returning with filename . . .\n";
       $c->stash->{filetype} = 'PDF';
       $c->stash->{rest} = { filename => $filename };


   }


# sub download_zpl_barcodes : Path('/barcode/download/zpl') : ActionClass('REST') { }
# 
# sub download_zpl_barcodes_POST : Args(0) {
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
#      my $zpl = $c->req->param("zpl_template") || '^LH{ $X },{ $Y }
# ^FO5,10^AA,{ $FONT_SIZE }^FB320,5^FD{ $ACCESSION_NAME }^FS
# ^FO20,70^AA,28^FDPlot { $PLOT_NUMBER }, Rep { $REP_NUMBER }^AF4^FS
# ^FO22,70^AA,28^FD     { $PLOT_NUMBER }      { $REP_NUMBER }^AF4^FS
# ^FO20,72^AA,28^FD     { $PLOT_NUMBER }      { $REP_NUMBER }^AF4^FS
# ^FO20,105^AA,22^FD{ $TRIAL_NAME } { $YEAR }^FS
# ^FO10,140^AA,28^FB300,5^FD{ $CUSTOM_TEXT }^FS
# ^FO325,5^BQ,,{ $QR_SIZE }^FD   { $PLOT_NAME }^FS
# ';
#     my $zpl_template = Text::Template->new(
#         type => 'STRING',
#         source => $zpl,
#     );
#     
#     # retrieve variable params
#     my $trial_id = $c->req->param("trial_id");
#     my $labels_per_stock = $c->req->param("num_labels");# || 1;
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
#         my $pedigree = CXGN::Stock->new ( schema => $schema, stock_id => $design_info{'accession_id'} )->get_pedigree_string('Parents');
#         print STDERR "Pedigree for $accession_name is $pedigree\n";
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
#                         TRIAL_NAME => $trial_name,
#                         YEAR => $year,  
#                         FONT_SIZE => $font_size,
#                         QR_SIZE => $qr_size,
#                         PEDIGREE => $pedigree,
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
#     $c->stash->{rest} = { filename => $pdf_filename };
# 
# }
# 
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
