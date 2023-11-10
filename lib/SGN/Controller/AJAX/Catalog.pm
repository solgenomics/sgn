package SGN::Controller::AJAX::Catalog;

use Moose;
use CXGN::Stock::Catalog;
use Data::Dumper;
use JSON;
use CXGN::People::Person;
use SGN::Image;
use CXGN::Stock::StockLookup;
use SGN::Model::Cvterm;
use CXGN::List::Validate;
use CXGN::List;
use CXGN::Stock::Seedlot;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );


sub add_catalog_item : Path('/ajax/catalog/add_item') : ActionClass('REST'){ }

sub add_catalog_item_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $dbh = $c->dbc->dbh;

    my $item_name = $c->req->param('name');
    my $item_category = $c->req->param('category');
    my $item_additional_info = $c->req->param('additional_info');
    my $item_material_source = $c->req->param('material_source');
    my $item_breeding_program_id = $c->req->param('breeding_program_id');
    my $contact_person = $c->req->param('contact_person');
    my $item_prop_id = $c->req->param('item_prop_id');
    my $availability = $c->req->param('availability');
    if (!defined $availability) {
        $availability = 'available';
    }

    if (!$c->user()) {
        print STDERR "User not logged in... not adding a catalog item.\n";
        $c->stash->{rest} = {error_string => "You must be logged in to add a catalog item." };
        return;
    }

    my $item_material_type;
    my $item_type;
    my $item_stock_id;
    my $item_species;
    my $item_variety;

    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $seedlot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'seedlot', 'stock_type')->cvterm_id();
    my $vector_construct_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'vector_construct', 'stock_type')->cvterm_id();
    my $population_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'population', 'stock_type')->cvterm_id();

    my $stock_lookup = CXGN::Stock::StockLookup->new(schema => $schema);
    $stock_lookup->set_stock_name($item_name);
    my $item_rs = $stock_lookup->get_stock_exact();

    if (!defined $item_rs) {
        $c->stash->{rest} = {error_string => "Item name is not in the database or not unique in the database!",};
        return;
    } else {
        $item_stock_id = $item_rs->stock_id();
        my $item_type_id = $item_rs->type_id();

        my $variety_result = $stock_lookup->get_stock_variety();
        if (defined $variety_result) {
            $item_variety = $variety_result;
        } else {
            $item_variety = 'NA';
        }

        if ($item_type_id == $accession_cvterm_id) {
            my $organism_id = $item_rs->organism_id();
            my $organism = $schema->resultset("Organism::Organism")->find({organism_id => $organism_id});
            $item_species = $organism->species();
            $item_material_type = 'plant';
            $item_type = 'single item';

        } elsif ($item_type_id == $seedlot_cvterm_id) {
            my $seedlot_species = CXGN::Stock::Seedlot->new(schema => $schema, seedlot_id=>$item_stock_id);
            $item_species = $seedlot_species->get_seedlot_species();
            $item_material_type = 'seed';
            $item_type = 'single item';

        } elsif ($item_type_id == $vector_construct_cvterm_id) {
            $item_material_type = 'construct';
            $item_type = 'single item';

        } elsif ($item_type_id == $population_cvterm_id) {
            $item_material_type = 'plant';
            $item_type = 'set of items';
        }

    }

    my $sp_person_id = CXGN::People::Person->get_person_by_username($dbh, $contact_person);
    if (!$sp_person_id) {
        $c->stash->{rest} = {error_string => "Contact person has no record in the database!",};
        return;
    }
#    print STDERR "PERSON ID =".Dumper($sp_person_id)."\n";
    my $program_rs = $schema->resultset('Project::Project')->find({project_id => $item_breeding_program_id});
    if (!$program_rs) {
        $c->stash->{rest} = {error_string => "Breeding program is not in the database!",};
        return;
    }

    my $stock_catalog = CXGN::Stock::Catalog->new({
        bcs_schema => $schema,
        parent_id => $item_stock_id,
        prop_id => $item_prop_id
    });

    $stock_catalog->item_type($item_type);
    $stock_catalog->material_type($item_material_type);
    $stock_catalog->material_source($item_material_source);
    $stock_catalog->category($item_category);
    $stock_catalog->species($item_species);
    $stock_catalog->variety($item_variety);
    $stock_catalog->breeding_program($item_breeding_program_id);
    $stock_catalog->availability($availability);
    $stock_catalog->additional_info($item_additional_info);
    $stock_catalog->contact_person_id($sp_person_id);

    $stock_catalog->store();

    if (!$stock_catalog->store()){
        $c->stash->{rest} = {error_string => "Error saving catalog item",};
        return;
    }

    $c->stash->{rest} = {success => "1",};

}


sub upload_catalog_items : Path('/ajax/catalog/upload_items') : ActionClass('REST'){ }

