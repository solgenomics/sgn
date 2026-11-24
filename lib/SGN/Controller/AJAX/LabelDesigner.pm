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
use Imager;
use Imager::Font;
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
use CXGN::BreederSearch;

BEGIN { extends 'Catalyst::Controller::REST' }

#
# DEFINE ADDITIONAL LABEL DATA FOR LIST ITEMS HERE
# This info is used to provide additional properties for list items of
# specific types to the label designer.
# - The first-level hash key defines the list type
# - The second-level hash key defines the property name (displayed in the label designer)
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
		elsif ( $parents->{'mother'}) {
		    $pedigree = $parents->{'mother'} .'/NA';
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
       my $download_type = $c->req->param("download_type") || '';
       my $data_type = $c->req->param("data_type");
       my $data_level = $c->req->param("data_level");
       my $source_id = $c->req->param("source_id");
       my $source_name = $c->req->param("source_name") // '';
       my $design_json = $c->req->param("design_json");

       if ($download_type ne 'pdf' && $download_type ne 'zpl') {
           $c->stash->{rest} = { error => "Unknown download type. Please choose a PDF or a Zebra printer file." };
           return;
       }

       # Catalyst has usually decoded the parameter to characters already;
       # decode_json would die on any non-ASCII text in the design then
       my $design_params = eval {
           utf8::is_utf8($design_json) ? JSON->new->decode($design_json) : decode_json($design_json);
       };
       if (ref($design_params) ne 'HASH') {
           $c->stash->{rest} = { error => "The label design could not be read. Please reload the page and try again." };
           return;
       }
       my $text_alignment = $design_params->{"text_alignment"} || "middle";

       my ($settings_error, $first_label, $last_label) = _check_label_settings($design_params, $download_type);
       if ($settings_error) {
           $c->stash->{rest} = { error => $settings_error };
           return;
       }

       my $conversion_factor = 2.83; # for converting from 8 dots per mmm to 2.83 per mm (72 per inch)

       my ($trial_num, $design) = get_data($c, $schema, $data_type, $data_level, $source_id, 1);

       my $label_params = $design_params->{'label_elements'} || [];

       if ($trial_num && $trial_num > 1) {
           $c->stash->{rest} = { error => "The selected list contains plots from more than one trial. This is not supported. Please select a different data source." };
           return;
       }

       if (ref($design) ne 'HASH') {
           $c->stash->{rest} = { error => "$source_name is not linked to a valid field design. Can't create labels." };
           return;
       }
       if (!%$design) {
           $c->stash->{rest} = { error => "$source_name has no items to make labels from." };
           return;
       }

       my %design = %{$design};

       # initialize loop variables
       my $col_num = $design_params->{'start_col'} || 1;
       my $row_num = $design_params->{'start_row'} || 1;
       my $sort_order_1 = $design_params->{'sort_order_1'} // '';
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
            elsif ( $data_type eq 'Lists' || $data_type eq 'Public Lists' ) {
                my $list = CXGN::List->new({ dbh => $schema->storage->dbh(), list_id => $source_id });
                my $list_type = $list->type();
                my $list_elements = $list->retrieve_elements_with_ids($source_id);

                if ( $list_type eq 'trials' ) {
                    my @trial_names = map { $_->[1] } @$list_elements;
                    my $lt = CXGN::List::Transform->new();
                    my $tr = $lt->transform($schema, "projects_2_project_ids", \@trial_names);
                    @trial_ids = @{$tr->{transform}};
                }
                elsif ( $list_type eq 'plots' ) {
                    my @plot_names = map { $_->[1] } @$list_elements;
                    my $lt = CXGN::List::Transform->new();
                    my $tr = $lt->transform($schema, "stocks_2_stock_ids", \@plot_names);
                    my @plot_ids = @{$tr->{transform}};

                    my $bs = CXGN::BreederSearch->new({ dbh => $schema->storage->dbh() });
                    my $criteria_list = [ 'plots', 'trials' ];
                    my $dataref = {
                        'trials' => {
                            'plots' => join(', ', map { qq\'$_'\ } @plot_ids)
                        }
                    };
                    my $queryref = {
                        'trials' => {
                            'plots' => 0
                        }
                    };
                    my $results_ref = $bs->metadata_query($criteria_list, $dataref, $queryref);
                    @trial_ids = map { $_->[0] } @{$results_ref->{results}};
                }
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
                    ncmp($design->{$a}{plot_number}, $design->{$b}{plot_number}) ||
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

       # "Limit by Rep" is applied before the range, so Start/End/Total count
       # only the labels of the selected rep, and {Number} does not skip.
       my $plot_filter = $design_params->{'plot_filter'};
       my $filter_by_rep = defined($plot_filter) && $plot_filter ne '' && $plot_filter ne 'all';
       my @selected_keys = $filter_by_rep
           ? grep { defined($design{$_}{'rep_number'}) && $design{$_}{'rep_number'} eq $plot_filter } @sorted_keys
           : @sorted_keys;
       my $selection_name = $filter_by_rep ? "rep $plot_filter of $source_name" : $source_name;

       if (!@selected_keys) {
           $c->stash->{rest} = { error => "There are no labels to print for $selection_name." };
           return;
       }
       if ($first_label > @selected_keys) {
           $c->stash->{rest} = { error => "Start Number $first_label is past the last label: there are ".scalar(@selected_keys)." labels for $selection_name." };
           return;
       }
       my $last_index = (defined($last_label) && $last_label < @selected_keys) ? $last_label - 1 : $#selected_keys;
       # each entry: [ design key, position in the selected labels (0 = first) ]
       my @labels_to_print = map { [ $selected_keys[$_], $_ ] } ($first_label - 1) .. $last_index;

       my $copies_per_plot = $design_params->{'copies_per_plot'};

       # what could not be printed as designed, grouped by element and reason
       my %problems;
       my @problem_order;
       my $note_problem = sub {
           my ($what, $reason, $design_info, $key) = @_;
           my $group = "$what\t$reason";
           if (!$problems{$group}) {
               $problems{$group} = { what => $what, reason => $reason, labels => [] };
               push @problem_order, $group;
           }
           push @{$problems{$group}{labels}}, _label_name($design_info, $key);
       };
       my $note_barcode_problem = sub {
           my ($element, $reason, $design_info, $key) = @_;
           $note_problem->("The $element->{'type'} barcode \"".($element->{'value'} // '')."\" was left blank", $reason, $design_info, $key);
       };

       # Create a blank file
       my $dir = $c->tempfiles_subdir('labels');
       my $file_prefix = $source_name;
       $file_prefix =~ s/[^a-zA-Z0-9-_]//g;

       my ($FH, $filename) = $c->tempfile(TEMPLATE=>"labels/$file_prefix-XXXXX", SUFFIX=>".$download_type");

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
           my %pdf_fonts; # fonts loaded into this PDF, by name or file
           my ($page, $text, $gfx);
           my $start_page = sub {
               $pdf->finishobjects($page, $gfx, $text) if $page; #flush the page to save memory on big PDFs
               $page = $pdf->page();
               $text = $page->text();
               $gfx = $page->gfx();
               $page->mediabox($design_params->{'page_width'}, $design_params->{'page_height'});
           };
           $start_page->();

           # loop through the selected labels, in the sorted order
           foreach my $label (@labels_to_print) {
               my ($key, $position) = @$label;
               my %design_info = %{$design{$key}};

                    for (my $i=0; $i < $copies_per_plot; $i++) {
                        # the sheet is full: start a new page only now that there is a label for it
                        if ($row_num > $design_params->{'number_of_rows'}) {
                            $start_page->();
                            $row_num = 1;
                        }

                        my $label_x = $design_params->{'left_margin'} + ($design_params->{'label_width'} + $design_params->{'horizontal_gap'}) * ($col_num-1);
                        my $label_y = $design_params->{'page_height'} - $design_params->{'top_margin'} - ($design_params->{'label_height'} + $design_params->{'vertical_gap'}) * ($row_num-1);

                       foreach my $element (@$label_params) {
                           my %element = %{$element};
                           my $elementx = $label_x + ( $element{'x'} / $conversion_factor );
                           my $elementy = $label_y - ( $element{'y'} / $conversion_factor );

                           my $filled_value = $element{'value'} // '';
                           $filled_value =~ s/\{(.*?)\}/process_field($1,$position,\%design_info)/ge;

                           if ( $element{'type'} eq "Code128" || $element{'type'} eq "QRCode" ) {

                                # one barcode that cannot be made leaves its space blank;
                                # the other labels are still printed and the user is told
                                my $problem = _barcode_problem($element{'type'}, $filled_value);
                                if (!$problem) {
                                    eval {
                                        _write_barcode_png($element{'type'}, $filled_value, $element{'size'}, $png_location, $qrcode);
                                        1;
                                    } or do {
                                        $problem = _clean_error($@);
                                    };
                                }
                                if ($problem) {
                                    $note_barcode_problem->($element, $problem, \%design_info, $key) if $i == 0;
                                    next;
                                }

                                my $image = $pdf->image_png($png_location);
                                my $height = $element{'height'} / $conversion_factor ; # scale to 72 pts per inch
                                my $width = $element{'width'} / $conversion_factor ; # scale to 72 pts per inch
                                my $image_y = $elementy - ($height/2); # adjust for img position starting at bottom
                                my $image_x = $elementx - ($width/2);
                                $gfx->image($image, $image_x, $image_y, $width, $height);
                           }
                           else { #Text

                                my $adjusted_size = $element{'size'} / $conversion_factor;
                                my $line_spacing = $adjusted_size * 1.2; # padding between lines

                                my @lines = split(/\n/, $filled_value); # Split multiline text
                                my $start_y = $elementy;

                                foreach my $line (@lines) {
                                    my ($runs, $missing) = _pdf_text_runs($pdf, $element{'font'}, $line, \%pdf_fonts);
                                    if (@$missing && $i == 0) {
                                        my %seen;
                                        my $chars = join(' ', grep { !$seen{$_}++ } @$missing);
                                        $note_problem->("The text \"".($element{'value'} // '')."\" was printed without some characters",
                                            "no installed font has $chars", \%design_info, $key);
                                    }
                                    if (@$runs == 1) {
                                        $text->font($runs->[0][0], $adjusted_size);
                                        $text->translate($elementx, $start_y);
                                        if ($text_alignment eq "left") {
                                            $text->text($runs->[0][1]);
                                        } else {
                                            $text->text_center($runs->[0][1]);
                                        }
                                    } elsif (@$runs) {
                                        # characters from more than one font: print the pieces one after another
                                        my $line_width = 0;
                                        $line_width += $_->[0]->width($_->[1]) * $adjusted_size for @$runs;
                                        my $run_x = $text_alignment eq "left" ? $elementx : $elementx - ($line_width / 2);
                                        foreach my $run (@$runs) {
                                            $text->font($run->[0], $adjusted_size);
                                            $text->translate($run_x, $start_y);
                                            $text->text($run->[1]);
                                            $run_x += $run->[0]->width($run->[1]) * $adjusted_size;
                                        }
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
                    }
             }

           print STDERR "Saving the PDF : ".localtime()."\n";
           $pdf->save();

       } elsif ($download_type eq 'zpl') {

           print STDERR "Generating zpl . . .\n";
           binmode($FH, ':encoding(UTF-8)');
           my $zpl_obj = CXGN::ZPL->new(
               print_width => $design_params->{'label_width'} * $conversion_factor,
               label_length => $design_params->{'label_height'} * $conversion_factor
           );
           $zpl_obj->start_sequence();
           $zpl_obj->label_format();
           my @barcode_elements;
           my @zebra_texts;
           foreach my $element (@$label_params) {
               # elements are placed by their top left corner. Text drawn left aligned
               # already has its left edge at x; everything else is centred on x.
               my $type = $element->{'type'} // '';
               my $is_text = $type =~ /Text/;
               my $x = ($is_text && $text_alignment eq 'left') ? $element->{'x'} : $element->{'x'} - ($element->{'width'}/2);
               my $y = $element->{'y'} - ($element->{'height'}/2);
               if ($type eq 'ZebraText') {
                   # filled in per label: printer font A, or an image for other scripts
                   push @zebra_texts, { element => $element, x => $x, y => $y };
                   $zpl_obj->add("\x{1}ZEBRA_TEXT_$#zebra_texts\x{1}");
                   next;
               }
               $zpl_obj->new_element($type, $x, $y, $element->{'size'}, $element->{'value'});
               push @barcode_elements, $element if $type eq 'Code128' || $type eq 'QRCode';
           }
           my %zpl_fonts; # Imager fonts, by file

           # Font A of the printer only has Latin characters. Text in other
           # scripts is drawn by the server and sent as an image (^GFA).
           my $zebra_text_command = sub {
               my ($index, $design_info, $position, $key) = @_;
               my $zebra_text = $zebra_texts[$index];
               my $element = $zebra_text->{element};
               my $filled_value = $element->{'value'} // '';
               $filled_value =~ s/\{(.*?)\}/process_field($1,$position,$design_info)/ge;

               if ($filled_value =~ /[^\x00-\xFF]/) {
                   my $image = _zpl_text_image($filled_value, $element->{'size'}, \%zpl_fonts);
                   if (@{$image->{missing}}) {
                       my %seen;
                       my $chars = join(' ', grep { !$seen{$_}++ } @{$image->{missing}});
                       $note_problem->("The Zebra text \"".($element->{'value'} // '')."\" was printed without some characters",
                           "no installed font has $chars", $design_info, $key);
                   }
                   if ($image->{hex}) {
                       my $x = $text_alignment eq 'left' ? $element->{'x'} : $element->{'x'} - ($image->{width} / 2);
                       my $y = $element->{'y'} - ($image->{height} / 2);
                       return CXGN::ZPL->graphic_command($x, $y, $image->{bytes_per_row}, $image->{hex});
                   }
                   $note_problem->("The Zebra text \"".($element->{'value'} // '')."\" may not print correctly",
                       "no font is installed on the server to draw it, and the printer's built-in font A only has Latin characters; use a PDF for these labels", $design_info, $key);
               }
               return CXGN::ZPL->new->text_command($zebra_text->{x}, $zebra_text->{y}, $element->{'size'}, $filled_value);
           };
           $zpl_obj->end_sequence();
           my $zpl_template = $zpl_obj->render();
           foreach my $label (@labels_to_print) {
               my ($key, $position) = @$label;
               my %design_info = %{$design{$key}};

               # the printer builds the barcodes, so only report the values it cannot encode
               foreach my $element (@barcode_elements) {
                   my $filled_value = $element->{'value'} // '';
                   $filled_value =~ s/\{(.*?)\}/process_field($1,$position,\%design_info)/ge;
                   my $problem = _barcode_problem($element->{'type'}, $filled_value);
                   $note_barcode_problem->($element, $problem, \%design_info, $key) if $problem;
               }

               my $zpl = $zpl_template;
               $zpl =~ s/\{(.*?)\}/process_field($1,$position,\%design_info)/ge;
               # after the fields, so a value holding "{...}" is not filled in again
               $zpl =~ s/\x{1}ZEBRA_TEXT_(\d+)\x{1}/$zebra_text_command->($1, \%design_info, $position, $key)/ge;
               # ^CI28: the field data of this label is UTF-8
               $zpl =~ s/^\^XA\n/^XA\n^CI28\n/ if $zpl =~ /[^\x00-\x7F]/;
               for (my $i=0; $i < $copies_per_plot; $i++) {
                   print $FH $zpl;
               }
           }
       }

       close($FH);

       my @warnings = map {
           my $problem = $problems{$_};
           my @labels = @{$problem->{labels}};
           my $shown = join(', ', grep { defined } @labels[0 .. ($#labels < 4 ? $#labels : 4)]);
           $shown .= ", ..." if @labels > 5;
           "$problem->{what} on ".scalar(@labels)." label(s) ($shown): $problem->{reason}.";
       } @problem_order;

       print STDERR "Returning with filename . . .\n";
       $c->stash->{rest} = {
           filename => $urlencode{$filename},
           filepath => $c->config->{basepath}."/".$filename,
           labels => scalar(@labels_to_print) * $copies_per_plot,
           (@warnings ? (warnings => \@warnings) : ()),
       };

   }

# Checks the sheet and range settings of a design before any file is made.
# Returns an error message, or (undef, first label, last label) where the
# labels are counted from 1 and the last label is undef for "to the end".
sub _check_label_settings {
    my $params = shift;
    my $download_type = shift;

    my $is_whole = sub { my $v = shift; return defined($v) && $v =~ /^\s*\d+\s*$/; };
    my $is_positive = sub { my $v = shift; return defined($v) && $v =~ /^\s*(\d+\.?\d*|\.\d+)\s*$/ && $v > 0; };
    my $is_given = sub { my $v = shift; return defined($v) && $v ne ''; };

    my $copies = $params->{'copies_per_plot'};
    if (!$is_whole->($copies) || $copies < 1) {
        return ("Copies per label must be a whole number of 1 or more.");
    }

    if (!$is_positive->($params->{'label_width'}) || !$is_positive->($params->{'label_height'})) {
        return ("The label width and height must be larger than 0.");
    }

    if ($download_type eq 'pdf') {
        if (!$is_positive->($params->{'page_width'}) || !$is_positive->($params->{'page_height'})) {
            return ("The page width and height must be larger than 0.");
        }
        foreach my $setting (['number_of_columns', 'Number of columns'], ['number_of_rows', 'Number of rows']) {
            my ($name, $label) = @$setting;
            if (!$is_whole->($params->{$name}) || $params->{$name} < 1) {
                return ("$label must be a whole number of 1 or more.");
            }
        }
        foreach my $setting (['start_col', 'Start Column', 'number_of_columns', 'columns'], ['start_row', 'Start Row', 'number_of_rows', 'rows']) {
            my ($name, $label, $max_name, $unit) = @$setting;
            my $value = $params->{$name};
            next if !$is_given->($value);
            if (!$is_whole->($value) || $value < 1 || $value > $params->{$max_name}) {
                return ("$label must be between 1 and $params->{$max_name}, the number of $unit on the sheet.");
            }
        }
    }

    my $start = $params->{'start_number'};
    my $end = $params->{'end_number'};
    my $total = $params->{'labels_to_download'};

    if ($is_given->($start) && !$is_whole->($start)) {
        return ("Start Number must be a whole number.");
    }
    foreach my $setting ([$end, 'End Number'], [$total, 'Total # to download']) {
        my ($value, $label) = @$setting;
        if ($is_given->($value) && (!$is_whole->($value) || $value < 1)) {
            return ("$label must be a whole number of 1 or more.");
        }
    }

    # Start 0 or empty means the first label
    my $first = ($is_given->($start) && $start > 0) ? $start + 0 : 1;
    my $last;
    if ($is_given->($total)) {
        $last = $first + $total - 1;
    } elsif ($is_given->($end)) {
        $last = $end + 0;
        if ($last < $first) {
            return ("End Number ($last) is smaller than Start Number ($first).");
        }
    }
    return (undef, $first, $last);
}

# The PDF core fonts (Courier, Helvetica, Times) only have Latin characters.
# Other characters are taken from Unicode fonts installed on the server:
# DejaVu in the style of the chosen font (Latin, Greek, Cyrillic, ...), then
# Droid Sans Fallback (Chinese, Japanese, Korean). Returns [ file, ttfont options ].
sub _unicode_font_files {
    my $core_font = shift // '';
    my $family = $core_font =~ /^Courier/ ? 'DejaVuSansMono' : $core_font =~ /^Times/ ? 'DejaVuSerif' : 'DejaVuSans';
    my $bold = $core_font =~ /Bold/;
    my $slanted = $core_font =~ /Italic|Oblique/;
    my $slant = $family eq 'DejaVuSerif' ? 'Italic' : 'Oblique';
    my $style = $bold && $slanted ? "-Bold$slant" : $bold ? '-Bold' : $slanted ? "-$slant" : '';
    return (
        [ "/usr/share/fonts/truetype/dejavu/$family$style.ttf" ],
        [ "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf" ],
        # embedded whole: the PDF::API2 subset loses glyphs with high numbers,
        # which are most of the Chinese and Japanese characters of this font
        [ "/usr/share/fonts/truetype/droid/DroidSansFallbackFull.ttf", -nosubset => 1 ],
    );
}

# Splits a line of text into pieces that each use one font that has their
# characters. Returns ([ [font, text], ... ], [ characters no font has ]).
sub _pdf_text_runs {
    my ($pdf, $core_font_name, $line, $fonts) = @_;
    $core_font_name ||= 'Courier';
    my $core_font = $fonts->{"core:$core_font_name"} //= $pdf->corefont($core_font_name);
    return ([ [ $core_font, $line ] ], []) if $line !~ /[^\x00-\xFF]/;

    # a font is only added to the PDF when a character needs it
    my $font_for = sub {
        my $char = shift;
        foreach my $candidate (_unicode_font_files($core_font_name)) {
            my ($file, @options) = @$candidate;
            if (!exists $fonts->{$file}) {
                $fonts->{$file} = -r $file ? eval { $pdf->ttfont($file, @options) } : undef;
            }
            my $font = $fonts->{$file} or next;
            return $font if ($font->glyphByUni(ord($char)) // '.notdef') ne '.notdef';
        }
        return;
    };

    my (@runs, @missing);
    foreach my $char (split //, $line) {
        my $font = ord($char) <= 0xFF ? $core_font : $font_for->($char);
        if (!$font) {
            push @missing, $char;
            next;
        }
        if (@runs && $runs[-1][0] == $font) {
            $runs[-1][1] .= $char;
        } else {
            push @runs, [ $font, $char ];
        }
    }
    return (\@runs, \@missing);
}

# Draws text for a Zebra printer as a 1-bit image, with the same font
# fallback as the PDF (one font per character). Returns { hex, bytes_per_row,
# width, height, missing }: hex is empty when nothing could be drawn, and
# missing lists the characters no installed font has.
sub _zpl_text_image {
    my ($value, $size, $fonts) = @_;
    $size = 20 if !$size || $size !~ /^\s*\d+(?:\.\d+)?\s*$/ || $size <= 0;

    my $font_for = sub {
        my $char = shift;
        foreach my $candidate (_unicode_font_files('Courier')) {
            my ($file) = @$candidate;
            if (!exists $fonts->{$file}) {
                $fonts->{$file} = -r $file ? Imager::Font->new(file => $file, type => 'ft2') : undef;
            }
            my $font = $fonts->{$file} or next;
            return $font if ($font->has_chars(string => $char))[0];
        }
        return;
    };

    my (@lines, @missing);
    my ($ascent, $descent, $width) = (0, 0, 0);
    foreach my $line (split /\n/, $value) {
        my @runs;
        my $line_width = 0;
        foreach my $char (split //, $line) {
            my $font = $font_for->($char);
            if (!$font) {
                push @missing, $char;
                next;
            }
            if (@runs && $runs[-1][0] == $font) {
                $runs[-1][1] .= $char;
            } else {
                push @runs, [ $font, $char ];
            }
        }
        foreach my $run (@runs) {
            my $box = $run->[0]->bounding_box(string => $run->[1], size => $size);
            $run->[2] = $box->advance_width;
            $line_width += $box->advance_width;
            $ascent = $box->global_ascent if $box->global_ascent > $ascent;
            $descent = $box->global_descent if $box->global_descent < $descent;
        }
        $width = $line_width if $line_width > $width;
        push @lines, \@runs;
    }

    my $line_height = $ascent - $descent;
    $width = int($width + 0.999);
    my $height = $line_height * @lines;
    return { hex => '', missing => \@missing } if $width < 1 || $height < 1;

    # Imager draws text on colour images only
    my $image = Imager->new(xsize => $width, ysize => $height, channels => 3);
    $image->box(filled => 1, color => Imager::Color->new(255, 255, 255));
    my $baseline = $ascent;
    foreach my $runs (@lines) {
        my $x = 0;
        foreach my $run (@$runs) {
            $image->string(font => $run->[0], string => $run->[1], x => $x, y => $baseline, size => $size, color => Imager::Color->new(0, 0, 0), aa => 1);
            $x += $run->[2];
        }
        $baseline += $line_height;
    }
    $image = $image->convert(preset => 'gray');

    # ^GFA data: one bit per dot, 1 = black, each row padded to whole bytes
    my $bytes_per_row = int(($width + 7) / 8);
    my $hex = '';
    foreach my $row (0 .. $height - 1) {
        my $bits = join('', map { $_ < 128 ? 1 : 0 } $image->getsamples(y => $row));
        $bits .= '0' x ($bytes_per_row * 8 - length($bits));
        $hex .= uc(unpack('H*', pack('B*', $bits)));
    }
    return { hex => $hex, bytes_per_row => $bytes_per_row, width => $width, height => $height, missing => \@missing };
}

# Why a barcode cannot hold a value, or nothing when it can.
sub _barcode_problem {
    my $type = shift;
    my $value = shift;

    if (!defined($value) || $value !~ /\S/) {
        return "the value is empty, so there is nothing to encode";
    }
    if ($type eq 'Code128' && $value =~ /[^\x00-\x7F]/) {
        return "Code128 can only hold plain ASCII characters (no accents or non-Latin letters); use a QR code for this field";
    }
    return;
}

sub _write_barcode_png {
    my ($type, $value, $size, $png_location, $qrcode) = @_;

    if ($type eq 'Code128') {
        my $barcode_object = Barcode::Code128->new();
        $barcode_object->option("scale", $size, "font_align", "center", "padding", 5, "show_text", 0);
        $barcode_object->barcode($value);
        my $png = $barcode_object->gd_image()->png();
        open(my $PNG, ">", $png_location) or die "Can't write $png_location: $!\n";
        binmode($PNG);
        print $PNG $png;
        close($PNG);
    } else {
        my $barcode = $qrcode->plot($value);
        $barcode->write(file => $png_location) or die $barcode->errstr;
        system("convert $png_location -depth 8 $png_location"); # convert to 8 bit encoding. Won't work with default 16 bit encoding.
    }
}

sub _clean_error {
    my $error = shift // 'unknown error';
    $error =~ s/ at \S+ line \d+.*//s;
    $error =~ s/\s+$//;
    return $error;
}

sub _label_name {
    my $design_info = shift;
    my $key = shift;
    foreach my $field (qw(plot_name plant_name subplot_name tissue_sample_name list_item_name identifier)) {
        return $design_info->{$field} if defined($design_info->{$field}) && $design_info->{$field} ne '';
    }
    return $key;
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
        return $design_info{$field} // '';
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
        plots => {plot_name=>1,plot_id=>1,accession_name=>1,synonyms=>1,accession_id=>1,plot_number=>1,block_number=>1,is_a_control=>1,rep_number=>1,range_number=>1,row_number=>1,col_number=>1,seedlot_name=>1,seed_transaction_operator=>1,num_seed_per_plot=>1,pedigree=>1,location_name=>1,trial_name=>1,year=>1,tier=>1,plot_geo_json=>1, planting_date=>1, variety=>1},
        plants => {plant_name=>1,plant_id=>1,subplot_name=>1,subplot_id=>1,plot_name=>1,plot_id=>1,accession_name=>1,synonyms=>1,accession_id=>1,plot_number=>1,block_number=>1,is_a_control=>1,range_number=>1,rep_number=>1,row_number=>1,col_number=>1,seedlot_name=>1,seed_transaction_operator=>1,num_seed_per_plot=>1,subplot_number=>1,plant_number=>1,pedigree=>1,location_name=>1,trial_name=>1,year=>1,tier=>1,plot_geo_json=>1, planting_date=>1, variety=>1},
        subplots => {subplot_name=>1,subplot_id=>1,plot_name=>1,plot_id=>1,accession_name=>1,synonyms=>1,accession_id=>1,plot_number=>1,block_number=>1,is_a_control=>1,rep_number=>1,range_number=>1,row_number=>1,col_number=>1,seedlot_name=>1,seed_transaction_operator=>1,num_seed_per_plot=>1,subplot_number=>1,pedigree=>1,location_name=>1,trial_name=>1,year=>1,tier=>1,plot_geo_json=>1, planting_date=>1, variety=>1},
        field_trial_tissue_samples => {tissue_sample_name=>1,tissue_sample_id=>1,plant_name=>1,plant_id=>1,subplot_name=>1,subplot_id=>1,plot_name=>1,plot_id=>1,accession_name=>1,synonyms=>1,accession_id=>1,plot_number=>1,block_number=>1,is_a_control=>1,range_number=>1,rep_number=>1,row_number=>1,col_number=>1,seedlot_name=>1,seed_transaction_operator=>1,num_seed_per_plot=>1,subplot_number=>1,plant_number=>1,tissue_sample_number=>1,pedigree=>1,location_name=>1,trial_name=>1,year=>1,tier=>1,plot_geo_json=>1, planting_date=>1, variety=>1}
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

        my $trial_layout_download = CXGN::Trial::TrialLayoutDownload->new({
            schema => $schema,
            trial_id => $trial_id,
            data_level => $type,
            include_treatments => 'true',
            selected_columns => $selected_columns{$type},
            selected_trait_ids => [],
            use_synonyms => 'true',
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
        my @list_data = @{$list_data || []};
        # a missing list, or one that does not hold an identifier batch, gives no design
        my $identifier_json = @list_data ? $list_data[0][1] : undef;
        my $identifier_object = defined($identifier_json)
            ? eval { utf8::is_utf8($identifier_json) ? JSON->new->decode($identifier_json) : decode_json($identifier_json) }
            : undef;
        my $records = ref($identifier_object) eq 'HASH' ? $identifier_object->{'records'} : [];
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
