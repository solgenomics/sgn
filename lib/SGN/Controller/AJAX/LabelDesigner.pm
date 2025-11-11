package SGN::Controller::AJAX::LabelDesigner;

use Moose;
use CXGN::Stock;
use CXGN::List;
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
use SGN::Model::Cvterm;
use Sort::Naturally;

BEGIN { extends 'Catalyst::Controller::REST' }

#
# DEFINE ADDITIONAL LABEL DATA FOR LIST ITEMS HERE
# This info is used to provide additional properties for list items of
# specific types to the label designer.
# - The first-level hash key defines the list type
# - The second-level hash key defines the propery name (displayed in the label designer)
#   NOTE: Each list type needs to define (as '_transform') the list transform plugin name used to convert the list item names to database ids
# - The value of the second-level hash is a subroutine that calculates the
#   property value(s) for the specified list item(s)
#   It accepts the following arguments:
#       - $c = catalyst context
#       - $schema = Bio::Chado::Schema
#       - $dbh = DB Handle
#       - $list_id = the id of the List
#       - $list_item_ids = arrayref of list item ids
#       - $list_item_names = arrayref of list item names
#       - $list_item_db_ids = arrayref of original db ids of list items (stock ids, project ids, etc)
#   and returns a hashref of property values (key = list item id, value = property value)
#
my %ADDITIONAL_LIST_DATA = (

    'accessions' => {

        '_transform' => 'stocks_2_stock_ids',

        'accession id' => sub {
            my ($c, $schema, $dbh, $list_id, $list_item_ids, $list_item_names, $list_item_db_ids) = @_;
            my %values;
            for my $index (0 .. $#$list_item_ids ) {
                $values{$list_item_ids->[$index]} = $list_item_db_ids->[$index];
            }
            return \%values;
        },

        'accession pedigree' => sub {
            my ($c, $schema, $dbh, $list_id, $list_item_ids, $list_item_names, $list_item_db_ids) = @_;
            my %values;
            my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "accession", "stock_type")->cvterm_id();
            my $mother_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'female_parent', 'stock_relationship')->cvterm_id();
            my $father_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'male_parent', 'stock_relationship')->cvterm_id();

            foreach my $stock_id ( @$list_item_db_ids) {

                # Get the pedigree of the stock
                my $prs = $schema->resultset("Stock::StockRelationship")->search([
                    {
                        'me.object_id' => $stock_id,
                        'me.type_id' => $father_type_id,
                        'subject.type_id'=> $accession_type_id
                    },
                    {
                        'me.object_id' => $stock_id,
                        'me.type_id' => $mother_type_id,
                        'subject.type_id'=> $accession_type_id
                    }
                ], {
                    'join' => 'subject',
                    '+select' => ['subject.uniquename'],
                    '+as' => ['subject_uniquename']
                });

                # Retrieve the names of the parents
                my $parents = {};
                while ( my $p = $prs->next() ) {
                    if ( $p->type_id == $mother_type_id ) {
                        $parents->{'mother'} = $p->get_column('subject_uniquename');
                    }
                    else {
                        $parents->{'father'} = $p->get_column('subject_uniquename');
                    }
                }

                # Build pedigree string
                my $pedigree = 'NA/NA';
                if ( $parents->{'mother'} && $parents->{'father'} ) {
                    $pedigree = $parents->{'mother'} . '/' . $parents->{'father'};
                }

                # Add pedigree to return hash
                for my $index (0 .. $#$list_item_db_ids ) {
                    if ( $list_item_db_ids->[$index] eq $stock_id ) {
                        $values{$list_item_ids->[$index]} = $pedigree;
                    }
                }
            }

            return \%values;
        },

        'accession synonyms' => sub {
            my ($c, $schema, $dbh, $list_id, $list_item_ids, $list_item_names, $list_item_db_ids) = @_;
            my %values;
            my $type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stock_synonym', 'stock_property')->cvterm_id();

            my $rs = $schema->resultset("Stock::Stockprop")->search({
                'me.stock_id' => { in => $list_item_db_ids },
                'me.type_id' => $type_id
            });
            while ( my $row = $rs->next() ) {
                my $accession_id = $row->stock_id();
                my $synonym = $row->value();
                for my $index (0 .. $#$list_item_db_ids ) {
                    if ( $list_item_db_ids->[$index] eq $accession_id ) {
                        my $id = $list_item_ids->[$index];
                        $values{$id} = $values{$id} ? $values{$id} . ", " . $synonym : $synonym;
                    }
                }
            }

            return \%values;
        }

    },

    'seedlots' => {

        '_transform' => 'stocks_2_stock_ids',

        'seedlot id' => sub {
            my ($c, $schema, $dbh, $list_id, $list_item_ids, $list_item_names, $list_item_db_ids) = @_;
            my %values;
            for my $index (0 .. $#$list_item_ids ) {
                $values{$list_item_ids->[$index]} = $list_item_db_ids->[$index];
            }
            return \%values;
        },

        'seedlot contents' => sub {
            my ($c, $schema, $dbh, $list_id, $list_item_ids, $list_item_names, $list_item_db_ids) = @_;
            my %values;
            my $type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "collection_of", "stock_relationship")->cvterm_id();
            my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "accession", "stock_type")->cvterm_id();
            my $cross_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "cross", "stock_type")->cvterm_id();

            my $rs = $schema->resultset("Stock::StockRelationship")->search({
                'me.object_id' => { in => $list_item_db_ids },
                'me.type_id' => $type_id,
                'subject.type_id' => { in => [$accession_type_id, $cross_type_id] }
            }, {
                'join' => 'subject',
                '+select' => ['subject.uniquename'],
                '+as' => ['subject_uniquename']
            });
            while ( my $row = $rs->next() ) {
                my $seedlot_id = $row->object_id();
                my $accession_name = $row->get_column('subject_uniquename');
                for my $index (0 .. $#$list_item_db_ids ) {
                    if ( $list_item_db_ids->[$index] eq $seedlot_id ) {
                        $values{$list_item_ids->[$index]} = $accession_name;
                    }
                }
            }

            return \%values;
        },

        'seedlot contents pedigree' => sub {
            my ($c, $schema, $dbh, $list_id, $list_item_ids, $list_item_names, $list_item_db_ids) = @_;
            my %values;
            my $type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "collection_of", "stock_relationship")->cvterm_id();
            my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "accession", "stock_type")->cvterm_id();
            my $mother_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'female_parent', 'stock_relationship')->cvterm_id();
            my $father_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'male_parent', 'stock_relationship')->cvterm_id();
            my $cross_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "cross", "stock_type")->cvterm_id();

            # Get the stock ids of the seedlot contents
            my $rs = $schema->resultset("Stock::StockRelationship")->search({
                'me.object_id' => { in => $list_item_db_ids },
                'me.type_id' => $type_id,
                'subject.type_id' => { in => [$accession_type_id, $cross_type_id] }
            }, {
                'join' => 'subject',
                '+select' => ['subject.uniquename', 'subject.stock_id'],
                '+as' => ['subject_uniquename', 'subject_stockid']
            });
            while ( my $row = $rs->next() ) {
                my $seedlot_id = $row->object_id();
                my $stock_id = $row->get_column('subject_stockid');

                # Get the pedigree of the contents
                my $prs = $schema->resultset("Stock::StockRelationship")->search([
                    {
                        'me.object_id' => $stock_id,
                        'me.type_id' => $father_type_id,
                        'subject.type_id'=> $accession_type_id
                    },
                    {
                        'me.object_id' => $stock_id,
                        'me.type_id' => $mother_type_id,
                        'subject.type_id'=> $accession_type_id
                    }
                ], {
                    'join' => 'subject',
                    '+select' => ['subject.uniquename'],
                    '+as' => ['subject_uniquename']
                });

                # Retrieve the names of the parents
                my $parents = {};
                while ( my $p = $prs->next() ) {
                    if ( $p->type_id == $mother_type_id ) {
                        $parents->{'mother'} = $p->get_column('subject_uniquename');
                    }
                    else {
                        $parents->{'father'} = $p->get_column('subject_uniquename');
                    }
                }

                # Build pedigree string
                my $pedigree = 'NA/NA';
                if ( $parents->{'mother'} && $parents->{'father'} ) {
                    $pedigree = $parents->{'mother'} . '/' . $parents->{'father'};
                }

                # Add pedigree to return hash
                for my $index (0 .. $#$list_item_db_ids ) {
                    if ( $list_item_db_ids->[$index] eq $seedlot_id ) {
                        $values{$list_item_ids->[$index]} = $pedigree;
                    }
                }
            }

            return \%values;
        },

        'seedlot box' => sub {
            my ($c, $schema, $dbh, $list_id, $list_item_ids, $list_item_names, $list_item_db_ids) = @_;
            my %values;
            my $type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'location_code', 'stock_property')->cvterm_id();

            my $rs = $schema->resultset("Stock::Stockprop")->search({
                'me.stock_id' => { in => $list_item_db_ids },
                'me.type_id' => $type_id
            });
            while ( my $row = $rs->next() ) {
                my $seedlot_id = $row->stock_id();
                my $box = $row->value();
                for my $index (0 .. $#$list_item_db_ids ) {
                    if ( $list_item_db_ids->[$index] eq $seedlot_id ) {
                        $values{$list_item_ids->[$index]} = $box;
                    }
                }
            }

            return \%values;
        }

    }

);

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

        # Get additional list data for just the longest item
        if ( $data_type eq 'Lists' ) {
            my %longest_additional_list_data;
            my $additional_list_data = get_additional_list_data($c, $source_id);
            if ( $additional_list_data ) {
                foreach my $key ( keys(%$additional_list_data) ) {
                    my $fields = $additional_list_data->{$key};
                    if ( (ref($fields) eq "HASH") && (keys(%$fields) > 0) ) {
                        foreach my $field_name ( keys(%$fields) ) {
                            my $field_value = $fields->{$field_name};
                            if (exists $longest_additional_list_data{$field_name} ) {
                                if ( length($field_value) > length($longest_additional_list_data{$field_name}) ) {
                                    $longest_additional_list_data{$field_name} = $field_value;
                                }
                            }
                            else {
                                $longest_additional_list_data{$field_name} = $field_value;
                            }
                        }
                    }
                }
            }
            %longest_hash = (%longest_hash, %longest_additional_list_data);
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
       # my $json = JSON->new;
       #my $design_params = $json->allow_nonref->utf8->relaxed->escape_slash->loose->allow_singlequote->allow_barekey->decode($design_json);
       my $design_params = decode_json($design_json);
       my $labels_to_download = $design_params->{'labels_to_download'} || undef;
       my $start_number = $design_params->{'start_number'} || undef;
       my $end_number = $design_params->{'end_number'} || undef;
       my $text_alignment = $design_params->{"text_alignment"} || "middle";

       if ($labels_to_download) {
           $start_number = $start_number || 1;
           $end_number = $labels_to_download;
       }

       if ($start_number) { $start_number--; } #zero index
       if ($end_number) { $end_number--; } #zero index

       my $conversion_factor = 2.83; # for converting from 8 dots per mmm to 2.83 per mm (72 per inch)

       my ($trial_num, $design) = get_data($c, $schema, $data_type, $data_level, $source_id, 1);

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
       my $sort_order_1 = $design_params->{'sort_order_1'};
       my $sort_order_2 = $design_params->{'sort_order_2'};
       my $sort_order_3 = $design_params->{'sort_order_3'};
       my @sorted_keys;

       # Sort by Field Layout
       if ( $sort_order_1 eq 'Trial Layout: Plot Order') {
            my $layout_order = $design_params->{'sort_order_layout_order'};
            my $layout_start = $design_params->{'sort_order_layout_start'};

            # Set the Trial IDs
            # - a single trial = the source id is the trial id
            # - a list of trials = the source id is the list id
            #       get the list contents and convert to database ids
            my @trial_ids;
            if ( $data_type eq 'Field Trials' ) {
                push(@trial_ids, $source_id);
            }
            elsif ( $data_type eq 'Lists' ) {
                my $list = CXGN::List->new({ dbh => $schema->storage->dbh(), list_id => $source_id });
                my $list_elements = $list->retrieve_elements_with_ids($source_id);
                my @trial_names = map { $_->[1] } @$list_elements;
                my $lt = CXGN::List::Transform->new();
                my $tr = $lt->transform($schema, "projects_2_project_ids", \@trial_names);
                @trial_ids = @{$tr->{transform}};
            }

            # Get the sorted plots, individually by trial
            # Add a _plot_order key to each plot in the label design
            foreach my $trial_id (@trial_ids) {
                my $results = CXGN::Trial->get_sorted_plots($schema, [$trial_id], $layout_order, $layout_start);
                if ( $results->{plots} ) {
                    foreach (@{$results->{plots}}) {
                        $design->{$_->{plot_name}}{_plot_order} = $_->{order};
                    }
                }
            }

            # Sort the label design elements by trial, plot order, plot number
            # (if the trial does not have a layout, it will default to sorting by plot number)
            @sorted_keys = sort {
                    ncmp($design->{$a}{trial_name}, $design->{$b}{trial_name}) ||
                    ncmp($design->{$a}{_plot_order}, $design->{$b}{_plot_order}) ||
                    ncmp($design->{$a}{plot_number}, $design->{$b}{plot_numer}) ||
                    ncmp($a, $b)
            } keys %design;
       }

       # Sort by designated data property(s)
       else {
            @sorted_keys = sort {
                    ncmp($design->{$a}{$sort_order_1}, $design->{$b}{$sort_order_1}) ||
                    ncmp($design->{$a}{$sort_order_2}, $design->{$b}{$sort_order_2}) ||
                    ncmp($design->{$a}{$sort_order_3}, $design->{$b}{$sort_order_3}) ||
                    ncmp($a, $b)
            } keys %design;
       }

       my $qrcode = Imager::QRCode->new(
           margin        => 0,
           version       => 0,
           level         => 'M',
           casesensitive => 1,
           lightcolor    => Imager::Color->new(255, 255, 255, 255), # add alpha channel
           darkcolor     => Imager::Color->new(0, 0, 0, 255), # add alpha channel
       );
       my ($png_location, $png_uri) = $c->tempfile( TEMPLATE => [ 'barcode', 'bc-XXXXX'], SUFFIX=>'.png');

       if ($download_type eq 'pdf') {

           print STDERR "Creating the PDF : ".localtime()."\n";
           my $pdf  = PDF::API2->new(-file => $FH);
           my $page = $pdf->page();
           my $text = $page->text();
           my $gfx = $page->gfx();
           $page->mediabox($design_params->{'page_width'}, $design_params->{'page_height'});

           # loop through design hash, sorting via specified field or default
           foreach my $key (@sorted_keys) {
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
                           # print STDERR "Element Dumper\n" . Dumper($element);
                           my %element = %{$element};
                           my $elementx = $label_x + ( $element{'x'} / $conversion_factor );
                           my $elementy = $label_y - ( $element{'y'} / $conversion_factor );

                           my $filled_value = $element{'value'};
                           $filled_value =~ s/\{(.*?)\}/process_field($1,$key_number,\%design_info)/ge;

                           if ( $element{'type'} eq "Code128" || $element{'type'} eq "QRCode" ) {

                                if ( $element{'type'} eq "Code128" ) {
                                   # initialize barcode objs
                                   my $barcode_object = Barcode::Code128->new();
                                   my ($png_location, $png_uri) = $c->tempfile( TEMPLATE => [ 'barcode', 'bc-XXXXX'], SUFFIX=>'.png');
                                   open(my $PNG, ">", $png_location) or die "Can't write $png_location: $!\n";
                                   binmode($PNG);

                                   $barcode_object->option("scale", $element{'size'}, "font_align", "center", "padding", 5, "show_text", 0);
                                   $barcode_object->barcode($filled_value);
                                   my $barcode = $barcode_object->gd_image();
                                   print $PNG $barcode->png();
                                   close($PNG);

                                    my $image = $pdf->image_png($png_location);
                                    my $height = $element{'height'} / $conversion_factor ; # scale to 72 pts per inch
                                    my $width = $element{'width'} / $conversion_factor ; # scale to 72 pts per inch
                                    my $elementy = $elementy - ($height/2); # adjust for img position sarting at bottom
                                    my $elementx = $elementx - ($width/2);
                                    #print STDERR 'adding Code 128 params $image, $elementx, $elementy, $width, $height with: '."$image, $elementx, $elementy, $width, $height\n";
                                    $gfx->image($image, $elementx, $elementy, $width, $height);

                              } else { #QRCode

                                  my $barcode = $qrcode->plot( $filled_value );
                                  my $barcode_file = $barcode->write(file => $png_location);
                                  system("convert $png_location -depth 8 $png_location"); # convert to 8 bit encoding. Won't work with default 16 bit encoding.

                                   my $image = $pdf->image_png($png_location);
                                   my $height = $element{'height'} / $conversion_factor ; # scale to 72 pts per inch
                                   my $width = $element{'width'} / $conversion_factor ; # scale to 72 pts per inch
                                   my $elementy = $elementy - ($height/2); # adjust for img position sarting at bottom
                                   my $elementx = $elementx - ($width/2);
                                   $gfx->image($image, $elementx, $elementy, $width, $height);

                              }
                           }
                           else { #Text

                                my $font = $pdf->corefont($element{'font'});
                                my $adjusted_size = $element{'size'} / $conversion_factor;
                                my $height = $element{'height'} / $conversion_factor;
                                my $line_spacing = $adjusted_size * 1.2; # padding between lines

                                my @lines = split(/\n/, $filled_value); # Split multiline text

                                # Adjust starting y-position to center the block vertically
                                my $total_text_height = scalar(@lines) * $line_spacing;
                                my $start_y = $elementy; 

                                foreach my $line (@lines) {
                                    $text->font($font, $adjusted_size);
                                    $text->translate($elementx, $start_y);
                                    if ($text_alignment eq "middle") {
                                        $text->text_center($filled_value);
                                    } elsif ($text_alignment eq "left") {
                                        $text->text($filled_value);
                                    }
                                    $start_y -= $line_spacing;
                                }
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
           foreach my $key ( @sorted_keys ) {

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

sub convert_project_list {
    my $c = shift;
    my $schema = shift;
    my $list_id = shift;
    my $list_data = SGN::Controller::AJAX::List->retrieve_list($c, $list_id);
    my @list_items = map { $_->[1] } @$list_data;
    my $t = CXGN::List::Transform->new();
    my $proj_t = $t->can_transform("projects", "project_ids");
    my $id_hash = $t->transform($schema, $proj_t, \@list_items);
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
    my @all_trial_ids = keys %trials;
    #print STDERR "Number of linked trials is $num_trials\n";
    return \@all_trial_ids, $num_trials;
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
    my $trial_ids = shift;
    my $type = shift;
    my %selected_columns = (
        plate => {genotyping_project_name=>1,genotyping_facility=>1,trial_name=>1,acquisition_date=>1,exported_tissue_sample_name=>1,tissue_sample_name=>1,well_A01=>1,row_number=>1,col_number=>1,source_observation_unit_name=>1,accession_name=>1,synonyms=>0,accession_id=>1,pedigree=>1,dna_person=>1,notes=>1,tissue_type=>1,extraction=>1,concentration=>1,volume=>1,is_blank=>1,year=>1,location_name=>1},
        plots => {plot_name=>1,plot_id=>1,accession_name=>1,synonyms=>0,accession_id=>1,plot_number=>1,block_number=>1,is_a_control=>1,rep_number=>1,range_number=>1,row_number=>1,col_number=>1,seedlot_name=>1,seed_transaction_operator=>1,num_seed_per_plot=>1,pedigree=>1,location_name=>1,trial_name=>1,year=>1,tier=>1,plot_geo_json=>1},
        plants => {plant_name=>1,plant_id=>1,subplot_name=>1,subplot_id=>1,plot_name=>1,plot_id=>1,accession_name=>1,synonyms=>0,accession_id=>1,plot_number=>1,block_number=>1,is_a_control=>1,range_number=>1,rep_number=>1,row_number=>1,col_number=>1,seedlot_name=>1,seed_transaction_operator=>1,num_seed_per_plot=>1,subplot_number=>1,plant_number=>1,pedigree=>1,location_name=>1,trial_name=>1,year=>1,tier=>1,plot_geo_json=>1},
        subplots => {subplot_name=>1,subplot_id=>1,plot_name=>1,plot_id=>1,accession_name=>1,synonyms=>0,accession_id=>1,plot_number=>1,block_number=>1,is_a_control=>1,rep_number=>1,range_number=>1,row_number=>1,col_number=>1,seedlot_name=>1,seed_transaction_operator=>1,num_seed_per_plot=>1,subplot_number=>1,pedigree=>1,location_name=>1,trial_name=>1,year=>1,tier=>1,plot_geo_json=>1},
        field_trial_tissue_samples => {tissue_sample_name=>1,tissue_sample_id=>1,plant_name=>1,plant_id=>1,subplot_name=>1,subplot_id=>1,plot_name=>1,plot_id=>1,accession_name=>1,synonyms=>0,accession_id=>1,plot_number=>1,block_number=>1,is_a_control=>1,range_number=>1,rep_number=>1,row_number=>1,col_number=>1,seedlot_name=>1,seed_transaction_operator=>1,num_seed_per_plot=>1,subplot_number=>1,plant_number=>1,tissue_sample_number=>1,pedigree=>1,location_name=>1,trial_name=>1,year=>1,tier=>1,plot_geo_json=>1}
    );
    my %unique_identifier = (
        plate => 'tissue_sample_name',
        plots => 'plot_name',
        plants => 'plant_name',
        subplots => 'subplot_name',
        field_trial_tissue_samples => 'tissue_sample_name',
    );

    my %mapped_design;
    foreach my $trial_id (@$trial_ids) {
        my $trial = CXGN::Trial->new({ bcs_schema => $schema, trial_id => $trial_id });
        my $trial_name = $schema->resultset("Project::Project")->search({ project_id => $trial_id })->first->name();
        my $entry_numbers = $trial->get_entry_numbers();

        my $trial_management_regime = $trial->get_management_regime();

        # my $treatments = $trial->get_treatments();
        # my @treatment_ids = map { $_->{trait_id} } @{$treatments};
        # print STDERR "treatment ids are @treatment_ids\n";
        my $trial_layout_download = CXGN::Trial::TrialLayoutDownload->new({
            schema => $schema,
            trial_id => $trial_id,
            data_level => $type,
            # treatment_ids => \@treatment_ids,
            selected_columns => $selected_columns{$type},
            selected_trait_ids => [],
            use_synonyms => 'false',
            include_measured => 'true'
        });
        my $layout = $trial_layout_download->get_layout_output();

        # map array of arrays into hash
        my @outer_array = @{$layout->{'output'}};
        my ($inner_array, @keys);
        for my $i (0 .. $#outer_array) {
            $inner_array = $outer_array[$i];
        # foreach my $inner_array (@{$outer_array}) {
            if (scalar @keys > 0) {
                my %detail_hash;
                @detail_hash{@keys} = @{$outer_array[$i]};

                $detail_hash{'brief_management_regime'} = _format_management_regime($trial_management_regime);
                $detail_hash{'full_management_regime'} = $trial_management_regime ? encode_json($trial_management_regime) : '';
                $detail_hash{'entry_number'} = $entry_numbers ? $entry_numbers->{$detail_hash{accession_id}} : undef;
                $mapped_design{$detail_hash{$unique_identifier{$type}}} = \%detail_hash;

            }
            else {
                @keys = @{$inner_array};
            }
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
    my $include_additional_list_data = shift;
    my $num_trials = 1;
    my $design;
    my $dbh = $schema->storage->dbh();

    # print STDERR "starting to get data,level is $data_level and type is $data_type\n";
    # use data level as well as type to determine and enact correct retrieval

    if ($data_level =~ /batch-/) {  # handle batches of identifiers
        my $match = substr($data_level, 6);
        my $list_data = SGN::Controller::AJAX::List->retrieve_list($c, $id);
        my @list_data = @{$list_data};
        # my $json = JSON->new;
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
        my $additional_list_data = {};
        if ( $include_additional_list_data ) {
            $additional_list_data = get_additional_list_data($c, $id);
        }
        foreach my $item (@{$list_data}) {
            my $list_fields = { 'list_item_name' => $item->[1], 'list_item_id' => $item->[0] };
            my $additional_list_fields = $additional_list_data->{$item->[0]};
            $design->{$item->[0]} = { %$list_fields, $additional_list_fields ? %$additional_list_fields : () };
        }
    }
    elsif ($data_level eq "plate") {
        $design = get_trial_design($c, $schema, [$id], 'plate');
    }
    elsif ($data_level eq "plots") {
        if ($data_type =~ m/Field Trials/) {
            $design = get_trial_design($c, $schema, [$id], 'plots');
        }
        elsif ($data_type =~ m/List/) {
            my $list = CXGN::List->new({ dbh => $dbh, list_id => $id });
            my $list_type = $list->type();
            if ( $list_type eq "trials" ) {
                my $trial_ids = convert_project_list($c, $schema, $id);
                $design = get_trial_design($c, $schema, $trial_ids, 'plots');
            }
            elsif ( $list_type eq "plots" ) {
                my $plot_ids = convert_stock_list($c, $schema, $id);
                my $list_data = SGN::Controller::AJAX::List->retrieve_list($c, $id);
                my @list_items = map { $_->[1] } @$list_data;
                my ($trial_ids, $num_trials) = get_trial_from_stock_list($c, $schema, $plot_ids);
                $design = get_trial_design($c, $schema, $trial_ids, 'plots');
                $design = filter_by_list_items($design, \@list_items, 'plot_name');
            }
        }
    }
    elsif ($data_level eq "plants") {
        if ($data_type =~ m/Field Trials/) {
            $design = get_trial_design($c, $schema, [$id], 'plants');
        }
        elsif ($data_type =~ m/List/) {
            my $list_ids = convert_stock_list($c, $schema, $id);
            my $list_data = SGN::Controller::AJAX::List->retrieve_list($c, $id);
            my @list_items = map { $_->[1] } @$list_data;
            my ($trial_ids, $num_trials) = get_trial_from_stock_list($c, $schema, $list_ids);
            $design = get_trial_design($c, $schema, $trial_ids, 'plants');
            $design = filter_by_list_items($design, \@list_items, 'plant_name');
        }
    }
    elsif ($data_level eq "subplots") {
        if ($data_type =~ m/Field Trials/) {
            $design = get_trial_design($c, $schema, [$id], 'subplots');
        }
        elsif ($data_type =~ m/List/) {
            my $list_ids = convert_stock_list($c, $schema, $id);
            my $list_data = SGN::Controller::AJAX::List->retrieve_list($c, $id);
            my @list_items = map { $_->[1] } @$list_data;
            my ($trial_ids, $num_trials) = get_trial_from_stock_list($c, $schema, $list_ids);
            $design = get_trial_design($c, $schema, $trial_ids, 'subplots');
            $design = filter_by_list_items($design, \@list_items, 'subplot_name');
        }
    }
    elsif ($data_level eq "tissue_samples") {
        if ($data_type =~ m/Field Trials/) {
            $design = get_trial_design($c, $schema, [$id], 'field_trial_tissue_samples');
        }
        elsif ($data_type =~ m/List/) {
            my $list_ids = convert_stock_list($c, $schema, $id);
            my $list_data = SGN::Controller::AJAX::List->retrieve_list($c, $id);
            my @list_items = map { $_->[1] } @$list_data;
            my ($trial_ids, $num_trials) = get_trial_from_stock_list($c, $schema, $list_ids);
            $design = get_trial_design($c, $schema, $trial_ids, 'field_trial_tissue_samples');
            $design = filter_by_list_items($design, \@list_items, 'tissue_sample_name');
        }
    }
    elsif ($data_level eq "crosses") {
        my %cross_info;
        if ($data_type =~ m/Crossing Experiments/) {
            my $project = CXGN::Cross->new({ schema => $schema, trial_id => $id});
            my $result = $project->get_crosses_and_details_in_crossingtrial();
            my @cross_data = @$result;
            foreach my $cross (@cross_data){
                my $cross_combination;
                my $male_parent_name;
                my $male_parent_id;

                if (!$cross->[2] || $cross->[2] eq ''){
                    $cross_combination = 'No cross combination available';
                } else {
                    $cross_combination = $cross->[2];
                }

                if (!$cross->[8] || $cross->[8] eq ''){
                    $male_parent_name = 'No male parent available';
                } else {
                    $male_parent_name = $cross->[8];
                }

                if (!$cross->[7] || $cross->[7] eq ''){
                    $male_parent_id = 'No male parent available';
                } else {
                    $male_parent_id = $cross->[7];
                }

                $cross_info{$cross->[0]} = {
                    'cross_name' => $cross->[1],
                    'cross_id' => $cross->[0],
                    'cross_combination' => $cross_combination,
                    'cross_type' => $cross->[3],
                    'female_parent_name' => $cross->[5],
                    'female_parent_id' => $cross->[4],
                    'male_parent_name' => $male_parent_name,
                    'male_parent_id' => $male_parent_id
                };
            }

        } elsif ($data_type =~ m/List/) {
            my $cross_list_ids = convert_stock_list($c, $schema, $id);
            foreach my $cross_id (@$cross_list_ids) {
                my $cross = CXGN::Cross->new({ schema => $schema, cross_stock_id => $cross_id});
                my $info = $cross->cross_parents();
#                print STDERR "INFO =".Dumper($info)."\n";
                my $cross_combination;
                my $male_parent_name;
                my $male_parent_id;

                if (!$info->[0]->[13] || $info->[0]->[13] eq ''){
                    $cross_combination = 'No cross combination available';
                } else {
                    $cross_combination = $info->[0]->[13];
                }

                if (!$info->[0]->[7] || $info->[0]->[7] eq ''){
                    $male_parent_name = 'No male parent available';
                } else {
                    $male_parent_name = $info->[0]->[7];
                }

                if (!$info->[0]->[6] || $info->[0]->[6] eq ''){
                    $male_parent_id = 'No male parent available';
                } else {
                    $male_parent_id = $info->[0]->[6];
                }

                $cross_info{$cross->cross_stock_id()} = {
                    'cross_name' => $cross->cross_name(),
                    'cross_id' => $cross->cross_stock_id(),
                    'cross_combination' => $cross_combination,
                    'cross_type' => $info->[0]->[12],
                    'female_parent_name' => $info->[0]->[1],
                    'female_parent_id' => $info->[0]->[0],
                    'male_parent_name' => $male_parent_name,
                    'male_parent_id' => $male_parent_id
                };
            }
        }

        $design = \%cross_info;
    }

#    print STDERR "Design is ".Dumper($design)."\n";
    return $num_trials, $design;
}

sub get_additional_list_data {
    my $c = shift;
    my $list_id = shift;
    my $list_item_id = shift;
    my $list_item_name = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    my $dbh = $schema->storage->dbh();

    if ( !$list_id || $list_id eq '' ) {
        die "List ID not provided!";
    }

    my $list;
    my $list_type;
    my $list_type_data_def;
    eval {
        $list = CXGN::List->new({ dbh => $dbh, list_id => $list_id });
        $list_type = $list->type();
        $list_type_data_def = $ADDITIONAL_LIST_DATA{$list_type};
    };
    if ( $@ || !$list ) {
        die "List not found!"
    }

    # No additional list data defined for list type...
    if ( !$list_type_data_def ) {
        return {};
    }

    # Set arrays of List Item IDs and Names
    my @list_item_ids;
    my @list_item_names;
    if ( $list_item_id && $list_item_name ) {
        push(@list_item_ids, $list_item_id);
        push(@list_item_names, $list_item_name);
    }
    else {
        my $list_elements = $list->retrieve_elements_with_ids($list_id);
        @list_item_names = map { $_->[1] } @$list_elements;
        @list_item_ids = map { $_->[0] } @$list_elements;
    }

    # Set original DB IDs (stock ids, project ids, etc) of List Items
    my @list_item_db_ids;
    my $transform = $list_type_data_def->{'_transform'};
    if ( $transform ) {
        my $lt = CXGN::List::Transform->new();
        my $tr = $lt->transform($schema, $transform, \@list_item_names);
        @list_item_db_ids = @{$tr->{transform}};
    }

    # Calculate list properties
    # - organized by property name, list item id
    my %fields_by_prop;
    while ( my ($name, $calc) = each (%$list_type_data_def) ) {
        if ( $name =~ /^(?!_).*/ ) {
            $fields_by_prop{$name} = &$calc($c, $schema, $dbh, $list_id, \@list_item_ids, \@list_item_names, \@list_item_db_ids);
        }
    }

    # Reorganize list properties
    # - organized by list item id, property name
    my %fields;
    foreach my $list_item_id (@list_item_ids) {
        foreach my $name (keys %fields_by_prop) {
            $fields{$list_item_id}{$name} = $fields_by_prop{$name}{$list_item_id};
        }
    }

    return \%fields;
}

sub _format_management_regime { #management regime is a list of hashes. This condenses it because it would be too large otherwise
    my $management_regime = shift;

    if (!$management_regime || $management_regime eq "") {
        return "";
    }

    my @factors;

    foreach my $factor (@{$management_regime}) {
        my $factor_text = "";
        $factor_text .= "Mgmt factor type: ".$factor->{type}."\n";
        $factor_text .= "Description: ".$factor->{description}."\n";
        $factor_text .= "Schedule: ".$factor->{schedule}."\n";
        push @factors, $factor_text;
    }
    return join("\n", @factors);
}

#########
1;
#########