sub upload_catalog_items_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $dbh = $c->dbc->dbh;
    my $upload = $c->req->upload('catalog_items_upload_file');
    my $upload_type = 'CatalogXLS';
    my $parser;
    my $parsed_data;
    my $upload_original_name = $upload->filename();
    my $upload_tempfile = $upload->tempname;
    my $subdirectory = "catalog_upload";
    my $archived_filename_with_path;
    my $md5;
    my $validate_file;
    my $parsed_file;
    my $parse_errors;
    my %parsed_data;
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();
    my $user_role;
    my $user_id;
    my $user_name;
    my $owner_name;
    my $session_id = $c->req->param("sgn_session_id");

    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{rest} = {error=>'You must be logged in to upload!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else{
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to upload catalog items!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }
    my $uploader = CXGN::UploadFile->new({
        tempfile => $upload_tempfile,
        subdirectory => $subdirectory,
        archive_path => $c->config->{archive_path},
        archive_filename => $upload_original_name,
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $user_role
    });

    ## Store uploaded temporary file in arhive
    $archived_filename_with_path = $uploader->archive();
    $md5 = $uploader->get_md5($archived_filename_with_path);
    if (!$archived_filename_with_path) {
        $c->stash->{rest} = {error => "Could not save file $upload_original_name in archive",};
        return;
    }
    unlink $upload_tempfile;
    #parse uploaded file with appropriate plugin
    my @stock_props = ('stock_catalog_json');
    $parser = CXGN::Stock::ParseUpload->new(chado_schema => $schema, filename => $archived_filename_with_path, editable_stock_props=>\@stock_props);
    $parser->load_plugin($upload_type);
    $parsed_data = $parser->parse();

    if (!$parsed_data){
        my $return_error = '';
        my $parse_errors;
        if (!$parser->has_parse_errors() ){
            $c->stash->{rest} = {error_string => "Could not get parsing errors"};
        } else {
            $parse_errors = $parser->get_parse_errors();
            #print STDERR Dumper $parse_errors;

            foreach my $error_string (@{$parse_errors->{'error_messages'}}){
                $return_error .= $error_string."<br>";
            }
        }
        $c->stash->{rest} = {error_string => $return_error};
        $c->detach();
    }

    if ($parsed_data) {
        my $variety_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'variety', 'stock_property')->cvterm_id();
        my %catalog_info = %{$parsed_data};
        foreach my $item_name (keys %catalog_info) {
            my $item_stock_id;
            my $item_species;
            my $item_variety;
            my $item_type;
            my $item_material_type;
            my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
            my $seedlot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'seedlot', 'stock_type')->cvterm_id();
            my $vector_construct_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'vector_construct', 'stock_type')->cvterm_id();
            my $population_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'population', 'stock_type')->cvterm_id();

            my $stock_lookup = CXGN::Stock::StockLookup->new(schema => $schema);
            $stock_lookup->set_stock_name($item_name);
            my $item_rs = $stock_lookup->get_stock_exact();

            if (!defined $item_rs) {
                $c->stash->{rest} = {error_string => "Item name is not unique in the database!",};
                return;
            } else {
                $item_stock_id = $item_rs->stock_id();
                my $item_type_id = $item_rs->type_id();

                my $variety_result = $stock_lookup->get_stock_variety();
                if (defined $variety_result) {
                    $item_variety = $variety_result;
                } else {
                    $item_variety = 'NA';
                }

                if ($item_type_id == $accession_cvterm_id) {
                    my $organism_id = $item_rs->organism_id();
                    my $organism = $schema->resultset("Organism::Organism")->find({organism_id => $organism_id});
                    $item_species = $organism->species();
                    $item_material_type = 'plant';
                    $item_type = 'single item';

                } elsif ($item_type_id == $seedlot_cvterm_id) {
                    my $seedlot_species = CXGN::Stock::Seedlot->new(schema => $schema, seedlot_id=>$item_stock_id);
                    $item_species = $seedlot_species->get_seedlot_species();
                    $item_material_type = 'seed';
                    $item_type = 'single item';

                } elsif ($item_type_id == $vector_construct_cvterm_id) {
                    $item_material_type = 'construct';
                    $item_type = 'single item';

                } elsif ($item_type_id == $population_cvterm_id) {
                    $item_material_type = 'plant';
                    $item_type = 'set of items';
                }

            }

            my %catalog_info_hash = %{$catalog_info{$item_name}};

            my $stock_catalog = CXGN::Stock::Catalog->new({
                bcs_schema => $schema,
                item_type => $item_type,
                material_type => $item_material_type,
                species => $item_species,
                variety => $item_variety,
                category => $catalog_info_hash{category},
                availability => 'available',
                additional_info => $catalog_info_hash{additional_info},
                material_source => $catalog_info_hash{material_source},
                breeding_program => $catalog_info_hash{breeding_program},
                contact_person_id => $catalog_info_hash{contact_person_id},
                parent_id => $item_stock_id
            });

            $stock_catalog->store();

            if (!$stock_catalog->store()){
                $c->stash->{rest} = {error_string => "Error saving catalog items",};
                return;
            }
        }
    }

    $c->stash->{rest} = {success => "1"};

}


