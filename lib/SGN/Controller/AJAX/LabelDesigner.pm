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
use Tie::UrlEncoder; our(%urlencode);
use CXGN::Trial::TrialLayout;
use CXGN::Trial;
use CXGN::Trial::TrialLayoutDownload;

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
        my $source_id = $c->req->param("source_id");
        my $data_level = $c->req->param("data_level");
        my %longest_hash;
        #print STDERR "Data type is $data_type and id is $value\n";

        my ($trial_num, $design) = get_data($c, $schema, $data_type, $data_level, $source_id);

       if ($trial_num > 1) {
           $c->stash->{rest} = { error => "The selected list contains plots, plants, subplots or tissues from more than one trial. This is not supported. Please select a different data source." };
           return;
       }

       my %design = %{$design};
       # print STDERR "A plot before undef deletion is ".Dumper($design{(keys %design)[rand keys %design]});
       #delete any undefined fields
       foreach my $key (keys %design) {
           my %plot = %{$design{$key}};
           delete $design{$key}{$_} for grep { !defined $plot{$_} } keys %plot;
       }
       # print STDERR "A plot after undef deletion is ".Dumper($design{(keys %design)[rand keys %design]});
       #get all fields in this trials design
       my $random_plot = $design{(keys %design)[rand keys %design]};
       my %reps;
       my @keys = keys %{$random_plot};
       foreach my $field (@keys) {

           # if rep_number, find unique options and return them
           if ($field eq 'rep_number') {
               print STDERR "Searching for unique rep numbers.\n";
            #    foreach my $key (keys %design) {
               $reps{$_->{'rep_number'}}++ foreach values %design;
               print STDERR "Reps: ".Dumper(%reps);
           }


           print STDERR " Searching for longest $field\n";
           #for each field order values by descending length, then save the first one
           foreach my $key ( sort { length($design{$b}{$field}) <=> length($design{$a}{$field}) or versioncmp($a, $b) } keys %design) {
                print STDERR "Longest $field is: ".$design{$key}{$field}."\n";
                my $longest = $design{$key}{$field};
                unless (ref($longest) || length($longest) < 1) { # skip if not scalar or undefined
                    $longest_hash{$field} = $longest;
                } elsif (ref($longest) eq 'ARRAY') { # if array (ex. plants), sort array by length and take longest
                    print STDERR "Processing array " . Dumper($longest) . "\n";
                    # my @array = @{$longest};
                    my @sorted = sort { length $a <=> length $b } @{$longest};
                    if (length($sorted[0]) > 0) {
                        $longest_hash{$field} = $sorted[0];
                    }
                } elsif (ref($longest) eq 'HASH') {
                    print STDERR "Not handling hashes yet\n";
                }
                last;
            }
        }

        #print STDERR "Dumped data is: ".Dumper(%longest_hash);
        $c->stash->{rest} = {
            fields => \%longest_hash,
            reps => \%reps,
        };
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
       my $data_type = $c->req->param("data_type");
       my $data_level = $c->req->param("data_level");
       my $source_id = $c->req->param("source_id");
       my $source_name = $c->req->param("source_name");
       my $design_json = $c->req->param("design_json");
       my $labels_to_download = $c->req->param("labels_to_download") || 10000000000;
       my $conversion_factor = 2.83; # for converting from 8 dots per mmm to 2.83 per mm (72 per inch)

       # decode json
       my $json = new JSON;
       my $design_params = $json->allow_nonref->utf8->relaxed->escape_slash->loose->allow_singlequote->allow_barekey->decode($design_json);

       my ($trial_num, $design) = get_data($c, $schema, $data_type, $data_level, $source_id);

       # my ($trial_num, $trial_id, $plot_design, $plant_design, $subplot_design, $tissue_sample_design) = get_data($c, $schema, $data_type, $value);
       #
       # #if plant ids or names are used in design params, use plant design
       #
       # my $design = $plot_design;
       my $label_params = $design_params->{'label_elements'};
       # foreach my $element (@$label_params) {
       #     my %element = %{$element};
       #     my $filled_value = $element{'value'};
       #     print STDERR "Filled value is $filled_value\n";
       #     if ($filled_value =~ m/{plant_id}/ || $filled_value =~ m/{plant_name}/  || $filled_value =~ m/{plant_index_number}/) {
       #         $design = $plant_design;
       #     }
       #     if ($filled_value =~ m/{subplot_id}/ || $filled_value =~ m/{subplot_name}/ || $filled_value =~ m/{subplot_index_number}/) {
       #         $design = $subplot_design;
       #     }
       #     if ($filled_value =~ m/{tissue_sample_id}/ || $filled_value =~ m/{tissue_sample_name}/ || $filled_value =~ m/{tissue_sample_index_number}/) {
       #         $design = $tissue_sample_design;
       #     }
       # }

       if ($trial_num > 1) {
           $c->stash->{rest} = { error => "The selected list contains plots from more than one trial. This is not supported. Please select a different data source." };
           return;
       }

       my %design = %{$design};
       if (!$design) {
           $c->stash->{rest} = { error => "$source_name is not linked to a valid field design. Can't create labels." };
           return;
       }

       # my $design_cvterm_id = $schema->resultset("Cv::Cvterm")->search({name=> 'design' })->first->cvterm_id();
       # my $design_value = $schema->resultset("Project::Projectprop")->search({ project_id => $trial_id, type_id => $design_cvterm_id } )->first->value();
       #
       # my ($genotyping_facility, $genotyping_project_name);
       # if ($design_value eq "genotyping_plate") { # for genotyping plates, get "Genotyping Facility" and "Genotyping Project Name"
       #     my $genotyping_facility_cvterm_id = $schema->resultset("Cv::Cvterm")->search({name=> 'genotyping_facility' })->first->cvterm_id();
       #     my $geno_project_name_cvterm_id = $schema->resultset("Cv::Cvterm")->search({name=> 'genotyping_project_name' })->first->cvterm_id();
       #     $genotyping_facility = $schema->resultset("Project::Projectprop")->search({ project_id => $trial_id, type_id => $genotyping_facility_cvterm_id } )->first->value();
       #     $genotyping_project_name = $schema->resultset("NaturalDiversity::NdExperimentProject")->search({
       #             project_id => $trial_id
       #         })->search_related('nd_experiment')->search_related('nd_experimentprops',{
       #             'nd_experimentprops.type_id' => $geno_project_name_cvterm_id
       #         })->first->value();
       # }
       #
       # my $year_cvterm_id = $schema->resultset("Cv::Cvterm")->search({name=> 'project year' })->first->cvterm_id();
       # my $year = $schema->resultset("Project::Projectprop")->search({ project_id => $trial_id, type_id => $year_cvterm_id } )->first->value();
       #
       # if needed retrieve pedigrees in bulk
       # my $pedigree_strings;
       # foreach my $element (@$label_params) {
       #     if ($element->{'value'} =~ m/{pedigree_string}/ ) {
       #         $pedigree_strings = get_all_pedigrees($schema, $design);
       #     }
       # }

       # Create a blank PDF file
       my $dir = $c->tempfiles_subdir('labels');
       my $file_prefix = $source_name;
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

               if ($key_number >= $labels_to_download){
                   last;
               }

                #print STDERR "Design key is $key\n";
                my %design_info = %{$design{$key}};
                # $design_info{'trial_name'} = $trial_name;
                # $design_info{'year'} = $year;
                # $design_info{'genotyping_facility'} = $genotyping_facility;
                # $design_info{'genotyping_project_name'} = $genotyping_project_name;
                # $design_info{'pedigree_string'} = $pedigree_strings->{$design_info{'accession_name'}};
                #print STDERR "Design info: " . Dumper(%design_info);

                if ( $design_params->{'plot_filter'} eq 'all' || $design_params->{'plot_filter'} eq $design_info{'rep_number'}) { # filter by rep if needed

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
                           # print STDERR "Filled value b4: $filled_value";
                           $filled_value =~ s/\{(.*?)\}/process_field($1,$key_number,\%design_info)/ge;
                           # print STDERR "\tFilled value after: $filled_value\n";
                           #print STDERR "Element ".$element{'type'}."_".$element{'size'}." filled value is ".$filled_value." and coords are $elementx and $elementy\n";
                           #print STDERR "Writing to the PDF . . .\n";
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

               if ($key_number >= $labels_to_download){
                   last;
               }

            #    print STDERR "Design key is $key\n";
               my %design_info = %{$design{$key}};
               # $design_info{'trial_name'} = $trial_name;
               # $design_info{'year'} = $year;
               # $design_info{'pedigree_string'} = $pedigree_strings->{$design_info{'accession_name'}};

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
       $c->stash->{rest} = {
           filename => $urlencode{$filename},
           filepath => $c->config->{basepath}."/".$filename
       };

   }

