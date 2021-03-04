
package SGN::Controller::AJAX::Order;

use Moose;
use CXGN::Stock::StockOrder;
use CXGN::Stock::Catalog;
use Data::Dumper;
use JSON;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
   );


sub order :Chained('/') PathPart('ajax/orders/') Args(1) {
    my $self = shift;
    my $c = shift;

    my $person_id = shift;

    my $orders = CXGN::Stock::StockOrder::get_orders_by_person_id( $c->dbic_schema(), $person_id);

    $c->stash->{order_from_person_id} = $person_id;
    $c->stash->{orders} = { data => $orders };
}

sub new_orders :Chained('order') PathPart('view') Args(0) {
    my $self = shift;
    my $c = shift;

    $c->stash->{rest} = { data => $c->stash->{orders} };
}


sub new_order: Chained('order') PathPart('new') Args(0) {
    my $self = shift;
    my $c = shift;

    my $order_from_person_id =  $c->stash->{order_from_person_id};
    my $order_to_person_id = $c->req->param('order_to_person_id');
    #my $order_status = $c->req->param('order_status');
    my $comment = $c->req->param('comments');

    my $so = CXGN::Stock::StockOrder->new( { bcs_schema => $c->dbic_schema() });

    $so->order_from_person_id($order_from_person_id);
    $so->order_to_person_id($order_to_person_id);
    $so->order_status("submitted");
    $so->comment($comment);

    $so->store();
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
            $c->stash->{rest} = {error=>'You must be logged in to upload progenies!'};
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
    print STDERR "PARSED DATA =".Dumper($parsed_data)."\n";

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
        my %catalog_info = %{$parsed_data};
        foreach my $item_name (keys %catalog_info) {
            my $stock_rs = $schema->resultset("Stock::Stock")->find({uniquename => $item_name});
            my $stock_id = $stock_rs->stock_id();
            print STDERR "STOCK ID =".Dumper($stock_id)."\n";
            my %catalog_info_hash = %{$catalog_info{$item_name}};

            my $stock_catalog = CXGN::Stock::Catalog->new({
                bcs_schema => $schema,
                item_type => $catalog_info_hash{item_type},
                category => $catalog_info_hash{category},
                description => $catalog_info_hash{description},
                material_source => $catalog_info_hash{material_source},
                breeding_program => $catalog_info_hash{breeding_program},
                availability => $catalog_info_hash{availability},
                parent_id => $stock_id
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

    my $catalog_obj = CXGN::Stock::Catalog->new({ bcs_schema => $schema});
    my $catalog_ref = $catalog_obj->get_catalog_items();
#    print STDERR "ITEM RESULTS =".Dumper($catalog_ref)."\n";
    my @catalog_items;
    my @catalog_list = @$catalog_ref;
    foreach my $catalog_item (@catalog_list) {
        my @item_detail = ();
        my @item_detail = @$catalog_item;
        my $item_id = shift @item_detail;
        my $stock_rs = $schema->resultset("Stock::Stock")->find({stock_id => $item_id });
        my $item_name = $stock_rs->uniquename();
        unshift @item_detail, qq{<a href="/stock/$item_id/view">$item_name</a>};

        push @catalog_items, [@item_detail];
    }

    $c->stash->{rest} = {data => \@catalog_items};

}


1;