sub get_catalog :Path('/ajax/catalog/items') :Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my @catalog_items;

    my $catalog_obj = CXGN::Stock::Catalog->new({ bcs_schema => $schema});
    my $catalog_ref = $catalog_obj->get_catalog_items();
#    print STDERR "ITEM RESULTS =".Dumper($catalog_ref)."\n";
    my @catalog_list = @$catalog_ref;
    foreach my $catalog_item (@catalog_list) {
        my @item_details = ();
        @item_details = @$catalog_item;
        my $item_id = shift @item_details;
        my $stock_rs = $schema->resultset("Stock::Stock")->find({stock_id => $item_id });
        my $item_name = $stock_rs->uniquename();

        my $program_id = $item_details[7];
        my $program_rs = $schema->resultset('Project::Project')->find({project_id => $program_id});
        my $program_name = $program_rs->name();
        my $availability = $item_details[8];
        if (!defined $availability) {
            $availability = 'available';
        }

        push @catalog_items, {
            item_id => $item_id,
            item_name => $item_name,
            item_type => $item_details[0],
            species => $item_details[1],
            variety => $item_details[2],
            material_type => $item_details[3],
            category => $item_details[4],
            material_source => $item_details[5],
            additional_info => $item_details[6],
            breeding_program => $program_name,
            availability => $availability
        };
    }

    $c->stash->{rest} = {data => \@catalog_items};

}


sub item_image_list :Path('/ajax/catalog/image_list') :Args(1) {
    my $self = shift;
    my $c = shift;
    my $item_id = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $dbh = $c->dbc->dbh;
#    print STDERR "ITEM ID =".Dumper($item_id)."\n";

    my @image_ids;
    my $q = "select distinct image_id, cvterm.name, stock_image.display_order FROM phenome.stock_image JOIN stock USING(stock_id) JOIN cvterm ON(type_id=cvterm_id) WHERE stock_id = ? ORDER BY stock_image.display_order ASC";
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute($item_id);
    while (my ($image_id, $stock_type) = $h->fetchrow_array()){
        push @image_ids, [$image_id, $stock_type];
    }
#    print STDERR "IMAGE IDS =".Dumper(\@image_ids)."\n";
    my @image_list;
    foreach my $image_info(@image_ids) {
        my $image_obj = SGN::Image->new($dbh, $image_info->[0]);
        my $image_obj_id = $image_obj->get_image_id;
        my $image_obj_name = $image_obj->get_name();
        my $image_obj_description = $image_obj->get_description();
        if (!$image_obj_description) {
            $image_obj_description = 'N/A';
        }
        my $medium_image  = $image_obj->get_image_url("medium");
        my $image_page  = "/image/view/$image_obj_id";
        my $small_image = $image_obj->get_image_url("thumbnail");

        push @image_list, {
                image_id => $image_obj_id,
                image_name => $image_obj_name,
                small_image => qq|<a href="$medium_image"  title="<a href=$image_page>Go to image page ($image_obj_name)</a>" class="stock_image_group" rel="gallery-figures"><img src="$small_image"/></a> |,
                image_description => $image_obj_description,
            };
    }

    $c->stash->{rest} = {data => \@image_list};
}


sub edit_catalog_image : Path('/ajax/catalog/edit_image') : ActionClass('REST'){ }

sub edit_catalog_image_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $dbh = $c->dbc->dbh;

    my $item_name = $c->req->param('item_name');
    my $item_prop_id = $c->req->param('item_prop_id');
    my $image_id = $c->req->param('image_id');
    my @images;
    my $item_stock_id;
    push @images, $image_id;
    print STDERR "IMAGE ID =".Dumper(\@images)."\n";
    if (!$c->user()) {
        print STDERR "User not logged in... not adding a catalog item.\n";
        $c->stash->{rest} = {error_string => "You must be logged in to add a catalog image." };
        return;
    }

    my $item_rs = $schema->resultset("Stock::Stock")->find({uniquename => $item_name});
    if (!$item_rs) {
        $c->stash->{rest} = {error_string => "Item name is not in the database!",};
        return;
    } else {
        $item_stock_id = $item_rs->stock_id();
    }

    my $stock_catalog = CXGN::Stock::Catalog->new({
        bcs_schema => $schema,
        parent_id => $item_stock_id,
        prop_id => $item_prop_id
    });

    $stock_catalog->images(\@images);

    $stock_catalog->store();

    if (!$stock_catalog->store()){
        $c->stash->{rest} = {error_string => "Error saving catalog image",};
        return;
    }

    $c->stash->{rest} = {success => "1",};

}


