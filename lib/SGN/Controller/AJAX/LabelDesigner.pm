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
use CXGN::Cross;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
   );

   sub retrieve_longest_fields :Path('/tools/label_designer/retrieve_longest_fields') {
        my $self = shift;
        my $c = shift;
        my $schema = $c->dbic_schema('Bio::Chado::Schema');
        my $data_type = $c->req->param("data_type");
        my $source_id = $c->req->param("source_id");
        my $data_level = $c->req->param("data_level");
        my %longest_hash;
        #print STDERR "Data type is $data_type and id is $source_id and data level is $data_level\n";

        my ($trial_num, $design) = get_data($c, $schema, $data_type, $data_level, $source_id);

       if ($trial_num > 1) {
           $c->stash->{rest} = { error => "The selected list contains plots, plants, subplots or tissues from more than one trial. This is not supported. Please select a different data source." };
           return;
       }

       my %design = %{$design};

       #delete any undefined fields
       my $num_units = scalar(keys %design);
       foreach my $key (keys %design) {
           my %plot = %{$design{$key}};
           delete $design{$key}{$_} for grep { !defined $plot{$_} } keys %plot;
       }

       #get all fields in this trials design
       my $random_plot = $design{(keys %design)[rand keys %design]};
       my %reps;
       my @keys = keys %{$random_plot};

       foreach my $field (@keys) {

           # if rep_number, find unique options and return them
           if ($field eq 'rep_number') {
               print STDERR "Searching for unique rep numbers.\n";
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

        $c->stash->{rest} = {
            fields => \%longest_hash,
            reps => \%reps,
            num_units => $num_units
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
       # decode json
       my $json = new JSON;
       #my $design_params = $json->allow_nonref->utf8->relaxed->escape_slash->loose->allow_singlequote->allow_barekey->decode($design_json);
       my $design_params = decode_json($design_json);
       my $labels_to_download = $design_params->{'labels_to_download'} || undef;
       my $start_number = $design_params->{'start_number'} || undef;
       my $end_number = $design_params->{'end_number'} || undef;

       if ($labels_to_download) {
           $start_number = $start_number || 1;
           $end_number = $labels_to_download;
       }

       if ($start_number) { $start_number--; } #zero index
       if ($end_number) { $end_number--; } #zero index

       my $conversion_factor = 2.83; # for converting from 8 dots per mmm to 2.83 per mm (72 per inch)

       my ($trial_num, $design) = get_data($c, $schema, $data_type, $data_level, $source_id);

       my $label_params = $design_params->{'label_elements'};

       if ($trial_num > 1) {
           $c->stash->{rest} = { error => "The selected list contains plots from more than one trial. This is not supported. Please select a different data source." };
           return;
       }

       my %design = %{$design};
       if (!$design) {
           $c->stash->{rest} = { error => "$source_name is not linked to a valid field design. Can't create labels." };
           return;
       }

       # Create a blank PDF file
       my $dir = $c->tempfiles_subdir('labels');
       my $file_prefix = $source_name;
       $file_prefix =~ s/[^a-zA-Z0-9-_]//g;

       my ($FH, $filename) = $c->tempfile(TEMPLATE=>"labels/$file_prefix-XXXXX", SUFFIX=>".$download_type");

       # initialize loop variables
       my $col_num = $design_params->{'start_col'} || 1;
       my $row_num = $design_params->{'start_row'} || 1;
       my $key_number = 0;
       my $sort_order = $design_params->{'sort_order'};

       # initialize barcode objs
       my $barcode_object = Barcode::Code128->new();
       my ($png_location, $png_uri) = $c->tempfile( TEMPLATE => [ 'barcode', 'bc-XXXXX'], SUFFIX=>'.png');
       open(PNG, ">", $png_location) or die "Can't write $png_location: $!\n";

       my $qrcode = Imager::QRCode->new(
           margin        => 0,
           version       => 0,
           level         => 'M',
           casesensitive => 1,
           lightcolor    => Imager::Color->new(255, 255, 255),
           darkcolor     => Imager::Color->new(0, 0, 0),
       );
       my ($jpeg_location, $jpeg_uri) = $c->tempfile( TEMPLATE => [ 'barcode', 'bc-XXXXX'], SUFFIX=>'.jpg');

       if ($download_type eq 'pdf') {

           print STDERR "Creating the PDF : ".localtime()."\n";
           my $pdf  = PDF::API2->new(-file => $FH);
           my $page = $pdf->page();
           my $text = $page->text();
           my $gfx = $page->gfx();
           $page->mediabox($design_params->{'page_width'}, $design_params->{'page_height'});

           # loop through design hash, sorting via specified field or default
           foreach my $key ( sort { versioncmp( $design{$a}{$sort_order} , $design{$b}{$sort_order} ) or versioncmp($a, $b) } keys %design) {
               if ($start_number && ($key_number < $start_number)){
                   $key_number++;
                   next;
               }
               if ($end_number && ($key_number > $end_number)){
                   last;
               }

               my %design_info = %{$design{$key}};

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
                           $filled_value =~ s/\{(.*?)\}/process_field($1,$key_number,\%design_info)/ge;

                           if ( $element{'type'} eq "Code128" || $element{'type'} eq "QRCode" ) {

                                if ( $element{'type'} eq "Code128" ) {
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

                                  my $barcode = $qrcode->plot( $filled_value );
                                  my $barcode_file = $barcode->write(file => $jpeg_location);

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

           print STDERR "Saving the PDF : ".localtime()."\n";
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

               if ($start_number && ($key_number < $start_number)){
                   $key_number++;
                   next;
               }
               if ($end_number && ($key_number > $end_number)){
                   last;
               }

               my %design_info = %{$design{$key}};

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

    my $genotyping_experiment_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'genotyping_layout', 'experiment_type')->cvterm_id();
    my $field_experiment_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'field_layout', 'experiment_type')->cvterm_id();
    my $cross_experiment_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'cross_experiment', 'experiment_type')->cvterm_id();


    my $trial_rs = $schema->resultset("NaturalDiversity::NdExperimentStock")->search({
        stock_id => { -in => \@ids }
    })->search_related('nd_experiment', {'nd_experiment.type_id'=>[$field_experiment_cvterm_id, $genotyping_experiment_cvterm_id, $cross_experiment_cvterm_id]
    })->search_related('nd_experiment_projects');
    my %trials = ();
    while (my $row = $trial_rs->next()) {
        #print STDERR "Looking at id ".$row->project_id()."\n";
        my $id = $row->project_id();
        $trials{$id} = 1;
    }
    my $num_trials = scalar keys %trials;
    #print STDERR "Number of linked trials is $num_trials\n";
    my $trial_id = $trial_rs->first->project_id();
    return $trial_id, $num_trials;
}

sub filter_by_list_items {
    my $full_design = shift;
    my $stock_ids = shift;
    my $type = shift;
    my %full_design = %{$full_design};
    my @stock_ids = @{$stock_ids};
    my %plot_design;

    foreach my $i (0 .. $#stock_ids) {
        #print STDERR "Stock id is ".$stock_ids[$i]."\n";
        foreach my $key (keys %full_design) {
            if ($full_design{$key}->{$type} eq $stock_ids[$i]) {
                #print STDERR "Plot name is ".$full_design{$key}->{'plot_name'}."\n";
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
        plate => {genotyping_project_name=>1,genotyping_facility=>1,trial_name=>1,acquisition_date=>1,exported_tissue_sample_name=>1,tissue_sample_name=>1,well_A01=>1,row_number=>1,col_number=>1,source_observation_unit_name=>1,accession_name=>1,accession_id=>1,pedigree=>1,dna_person=>1,notes=>1,tissue_type=>1,extraction=>1,concentration=>1,volume=>1,is_blank=>1,year=>1,location_name=>1},
        plots => {plot_name=>1,plot_id=>1,accession_name=>1,accession_id=>1,plot_number=>1,block_number=>1,is_a_control=>1,rep_number=>1,range_number=>1,row_number=>1,col_number=>1,seedlot_name=>1,seed_transaction_operator=>1,num_seed_per_plot=>1,pedigree=>1,location_name=>1,trial_name=>1,year=>1,tier=>1,plot_geo_json=>1},
        plants => {plant_name=>1,plant_id=>1,subplot_name=>1,subplot_id=>1,plot_name=>1,plot_id=>1,accession_name=>1,accession_id=>1,plot_number=>1,block_number=>1,is_a_control=>1,range_number=>1,rep_number=>1,row_number=>1,col_number=>1,seedlot_name=>1,seed_transaction_operator=>1,num_seed_per_plot=>1,subplot_number=>1,plant_number=>1,pedigree=>1,location_name=>1,trial_name=>1,year=>1,tier=>1,plot_geo_json=>1},
        subplots => {subplot_name=>1,subplot_id=>1,plot_name=>1,plot_id=>1,accession_name=>1,accession_id=>1,plot_number=>1,block_number=>1,is_a_control=>1,rep_number=>1,range_number=>1,row_number=>1,col_number=>1,seedlot_name=>1,seed_transaction_operator=>1,num_seed_per_plot=>1,subplot_number=>1,pedigree=>1,location_name=>1,trial_name=>1,year=>1,tier=>1,plot_geo_json=>1},
        field_trial_tissue_samples => {tissue_sample_name=>1,tissue_sample_id=>1,plant_name=>1,plant_id=>1,subplot_name=>1,subplot_id=>1,plot_name=>1,plot_id=>1,accession_name=>1,accession_id=>1,plot_number=>1,block_number=>1,is_a_control=>1,range_number=>1,rep_number=>1,row_number=>1,col_number=>1,seedlot_name=>1,seed_transaction_operator=>1,num_seed_per_plot=>1,subplot_number=>1,plant_number=>1,tissue_sample_number=>1,pedigree=>1,location_name=>1,trial_name=>1,year=>1,tier=>1,plot_geo_json=>1}
    );
    my %unique_identifier = (
        plots => 'plot_id',
        plants => 'plant_id',
        subplots => 'subplot_id',
        field_trial_tissue_samples => 'tissue_sample_id',
    );

    my $trial = CXGN::Trial->new({ bcs_schema => $schema, trial_id => $trial_id });
    my $trial_name = $schema->resultset("Project::Project")->search({ project_id => $trial_id })->first->name();

    my $treatments = $trial->get_treatments();
    my @treatment_ids = map { $_->[0] } @{$treatments};
    # print STDERR "treatment ids are @treatment_ids\n";
    my $trial_layout_download = CXGN::Trial::TrialLayoutDownload->new({
        schema => $schema,
        trial_id => $trial_id,
        data_level => $type,
        treatment_project_ids => \@treatment_ids,
        selected_columns => $selected_columns{$type},
        selected_trait_ids => [],
        use_synonyms => 'false',
        include_measured => 'true'
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
            $mapped_design{$detail_hash{$unique_identifier{$type}}} = \%detail_hash;

        }
        else {
            @keys = @{$inner_array};
        }
    }
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

    if ($data_level =~ /batch-/) {  # handle batches of identifiers
        my $match = substr($data_level, 6);
        my $list_data = SGN::Controller::AJAX::List->retrieve_list($c, $id);
        my @list_data = @{$list_data};
        my $json = new JSON;
        #my $identifier_object = $json->allow_nonref->utf8->relaxed->escape_slash->loose->allow_singlequote->allow_barekey->decode($list_data[0][1]);
	my $identifier_object = decode_json($list_data[0][1]);
        my $records = $identifier_object->{'records'};
        foreach my $record (@{$records}) {
            my $next_number = $record->{'next_number'};
            if ($next_number eq $match) {
                my $generated_identifiers = $record->{'generated_identifiers'};
                foreach my $identifier (@{$generated_identifiers}) {
                    $design->{$identifier} = { 'identifier' => $identifier };
                }
            }
        }
    }
    if ($data_level eq "list") {
        my $list_data = SGN::Controller::AJAX::List->retrieve_list($c, $id);
        foreach my $item (@{$list_data}) {
            $design->{$item->[0]} = { 'list_item_name' => $item->[1], 'list_item_id' => $item->[0] };
        }
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
            $design = filter_by_list_items($design, $list_ids, 'plot_id');
        }
    }
    elsif ($data_level eq "plants") {
        if ($data_type =~ m/Field Trials/) {
            $design = get_trial_design($c, $schema, $id, 'plants');
        }
        elsif ($data_type =~ m/List/) {
            my $list_ids = convert_stock_list($c, $schema, $id);
            my ($trial_id, $num_trials) = get_trial_from_stock_list($c, $schema, $list_ids);
            $design = get_trial_design($c, $schema, $trial_id, 'plants');
            $design = filter_by_list_items($design, $list_ids, 'plant_id');
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
            $design = filter_by_list_items($design, $list_ids, 'subplot_id');
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
            $design = filter_by_list_items($design, $list_ids, 'tissue_sample_id');
        }
    }
    elsif ($data_level eq "crosses") {
        my $project;
        my $cross_list_ids;
        my %all_design;
        if ($data_type =~ m/Crossing Experiments/) {
            $project = CXGN::Cross->new({ schema => $schema, trial_id => $id});
        } elsif ($data_type =~ m/List/) {
            $cross_list_ids = convert_stock_list($c, $schema, $id);
            my ($crossing_experiment_id, $num_trials) = get_trial_from_stock_list($c, $schema, $cross_list_ids);
            $project = CXGN::Cross->new({ schema => $schema, trial_id => $crossing_experiment_id});
        }

        my $result = $project->get_crosses_and_details_in_crossingtrial();
        my @cross_data = @$result;
        foreach my $cross (@cross_data){
            my $cross_combination;
            my $male_parent_name;
            my $male_parent_id;

            if ($cross->[2] eq ''){
                $cross_combination = 'No cross combination available';
            } else {
                $cross_combination = $cross->[2];
            }

            if ($cross->[8] eq ''){
                $male_parent_name = 'No male parent available';
            } else {
                $male_parent_name = $cross->[8];
            }

            if ($cross->[7] eq ''){
                $male_parent_id = 'No male parent available';
            } else {
                $male_parent_id = $cross->[7];
            }

            $all_design{$cross->[0]} = {'cross_name' => $cross->[1],
                                      'cross_id' => $cross->[0],
                                      'cross_combination' => $cross_combination,
                                      'cross_type' => $cross->[3],
                                      'female_parent_name' => $cross->[5],
                                      'female_parent_id' => $cross->[4],
                                      'male_parent_name' => $male_parent_name,
                                      'male_parent_id' => $male_parent_id};
        }

        if ($data_type =~ m/List/) {
            my %filtered_hash = map { $_ => $all_design{$_} } @$cross_list_ids;
            $design = \%filtered_hash;
        } else {
            $design = \%all_design;
        }
    }

#    print STDERR "Design is ".Dumper($design)."\n";
    return $num_trials, $design;
}

#########
1;
#########