sub process_field {
    my $field = shift;
    my $key_number = shift;
    my $design_info = shift;
    my %design_info = %{$design_info};
    #print STDERR "Field is $field\n";
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

# sub get_all_pedigrees {
#     my $schema = shift;
#     my $design = shift;
#     my %design = %{$design};
#
#     # collect all unique accession ids for pedigree retrieval
#     my %accession_id_hash;
#     foreach my $key (keys %design) {
#         $accession_id_hash{$design{$key}{'accession_id'}} = $design{$key}{'accession_name'};
#     }
#     my @accession_ids = keys %accession_id_hash;
#
#     # retrieve pedigree info using batch download (fastest method), then extract pedigree strings from download rows.
#     my $stock = CXGN::Stock->new ( schema => $schema);
#     my $pedigree_rows = $stock->get_pedigree_rows(\@accession_ids, 'parents_only');
#     my %pedigree_strings;
#     foreach my $row (@$pedigree_rows) {
#         my ($progeny, $female_parent, $male_parent, $cross_type) = split "\t", $row;
#         my $string = join ('/', $female_parent ? $female_parent : 'NA', $male_parent ? $male_parent : 'NA');
#         $pedigree_strings{$progeny} = $string;
#     }
#     return \%pedigree_strings;
# }

sub convert_stock_list {
    my $c = shift;
    my $schema = shift;
    my $list_id = shift;
    my $list_data = SGN::Controller::AJAX::List->retrieve_list($c, $list_id);
    my @list_items = map { $_->[1] } @$list_data;
    my $t = CXGN::List::Transform->new();
    my $acc_t = $t->can_transform("stocks", "stock_ids");
    my $id_hash = $t->transform($schema, $acc_t, \@list_items);
    my @ids = @{$id_hash->{transform}};
    return \@ids;
}

sub get_trial_from_stock_list {
    my $c = shift;
    my $schema = shift;
    my $ids = shift;
    my @ids = @{$ids};

    my $trial_rs = $schema->resultset("NaturalDiversity::NdExperimentStock")->search({
        stock_id => { -in => \@ids }
    })->search_related('nd_experiment')->search_related('nd_experiment_projects');
    my %trials = ();
    while (my $row = $trial_rs->next()) {
        #print STDERR "Looking at id ".$row->project_id()."\n";
        my $id = $row->project_id();
        $trials{$id} = 1;
    }
    my $num_trials = scalar keys %trials;
    print STDERR "Number of linked trials is $num_trials\n";
    my $trial_id = $trial_rs->first->project_id();
    return $trial_id, $num_trials;
}

sub filter_by_list_items {
    my $full_design = shift;
    my $stock_ids = shift;
    my %full_design = %{$full_design};
    my @stock_ids = @{$stock_ids};
    my %plot_design;

    foreach my $i (0 .. $#stock_ids) {
        foreach my $key (keys %full_design) {
            if ($full_design{$key}->{'plot_id'} eq $stock_ids[$i]) {
                print STDERR "Plot name is ".$full_design{$key}->{'plot_name'}."\n";
                $plot_design{$key} = $full_design{$key};
                $plot_design{$key}->{'list_order'} = $i;
            }
        }
    }
    return \%plot_design;
}

sub get_trial_design {
    my $c = shift;
    my $schema = shift;
    my $trial_id = shift;
    my $type = shift;

    my %selected_columns = (
        plate => {trial_name => 1, acquisition_date => 1, exported_tissue_sample_name => 1, tissue_sample_name => 1, well_A01 => 1, row_number => 1, col_number => 1, source_observation_unit_name => 1, accession_name => 1, accession_id => 1, synonyms => 1, pedigree => 1, dna_person => 1, notes => 1, tissue_type => 1, extraction => 1, concentration => 1, volume => 1, is_blank => 1, year => 1, location_name => 1},
        plots => {plot_name => 1,plot_id => 1,block_number => 1,plot_number => 1,rep_number => 1,row_number => 1,col_number => 1,accession_name => 1,is_a_control => 1,synonyms => 1,trial_name => 1,location_name => 1,year => 1,pedigree => 1,tier => 1,seedlot_name => 1,seed_transaction_operator => 1,num_seed_per_plot => 1,range_number => 1,plot_geo_json => 1},
        plants => {plant_name=>1,plant_id=>1,block_number => 1,plot_number => 1,rep_number => 1,row_number => 1,col_number => 1,accession_name => 1,is_a_control => 1,synonyms => 1,trial_name => 1,location_name => 1,year => 1,pedigree => 1,tier => 1,seedlot_name => 1,seed_transaction_operator => 1,num_seed_per_plot => 1,range_number => 1,plot_geo_json => 1},
        subplots => {subplot_name=>1,subplot_id=>1,block_number => 1,plot_number => 1,rep_number => 1,row_number => 1,col_number => 1,accession_name => 1,is_a_control => 1,synonyms => 1,trial_name => 1,location_name => 1,year => 1,pedigree => 1,tier => 1,seedlot_name => 1,seed_transaction_operator => 1,num_seed_per_plot => 1,range_number => 1,plot_geo_json => 1},
        field_trial_tissue_samples => {tissue_sample_name=>1,tissue_sample_id=>1,block_number => 1,plot_number => 1,rep_number => 1,row_number => 1,col_number => 1,accession_name => 1,is_a_control => 1,synonyms => 1,trial_name => 1,location_name => 1,year => 1,pedigree => 1,tier => 1,seedlot_name => 1,seed_transaction_operator => 1,num_seed_per_plot => 1,range_number => 1,plot_geo_json => 1},
    );

    my $trial = CXGN::Trial->new({ bcs_schema => $schema, trial_id => $trial_id });
    # $plot_design = CXGN::Trial::TrialLayout->new({schema => $schema, trial_id => $trial_id, experiment_type=>'field_layout' })->get_design();
    my $trial_name = $schema->resultset("Project::Project")->search({ project_id => $trial_id })->first->name();
    # my $year_cvterm_id = $schema->resultset("Cv::Cvterm")->search({name=> 'project year' })->first->cvterm_id();
    # my $year = $schema->resultset("Project::Projectprop")->search({ project_id => $trial_id, type_id => $year_cvterm_id } )->first->value();
    #
    # my ($genotyping_facility, $genotyping_project_name);
    # if ($type eq "plate") { # for genotyping plates, get "Genotyping Facility" and "Genotyping Project Name"
    #     my $genotyping_facility_cvterm_id = $schema->resultset("Cv::Cvterm")->search({name=> 'genotyping_facility' })->first->cvterm_id();
    #     my $geno_project_name_cvterm_id = $schema->resultset("Cv::Cvterm")->search({name=> 'genotyping_project_name' })->first->cvterm_id();
    #     $genotyping_facility = $schema->resultset("Project::Projectprop")->search({ project_id => $trial_id, type_id => $genotyping_facility_cvterm_id } )->first->value();
    #     $genotyping_project_name = $schema->resultset("NaturalDiversity::NdExperimentProject")->search({
    #             project_id => $trial_id
    #         })->search_related('nd_experiment')->search_related('nd_experimentprops',{
    #             'nd_experimentprops.type_id' => $geno_project_name_cvterm_id
    #         })->first->value();
    # }

    my $treatments = $trial->get_treatments();
    # # my @treatments = @{$treatments};
    # print STDERR "treatments are @treatments\n";
    my @treatment_ids = map { $_->[0] } @{$treatments};
    # print STDERR "treatment ids are @treatment_ids\n";
    my $trial_layout_download = CXGN::Trial::TrialLayoutDownload->new({
        schema => $schema,
        trial_id => $trial_id,
        data_level => $type,
        treatment_project_ids => \@treatment_ids,
        selected_columns => $selected_columns{$type},
        selected_trait_ids => []
    });
    my $layout = $trial_layout_download->get_layout_output();

    # map array of arrays into hash
    my @outer_array = @{$layout->{'output'}};
    my ($inner_array, @keys, %mapped_design);
    for my $i (0 .. $#outer_array) {
        $inner_array = $outer_array[$i];
    # foreach my $inner_array (@{$outer_array}) {
        if (scalar @keys > 0) {
            my %detail_hash;
            @detail_hash{@keys} = @{$outer_array[$i]};

            my @applied_treatments;
            foreach my $key (keys %detail_hash) {
                if ( $key =~ /ManagementFactor/ && $detail_hash{$key} ) {
                    my $treatment = $key;
                    $treatment =~ s/ManagementFactor://;
                    $treatment =~ s/$trial_name//;
                    $treatment =~ s/^_//;
                    push @applied_treatments, $treatment;
                    delete($detail_hash{$key});
                }
                elsif ( $key =~ /ManagementFactor/ ) {
                    delete($detail_hash{$key});
                }
            }
            $detail_hash{'management_factor'} = join(",", @applied_treatments);
            $mapped_design{$i} = \%detail_hash;

        }
        else {
            @keys = @{$inner_array};
        }
    }
    # print STDERR "Mapped design hash is ".Dumper(%mapped_design);
    return \%mapped_design;
}

sub get_data {
    my $c = shift;
    my $schema = shift;
    my $data_type = shift;
    my $data_level = shift;
    my $id = shift;
    my $num_trials = 1;
    my $design;

    # print STDERR "starting to get data,level is $data_level and type is $data_type\n";
    # use data level as well as type to determine and enact correct retrieval

    if ($data_level eq "list") {
        my $list_data = SGN::Controller::AJAX::List->retrieve_list($c, $id);
        my @list_items = map { $_->[1] } $list_data;
    }
    elsif ($data_level eq "plate") {
        $design = get_trial_design($c, $schema, $id, 'plate');
    }
    elsif ($data_level eq "plots") {
        if ($data_type =~ m/Field Trials/) {
            $design = get_trial_design($c, $schema, $id, 'plots');
        }
        elsif ($data_type =~ m/List/) {
            my $list_ids = convert_stock_list($c, $schema, $id);
            my ($trial_id, $num_trials) = get_trial_from_stock_list($c, $schema, $list_ids);
            $design = get_trial_design($c, $schema, $trial_id, 'plots');
            $design = filter_by_list_items($design, $list_ids);
        }
    }
    elsif ($data_level eq "plants") {
        if ($data_type =~ m/Field Trials/) {
            $design = get_trial_design($c, $schema, $id, 'plants');
            # print STDERR "Design is ".Dumper($design);
        }
        elsif ($data_type =~ m/List/) {
            my $list_ids = convert_stock_list($c, $schema, $id);
            my ($trial_id, $num_trials) = get_trial_from_stock_list($c, $schema, $list_ids);
            $design = get_trial_design($c, $schema, $trial_id, 'plants');
            $design = filter_by_list_items($design, $list_ids);
        }
    }
    elsif ($data_level eq "subplots") {
        if ($data_type =~ m/Field Trials/) {
            $design = get_trial_design($c, $schema, $id, 'subplots');
        }
        elsif ($data_type =~ m/List/) {
            my $list_ids = convert_stock_list($c, $schema, $id);
            my ($trial_id, $num_trials) = get_trial_from_stock_list($c, $schema, $list_ids);
            $design = get_trial_design($c, $schema, $trial_id, 'subplots');
            $design = filter_by_list_items($design, $list_ids);
        }
    }
    elsif ($data_level eq "tissue_samples") {
        if ($data_type =~ m/Field Trials/) {
            $design = get_trial_design($c, $schema, $id, 'field_trial_tissue_samples');
        }
        elsif ($data_type =~ m/List/) {
            my $list_ids = convert_stock_list($c, $schema, $id);
            my ($trial_id, $num_trials) = get_trial_from_stock_list($c, $schema, $list_ids);
            $design = get_trial_design($c, $schema, $trial_id, 'field_trial_tissue_samples');
            $design = filter_by_list_items($design, $list_ids);
        }
    }
    return $num_trials, $design;
}

# sub arraystostrings {
#     my $hash = shift;
#
#     print STDERR "Design type is ".ref($hash)." and content is ".Dumper($hash);
#     while (my ($key, $val) = each %$hash){
#         while (my ($prop, $value) = each %$val){
#             if (ref $value eq 'ARRAY'){
#                 $hash->{$key}->{$prop} = join ',', @$value;
#             }
#         }
#     }
#     return $hash;
# }


#########
1;
#########