sub delete_catalog_item : Path('/ajax/catalog/delete') : ActionClass('REST'){ }

sub delete_catalog_item_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    my $item_prop_id = $c->req->param('item_prop_id');
    print STDERR "ITEM PROP ID =".Dumper($item_prop_id)."\n";
    my $catalog_obj = CXGN::Stock::Catalog->new({ bcs_schema => $schema, prop_id => $item_prop_id });
    $catalog_obj->delete();
    if ($catalog_obj->delete() == 0) {
        $c->stash->{rest} = { error_string => "An error occurred attempting to delete a catalog item." };
        return;
    }

    $c->stash->{rest} = { success => 1 };
}


sub add_catalog_item_list : Path('/ajax/catalog/add_item_list') : ActionClass('REST'){ }

sub add_catalog_item_list_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $dbh = $c->dbc->dbh;

    my $list_type = $c->req->param('list_type');
    my $list_id = $c->req->param('catalog_list');
    my $list_category = $c->req->param('category');
    my $list_additional_info = $c->req->param('additional_info');
    my $list_material_source = $c->req->param('material_source');
    my $list_breeding_program_id = $c->req->param('breeding_program_id');
    my $list_contact_person = $c->req->param('contact_person');

    if (!$c->user()) {
        print STDERR "User not logged in... not adding catalog items.\n";
        $c->stash->{rest} = {error_string => "You must be logged in to add catalog items." };
        return;
    }

    my $sp_person_id = CXGN::People::Person->get_person_by_username($dbh, $list_contact_person);
    if (!$sp_person_id) {
        $c->stash->{rest} = {error_string => "Contact person has no record in the database!",};
        return;
    }

    my $item_type;
    my $item_material_type;

    if ($list_type eq 'accessions') {
        $item_material_type = 'plant';
        $item_type = 'single item';
    } elsif ($list_type eq 'seedlots') {
        $item_material_type = 'seed';
        $item_type = 'single item';
    } elsif ($list_type eq 'vector_constructs') {
        $item_material_type = 'construct';
        $item_type = 'single item';
    } elsif ($list_type eq 'populations') {
        $item_material_type = 'plant';
        $item_type = 'set of items';
    }

    my $item_list = CXGN::List->new({dbh => $dbh, list_id => $list_id});
    my $items = $item_list->retrieve_elements($list_id);
    my @item_names = @$items;

    my $list_error_message;
    my $item_validator = CXGN::List::Validate->new();
    my @item_missing = @{$item_validator->validate($schema, $list_type,\@item_names)->{'missing'}};
    if (scalar(@item_missing) > 0) {
        $list_error_message = "The following items are not in database or are not the specified list type: ".join("\n", @item_missing);
        $c->stash->{rest} = { error_string => $list_error_message };
        $c->detach();
    } else {
        foreach my $item (@item_names) {
            my $item_stock_id;
            my $item_species;
            my $item_variety;

            my $stock_lookup = CXGN::Stock::StockLookup->new(schema => $schema);
            $stock_lookup->set_stock_name($item);
            my $item_rs = $stock_lookup->get_stock_exact();

            if (!defined $item_rs) {
                $c->stash->{rest} = {error_string => "Item name is not unique in the database!",};
                return;
            } else {
                $item_stock_id = $item_rs->stock_id();

                my $variety_result = $stock_lookup->get_stock_variety();
                if (defined $variety_result) {
                    $item_variety = $variety_result;
                } else {
                    $item_variety = 'NA';
                }

                if ($list_type eq 'accessions') {
                    my $organism_id = $item_rs->organism_id();
                    my $organism = $schema->resultset("Organism::Organism")->find({organism_id => $organism_id});
                    $item_species = $organism->species();

                } elsif ($list_type eq 'seedlots') {
                    my $seedlot_species = CXGN::Stock::Seedlot->new(schema => $schema, seedlot_id=>$item_stock_id);
                    $item_species = $seedlot_species->get_seedlot_species();
                }

            }

            my $stock_catalog = CXGN::Stock::Catalog->new({
                bcs_schema => $schema,
                item_type => $item_type,
                material_type => $item_material_type,
                species => $item_species,
                variety => $item_variety,
                category => $list_category,
                availability => 'available',
                additional_info => $list_additional_info,
                material_source => $list_material_source,
                breeding_program => $list_breeding_program_id,
                contact_person_id => $sp_person_id,
                parent_id => $item_stock_id
            });

            $stock_catalog->store();

            if (!$stock_catalog->store()){
                $c->stash->{rest} = {error_string => "Error saving catalog items",};
                return;
            }
        }

    }

    $c->stash->{rest} = {success => "1",};

}


1;
