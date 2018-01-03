package SGN::Controller::AJAX::LabelDesigner;

use Moose;
use CXGN::Stock;
use CXGN::List::Transform;
use Data::Dumper;
use Try::Tiny;
use JSON;
use Barcode::Code128;
use CXGN::QRcode;
use CXGN::ZPL;
use PDF::API2;
use Sort::Versions;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );

   sub retrieve_longest_fields :Path('/tools/label_designer/retrieve_longest_fields') {
        my $self = shift;
        my $c = shift;
        my $schema = $c->dbic_schema('Bio::Chado::Schema');
        my $data_type = $c->req->param("data_type");
        my $value = $c->req->param("value");
        my %longest_hash;
        print STDERR "Data type is $data_type and id is $value\n";
       my ($trial_num, $trial_id, $design) = get_plot_data($c, $schema, $data_type, $value);
       print STDERR "AFTER SUB: \nTrial_id is $trial_id and design is ". Dumper($design) ."\n";
       if ($trial_num > 1) {
           $c->stash->{rest} = { error => "The selected list contains plots from more than one trial. This is not supported. Please select a different data source." };
           return;
       }

       my $trial_name = $schema->resultset("Project::Project")->search({ project_id => $trial_id })->first->name();
       if (!$trial_name) {
           $c->stash->{rest} = { error => "Trial with id $trial_id does not exist. Can't create labels." };
           return;
       }

       my %design = %{$design};
       if (!%design) {
           $c->stash->{rest} = { error => "Trial $trial_name does not have a valid field design. Can't create labels." };
           return;
       }
       $longest_hash{'trial_name'} = $trial_name;

       my $year_cvterm_id = $schema->resultset("Cv::Cvterm")->search({name=> 'project year' })->first->cvterm_id();
       my $year = $schema->resultset("Project::Projectprop")->search({ project_id => $trial_id, type_id => $year_cvterm_id } )->first->value();
       $longest_hash{'year'} = $year;


       #get all fields in this trials design
       my $random_plot = $design{(keys %design)[rand keys %design]};
       my @keys = keys %{$random_plot};
       foreach my $field (@keys) {
           print STDERR " Searching for longest $field\n";
           #for each field order values by descending length, then save the first one
           foreach my $key ( sort { length($design{$b}{$field}) <=> length($design{$a}{$field}) or  $a <=> $b } keys %design) {
                print STDERR "Longest $field is: ".$design{$key}{$field}."\n";
                my $longest = $design{$key}{$field};
                unless (ref($longest) || length($longest) < 1) { # skip if not scalar or undefined
                    $longest_hash{$field} = $design{$key}{$field};
                }
                last;
            }
        }

        # save longest pedigree string
        my $pedigree_strings = get_all_pedigrees($schema, \%design);
        my %pedigree_strings = %{$pedigree_strings};

        foreach my $key ( sort { length($pedigree_strings{$b}) <=> length($pedigree_strings{$a}) } keys %pedigree_strings) {
            $longest_hash{'pedigree_string'} = $pedigree_strings{$key};
            last;
        }

        #print STDERR "Dumped data is: ".Dumper(%longest_hash);
        $c->stash->{rest} = \%longest_hash;
   }

   sub label_designer_download : Path('/tools/label_designer/download') : ActionClass('REST') { }

   sub label_designer_download_GET : Args(0) {
        my $self = shift;
        my $c = shift;
        $c->forward('label_designer_download_POST');
    }

  sub label_designer_download_POST : Args(0) {
       my $self = shift;
       my $c = shift;
       my $schema = $c->dbic_schema('Bio::Chado::Schema');
       my $download_type = $c->req->param("download_type");
    #    my $trial_id = $c->req->param("trial_id");
       my $data_type = $c->req->param("data_type");
       my $value = $c->req->param("value");
       my $design_json = $c->req->param("design_json");
       my $conversion_factor = 2.83; # for converting from 8 dots per mmm to 2.83 per mm (72 per inch)

       # decode json
       my $json = new JSON;
       my $design_params = $json->allow_nonref->utf8->relaxed->escape_slash->loose->allow_singlequote->allow_barekey->decode($design_json);

       my ($trial_num, $trial_id, $design) = get_plot_data($c, $schema, $data_type, $value);
       if ($trial_num > 1) {
           $c->stash->{rest} = { error => "The selected list contains plots from more than one trial. This is not supported. Please select a different data source." };
           return;
       }

        my $trial_name = $schema->resultset("Project::Project")->search({ project_id => $trial_id })->first->name();
        if (!$trial_name) {
            $c->stash->{rest} = { error => "Trial with id $trial_id does not exist. Can't create labels." };
            return;
        }
       my %design = %{$design};
       if (!$design) {
           $c->stash->{rest} = { error => "Trial $trial_name does not have a valid field design. Can't create labels." };
           return;
       }

       my $year_cvterm_id = $schema->resultset("Cv::Cvterm")->search({name=> 'project year' })->first->cvterm_id();
       my $year = $schema->resultset("Project::Projectprop")->search({ project_id => $trial_id, type_id => $year_cvterm_id } )->first->value();

       my $label_params = $design_params->{'label_elements'};
       # if needed retrieve pedigrees in bulk
       my $pedigree_strings;
       foreach my $element (@$label_params) {
           if ($element->{'value'} eq '{pedigree_string}') {
               $pedigree_strings = get_all_pedigrees($schema, $design);
           }
       }

       # Create a blank PDF file
       my $dir = $c->tempfiles_subdir('labels');
       my $file_prefix = $trial_name;
       $file_prefix =~ s/[^a-zA-Z0-9-_]//g;

       my ($FH, $filename) = $c->tempfile(TEMPLATE=>"labels/$file_prefix-XXXXX", SUFFIX=>".$download_type");

       # initialize loop variables
       my $col_num = 1;
       my $row_num = 1;
       my $key_number = 0;
       my $sort_order = $design_params->{'sort_order'};

       if ($download_type eq 'pdf') {
           # Create pdf
           print STDERR "Creating the PDF . . .\n";
           my $pdf  = PDF::API2->new(-file => $FH);
           my $page = $pdf->page();
           my $text = $page->text();
           my $gfx = $page->gfx();
           $page->mediabox($design_params->{'page_width'}, $design_params->{'page_height'});

           # loop through plot data in design hash
           foreach my $key ( sort { versioncmp( $design{$a}{$sort_order} , $design{$b}{$sort_order} ) or  $a <=> $b } keys %design) {

                #print STDERR "Design key is $key\n";
                my %design_info = %{$design{$key}};
                $design_info{'trial_name'} = $trial_name;
                $design_info{'year'} = $year;
                $design_info{'pedigree_string'} = $pedigree_strings->{$design_info{'accession_name'}};
                #print STDERR "Design info: " . Dumper(%design_info);

                for (my $i=0; $i < $design_params->{'copies_per_plot'}; $i++) {
                    #print STDERR "Working on label num $i\n";
                    my $label_x = $design_params->{'left_margin'} + ($design_params->{'label_width'} + $design_params->{'horizontal_gap'}) * ($col_num-1);
                    my $label_y = $design_params->{'page_height'} - $design_params->{'top_margin'} - ($design_params->{'label_height'} + $design_params->{'vertical_gap'}) * ($row_num-1);

                   foreach my $element (@$label_params) {
                       #print STDERR "Element Dumper\n" . Dumper($element);
                       my %element = %{$element};
                       my $elementx = $label_x + ( $element{'x'} / $conversion_factor );
                       my $elementy = $label_y - ( $element{'y'} / $conversion_factor );

                       my $filled_value = $element{'value'};
                       $filled_value =~ s/\{(.*?)\}/process_field($1,$key_number,\%design_info)/ge;
                       #print STDERR "Element ".$element{'type'}."_".$element{'size'}." filled value is ".$filled_value." and coords are $elementx and $elementy\n";
                       print STDERR "Writing to the PDF . . .\n";
                       if ( $element{'type'} eq "Code128" || $element{'type'} eq "QRCode" ) {

                            if ( $element{'type'} eq "Code128" ) {

                               my $barcode_object = Barcode::Code128->new();

                               my ($png_location, $png_uri) = $c->tempfile( TEMPLATE => [ 'barcode', 'bc-XXXXX'], SUFFIX=>'.png');
                               open(PNG, ">", $png_location) or die "Can't write $png_location: $!\n";
                               binmode(PNG);

                               $barcode_object->option("scale", $element{'size'}, "font_align", "center", "padding", 5, "show_text", 0);
                               $barcode_object->barcode($filled_value);
                               my $barcode = $barcode_object->gd_image();
                               print PNG $barcode->png();
                               close(PNG);

                                my $image = $pdf->image_png($png_location);
                                my $height = $element{'height'} / $conversion_factor ; # scale to 72 pts per inch
                                my $width = $element{'width'} / $conversion_factor ; # scale to 72 pts per inch
                                my $elementy = $elementy - ($height/2); # adjust for img position sarting at bottom
                                my $elementx = $elementx - ($width/2);
                                #print STDERR 'adding Code 128 params $image, $elementx, $elementy, $width, $height with: '."$image, $elementx, $elementy, $width, $height\n";
                                $gfx->image($image, $elementx, $elementy, $width, $height);


                          } else { #QRCode

                              my ($jpeg_location, $jpeg_uri) = $c->tempfile( TEMPLATE => [ 'barcode', 'bc-XXXXX'], SUFFIX=>'.jpg');
                              my $barcode_generator = CXGN::QRcode->new(
                                  text => $filled_value,
                                  size => $element{'size'},
                                  margin => 0,
                                  version => 0,
                                  level => 'M'
                              );
                              my $barcode_file = $barcode_generator->get_barcode_file($jpeg_location);

                               my $image = $pdf->image_jpeg($jpeg_location);
                               my $height = $element{'height'} / $conversion_factor ; # scale to 72 pts per inch
                               my $width = $element{'width'} / $conversion_factor ; # scale to 72 pts per inch
                               my $elementy = $elementy - ($height/2); # adjust for img position sarting at bottom
                               my $elementx = $elementx - ($width/2);
                               $gfx->image($image, $elementx, $elementy, $width, $height);

                          }
                       }
                       else { #Text

                            my $font = $pdf->corefont($element{'font'}); # Add a built-in font to the PDF
                            # Add text to the page
                            my $adjusted_size = $element{'size'} / $conversion_factor; # scale to 72 pts per inch
                            $text->font($font, $adjusted_size);
                            my $height = $element{'height'} / $conversion_factor ; # scale to 72 pts per inch
                            my $elementy = $elementy - ($height/4); # adjust for img position starting at bottom
                            $text->translate($elementx, $elementy);
                            $text->text_center($filled_value);
                       }
                   }

                    if ($col_num < $design_params->{'number_of_columns'}) { #next column
                        $col_num++;
                    } else { #new row, reset col num
                        $col_num = 1;
                        $row_num++;
                    }

                    if ($row_num > $design_params->{'number_of_rows'}) { #create new page and reset row and col num
                        $pdf->finishobjects($page, $gfx, $text); #flush the page to save memory on big PDFs
                        $page = $pdf->page();
                        $text = $page->text();
                        $gfx = $page->gfx();
                        $page->mediabox($design_params->{'page_width'}, $design_params->{'page_height'});
                        $row_num = 1;
                    }
                }
             $key_number++;
             }

           print STDERR "Saving the PDF . . .\n";
           $pdf->save();

       } elsif ($download_type eq 'zpl') {

           print STDERR "Generating zpl . . .\n";
           my $zpl_obj = CXGN::ZPL->new(
               print_width => $design_params->{'label_width'} * $conversion_factor,
               label_length => $design_params->{'label_height'} * $conversion_factor
           );
           $zpl_obj->start_sequence();
           $zpl_obj->label_format();
           foreach my $element (@$label_params) {
               my $x = $element->{'x'} - ($element->{'width'}/2);
               my $y = $element->{'y'} - ($element->{'height'}/2);
               $zpl_obj->new_element($element->{'type'}, $x, $y, $element->{'size'}, $element->{'value'});
           }
           $zpl_obj->end_sequence();
           my $zpl_template = $zpl_obj->render();
           foreach my $key ( sort { versioncmp( $design{$a}{$sort_order} , $design{$b}{$sort_order} ) or  $a <=> $b } keys %design) {
            #    print STDERR "Design key is $key\n";
               my %design_info = %{$design{$key}};
               $design_info{'trial_name'} = $trial_name;
               $design_info{'year'} = $year;
               $design_info{'pedigree_string'} = $pedigree_strings->{$design_info{'accession_name'}};

               my $zpl = $zpl_template;
               $zpl =~ s/\{(.*?)\}/process_field($1,$key_number,\%design_info)/ge;
              for (my $i=0; $i < $design_params->{'copies_per_plot'}; $i++) {
                  print $FH $zpl;
               }
            $key_number++;
            }
       }

       close($FH);
       print STDERR "Returning with filename . . .\n";
       $c->stash->{rest} = { filename => $c->config->{basepath}."/".$filename };

   }

sub process_field {
    my $field = shift;
    my $key_number = shift;
    my $design_info = shift;
    my %design_info = %{$design_info};
    print STDERR "Field is $field\n";
    if ($field =~ m/Number:/) {
        our ($placeholder, $start_num, $increment) = split ':', $field;
        my $length = length($start_num);
        #print STDERR "Increment is $increment\nKey Number is $key_number\n";
        my $custom_num =  $start_num + ($increment * $key_number);
        return sprintf("%0${length}d", $custom_num);
    } else {
        return $design_info{$field};
    }
}

sub get_all_pedigrees {
    my $schema = shift;
    my $design = shift;
    my %design = %{$design};

    # collect all unique accession ids for pedigree retrieval
    my %accession_id_hash;
    foreach my $key (keys %design) {
        $accession_id_hash{$design{$key}{'accession_id'}} = $design{$key}{'accession_name'};
    }
    my @accession_ids = keys %accession_id_hash;

    # retrieve pedigree info using batch download (fastest method), then extract pedigree strings from download rows.
    my $stock = CXGN::Stock->new ( schema => $schema);
    my $pedigree_rows = $stock->get_pedigree_rows(\@accession_ids, 'parents_only');
    my %pedigree_strings;
    foreach my $row (@$pedigree_rows) {
        my ($progeny, $female_parent, $male_parent, $cross_type) = split "\t", $row;
        my $string = join ('/', $female_parent ? $female_parent : 'NA', $male_parent ? $male_parent : 'NA');
        $pedigree_strings{$progeny} = $string;
    }
    return \%pedigree_strings;
}

sub get_plot_data {
    my $c = shift;
    my $schema = shift;
    my $data_type = shift;
    my $value = shift;
    my $num_trials = 1;
    my ($trial_id, $design);
    print STDERR "Data type is $data_type and value is $value\n";
    if ($data_type =~ m/Plot List/) {
        # get items from list, get trial id from plot id. Or, get plot dta one by one
        my $plot_data = SGN::Controller::AJAX::List->retrieve_list($c, $value);
        my @plot_list = map { $_->[1] } @$plot_data;
        my $t = CXGN::List::Transform->new();
        my $acc_t = $t->can_transform("plots", "plot_ids");
        my $plot_id_hash = $t->transform($schema, $acc_t, \@plot_list);
        my @plot_ids = @{$plot_id_hash->{transform}};
        my $trial_rs = $schema->resultset("NaturalDiversity::NdExperimentStock")->search({
            stock_id => { -in => \@plot_ids }
        })->search_related('nd_experiment')->search_related('nd_experiment_projects');
        my %trials = ();
        while (my $row = $trial_rs->next()) {
            print STDERR "Looking at id ".$row->project_id()."\n";
            my $id = $row->project_id();
            $trials{$id} = 1;
        }
        $num_trials = scalar keys %trials;
        print STDERR "Count is $num_trials\n";
        $trial_id = $trial_rs->first->project_id();
        my $full_design = CXGN::Trial::TrialLayout->new({schema => $schema, trial_id => $trial_id })->get_design();
        print STDERR "Full Design is: ".Dumper($full_design);
        # reduce design hash, removing plots that aren't in list
        my %full_design = %{$full_design};

        foreach my $i (0 .. $#plot_ids) {
            foreach my $key (keys %full_design) {
                if ($full_design{$key}->{'plot_id'} eq $plot_ids[$i]) {
                    print STDERR "Plot name is ".$full_design{$key}->{'plot_name'}."\n";
                    $design->{$key} = $full_design{$key};
                    $design->{$key}->{'list_order'} = $i;
                }
            }
        }

    } elsif ($data_type =~ m/Trial/) {
        $trial_id = $value;
        $design = CXGN::Trial::TrialLayout->new({schema => $schema, trial_id => $trial_id })->get_design();
    }
    return ($num_trials, $trial_id, $design);
}


#########
1;
#########
