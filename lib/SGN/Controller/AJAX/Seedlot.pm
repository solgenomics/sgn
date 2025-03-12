
package SGN::Controller::AJAX::Seedlot;

use Moose;

BEGIN { extends 'Catalyst::Controller::REST' };

use Data::Dumper;
use DateTime;
use DateTime::Format::Strptime;
use CXGN::Stock::Seedlot;
use CXGN::Stock::Seedlot::Transaction;
use CXGN::Stock::Seedlot::Maintenance;
use SGN::Model::Cvterm;
use CXGN::Stock::Seedlot::ParseUpload;
use CXGN::Login;
use JSON;
use CXGN::BreederSearch;
use CXGN::Onto;
use CXGN::List;
use CXGN::List::Validate;
use CXGN::Stock::Seedlot::Discard;
use CXGN::Stock::RelatedStocks;

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON'  },
   );

sub list_seedlots :Path('/ajax/breeders/seedlots') :Args(0) {
    my $self = shift;
    my $c = shift;

    my $params = $c->req->params() || {};
    my $seedlot_name = $params->{seedlot_name} || '';
    my $description = $params->{description};
    my $breeding_program = $params->{breeding_program} || '';
    my $location = $params->{location} || '';
    my $box_name = $params->{box_name} || '';
    my $minimum_count = $params->{minimum_count} || '';
    my $minimum_weight = $params->{minimum_weight} || '';
    my $contents_accession = $params->{contents_accession} || '';
    my $contents_cross = $params->{contents_cross} || '';
    my $exact_accession = $params->{exact_accession};
    my $exact_cross = $params->{exact_cross};
    my $quality = $params->{quality};
    my $only_good_quality = $params->{only_good_quality};
    my $trial_name = $params->{trial_name};
    my $trial_usage = $params->{trial_usage};

    my $rows = $params->{length} || 10;
    my $offset = $params->{start} || 0;
    my $limit = ($offset+$rows)-1;
    my $draw = $params->{draw};
    $draw =~ s/\D//g; # cast to int


    my @accessions = split ',', $contents_accession;
    my @crosses = split ',', $contents_cross;

    my $exact_match_uniquenames = 0;
    if (@accessions > 0 && $exact_accession) {
        $exact_match_uniquenames = 1;
    } elsif (@crosses > 0 && $exact_cross) {
        $exact_match_uniquenames = 1;
    }

    my ($list, $records_total) = CXGN::Stock::Seedlot->list_seedlots(
        $c->dbic_schema("Bio::Chado::Schema", "sgn_chado"),
        $c->dbic_schema("CXGN::People::Schema"),
        $c->dbic_schema("CXGN::Phenome::Schema"),
        $offset,
        $limit,
        $seedlot_name,
        $description,
        $breeding_program,
        $location,
        $minimum_count,
        \@accessions,
        \@crosses,
        $exact_match_uniquenames,
        $minimum_weight,
        undef,
        undef,
        $quality,
        $only_good_quality,
        $box_name,
        undef,
        $trial_name,
        $trial_usage,
    );
    my @seedlots;
    foreach my $sl (@$list) {
        my $source_stock = $sl->{source_stocks};
        my $contents_html = '';
        if ($source_stock->[0]->[2] eq 'accession'){
            $contents_html .= '<a href="/stock/'.$source_stock->[0]->[0].'/view">'.$source_stock->[0]->[1].'</a> ('.$source_stock->[0]->[2].') ';
        }
        if ($source_stock->[0]->[2] eq 'cross'){
            $contents_html .= '<a href="/cross/'.$source_stock->[0]->[0].'">'.$source_stock->[0]->[1].'</a> ('.$source_stock->[0]->[2].') ';
        }
        push @seedlots, {
            breeding_program_id => $sl->{breeding_program_id},
            breeding_program_name => $sl->{breeding_program_name},
            seedlot_stock_id => $sl->{seedlot_stock_id},
            seedlot_stock_uniquename => $sl->{seedlot_stock_uniquename},
            contents_html => $contents_html,
            location => $sl->{location},
            location_id => $sl->{location_id},
            count => $sl->{current_count},
            weight_gram => $sl->{current_weight_gram},
            owners_string => $sl->{owners_string},
            organization => $sl->{organization},
            box => $sl->{box},
	        seedlot_quality => $sl->{seedlot_quality},
        };
    }

    $c->stash->{rest} = { data => \@seedlots, draw => $draw, recordsTotal => $records_total,  recordsFiltered => $records_total };
}

sub seedlot_base : Chained('/') PathPart('ajax/breeders/seedlot') CaptureArgs(1) {
    my $self = shift;
    my $c = shift;
    my $seedlot_id = shift;

    $c->stash->{schema} = $c->dbic_schema("Bio::Chado::Schema");
    $c->stash->{phenome_schema} = $c->dbic_schema("CXGN::Phenome::Schema");
    $c->stash->{seedlot_id} = $seedlot_id;
    $c->stash->{seedlot} = CXGN::Stock::Seedlot->new(
        schema => $c->stash->{schema},
        phenome_schema => $c->stash->{phenome_schema},
        seedlot_id => $c->stash->{seedlot_id},
    );
}

sub seedlot_details :Chained('seedlot_base') PathPart('') Args(0) {
    my $self = shift;
    my $c = shift;

    $c->stash->{rest} = {
        success => 1,
        uniquename => $c->stash->{seedlot}->uniquename(),
        description => $c->stash->{seedlot}->description(),
        seedlot_id => $c->stash->{seedlot}->seedlot_id(),
        current_count => $c->stash->{seedlot}->current_count(),
        current_weight => $c->stash->{seedlot}->current_weight(),
        location_code => $c->stash->{seedlot}->location_code(),
        breeding_program => $c->stash->{seedlot}->breeding_program_name(),
        organization_name => $c->stash->{seedlot}->organization_name(),
        population_name => $c->stash->{seedlot}->population_name(),
        accession => $c->stash->{seedlot}->accession(),
        cross => $c->stash->{seedlot}->cross(),
        box_name => $c->stash->{seedlot}->box_name(),
	quality => $c->stash->{seedlot}->quality(),
    };
}

sub seedlot_edit :Chained('seedlot_base') PathPart('edit') Args(0) {
    my $self = shift;
    my $c = shift;

    if (!$c->user()){
        $c->stash->{rest} = { error => "You must be logged in to edit seedlot details" };
        $c->detach();
    }
    if (!$c->user()->check_roles("curator")) {
        $c->stash->{rest} = { error => "You do not have the correct role to edit seedlot detail. Please contact us." };
        $c->detach();
    }
    my $seedlot = $c->stash->{seedlot};

    my $saved_seedlot_name = $seedlot->uniquename;
    my $seedlot_name = $c->req->param('uniquename');
    my $description = $c->req->param('description');
    my $breeding_program_name = $c->req->param('breeding_program');
    my $organization = $c->req->param('organization');
    my $population = $c->req->param('population');
    my $location = $c->req->param('location');
    my $box_name = $c->req->param('box_name');
    my $quality = $c->req->param('quality');
    my $accession_uniquename = $c->req->param('accession');
    my $cross_uniquename = $c->req->param('cross');
    my $schema = $c->stash->{schema};
    my $breeding_program = $schema->resultset('Project::Project')->find({name=>$breeding_program_name});
    if (!$breeding_program){
        $c->stash->{rest} = { error => "The breeding program $breeding_program_name does not exist in the database. Please add it first or choose another." };
        $c->detach();
    }
    my $breeding_program_id = $breeding_program->project_id();

    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $seedlot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'seedlot', 'stock_type')->cvterm_id();
    my $cross_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'cross', 'stock_type')->cvterm_id();

    if ($saved_seedlot_name ne $seedlot_name){
       #make sure the seedlot name is unique across the entire stock table
        my $previous_seedlot = $schema->resultset('Stock::Stock')->find({uniquename=>$seedlot_name }); #type_id=>$seedlot_cvterm_id});
        if ($previous_seedlot){
            $c->stash->{rest} = {error=>'The given seedlot uniquename has been taken. Please use another name or use the existing seedlot.'};
            $c->detach();
        }
    }
    my $accession_id;
    if ($accession_uniquename){
        $accession_id = $schema->resultset('Stock::Stock')->find({uniquename=>$accession_uniquename, type_id=>$accession_cvterm_id})->stock_id();
    }
    my $cross_id;
    if ($cross_uniquename){
        $cross_id = $schema->resultset('Stock::Stock')->find({uniquename=>$cross_uniquename, type_id=>$cross_cvterm_id})->stock_id();
    }
    if ($accession_uniquename && !$accession_id){
        $c->stash->{rest} = {error=>'The given accession name is not in the database! Seedlots can only be added onto existing accessions.'};
        $c->detach();
    }
    if ($cross_uniquename && !$cross_id){
        $c->stash->{rest} = {error=>'The given cross name is not in the database! Seedlots can only be added onto existing crosses.'};
        $c->detach();
    }
    if ($accession_id && $cross_id){
        $c->stash->{rest} = {error=>'A seedlot must have either an accession OR a cross as contents. Not both.'};
        $c->detach();
    }
    if (!$accession_id && !$cross_id){
        $c->stash->{rest} = {error=>'A seedlot must have either an accession or a cross as contents.'};
        $c->detach();
    }

    $seedlot->name($seedlot_name);
    $seedlot->uniquename($seedlot_name);
    $seedlot->description($description);
    $seedlot->breeding_program_id($breeding_program_id);
    $seedlot->organization_name($organization);
    $seedlot->location_code($location);
    $seedlot->box_name($box_name);
    $seedlot->quality($quality);
    $seedlot->accession_stock_id($accession_id);
    $seedlot->cross_stock_id($cross_id);
    $seedlot->population_name($population);
    my $return = $seedlot->store();
    if (exists($return->{error})){
        $c->stash->{rest} = { error => $return->{error} };
    } else {
        $c->stash->{rest} = { success => 1 };
    }
}

sub seedlot_delete :Chained('seedlot_base') PathPart('delete') Args(0) {
    my $self = shift;
    my $c = shift;

    if (!$c->user()){
        $c->stash->{rest} = { error => "You must be logged in the delete seedlots" };
        $c->detach();
    }
    if (!$c->user()->check_roles("curator")) {
        $c->stash->{rest} = { error => "You do not have the correct role to delete seedlots. Please contact us." };
        $c->detach();
    }

    my $error = $c->stash->{seedlot}->delete();
    if (!$error){
        $c->stash->{rest} = { success => 1 };
    }
    else {
        $c->stash->{rest} = { error => $error };
    }
}

sub seedlot_verify_delete_by_list :Path('/ajax/seedlots/verify_delete_by_list') Args(0) {
    my $self = shift;
    my $c = shift;

    my $list_id = $c->req->param("list_id");

    if (!$c->user()){
        $c->stash->{rest} = { error => "You must be logged in the delete seedlots" };
        $c->detach();
    }
    if (!$c->user()->check_roles("curator")) {
        $c->stash->{rest} = { error => "You do not have the correct role to delete seedlots. Please contact us." };
        $c->detach();
    }

    print STDERR "DELETE VERIFY USING LIST!\n";

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my ($ok, $errors) = CXGN::Stock::Seedlot->delete_verify_using_list($schema, $phenome_schema, $list_id);

    $c->stash->{rest} = { errors => \@$errors, ok => \@$ok };

}

sub seedlot_confirm_delete_by_list :Path('/ajax/seedlots/confirm_delete_by_list') Args(0) {
    my $self = shift;
    my $c = shift;

    my $list_id = $c->req->param("list_id");

    if (!$c->user()){
        $c->stash->{rest} = { error => "You must be logged in the delete seedlots" };
        $c->detach();
    }
    if (!$c->user()->check_roles("curator")) {
        $c->stash->{rest} = { error => "You do not have the correct role to delete seedlots. Please contact us." };
        $c->detach();
    }

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my ($total_count, $delete_count, $errors) = CXGN::Stock::Seedlot->delete_using_list($schema, $phenome_schema, $list_id);

    if (@$errors) {
	$c->stash->{rest} = { error => join("\n", @$errors), total_count => $total_count, delete_count => $delete_count }
    }
    else {
	$c->stash->{rest} = { success => 1, total_count => $total_count, delete_count => $delete_count };
    }
}



sub create_seedlot :Path('/ajax/breeders/seedlot-create/') :Args(0) {
    my $self = shift;
    my $c = shift;
    if (!$c->user){
        $c->stash->{rest} = {error=>'You must be logged in to add a seedlot transaction!'};
        $c->detach();
    }

    #if (!($c->user()->check_roles('curator') || $c->user()->check_roles('submitter'))) {
    #    $c->stash->{rest} = { error => "You do not have the correct submitter or curator role to add seedlots. Please contact us." };
    #    $c->detach();
    #}

    if ($c->stash->{access}->denied( $c->stash->{user_id}, "write", "stocks")) {
	$c->stash->{rest} = { error => "You do not have the correct privileges to add seedlots." };
	$c->detach();
    }
    
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $seedlot_uniquename = $c->req->param("seedlot_name");
    my $location_code = $c->req->param("seedlot_location");
    my $box_name = $c->req->param("seedlot_box_name");
    my $accession_uniquename = $c->req->param("seedlot_accession_uniquename");
    my $cross_uniquename = $c->req->param("seedlot_cross_uniquename");
    my $seedlot_source = $c->req->param("seedlot_source") || $c->req->param("seedlot_plot_uniquename") || $c->req->param("origin_seedlot_uniquename");
    my $seedlot_quality = $c->req->param("seedlot_quality");
    my $description = $c->req->param("seedlot_description");
    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $seedlot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'seedlot', 'stock_type')->cvterm_id();
    my $cross_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'cross', 'stock_type')->cvterm_id();
    my $plot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id();
    my $subplot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'subplot', 'stock_type')->cvterm_id();
    my $plant_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant', 'stock_type')->cvterm_id();
    my $no_refresh = $c->req->param("no_refresh");

    my $previous_seedlot = $schema->resultset('Stock::Stock')->find({uniquename=>$seedlot_uniquename }); #type_id=>$seedlot_cvterm_id});
    if ($previous_seedlot){
        $c->stash->{rest} = {error=>'The given seedlot uniquename has been taken. Please use another name or use the existing seedlot.'};
        $c->detach();
    }
    my $accession_id;
    if ($accession_uniquename){
        # In case of synonyms, use stocklookup
        my $stock_lookup = CXGN::Stock::StockLookup->new({ schema => $schema, stock_name=>$accession_uniquename });
        my $stock_lookup_rs = $stock_lookup->get_stock($accession_cvterm_id);
        if (!$stock_lookup_rs){
            $c->stash->{rest} = {error=>'The accession name you provided does not match to a unique accession. Please make sure you are using the correct name or contact us.'};
            $c->detach();
        }
        $accession_id = $stock_lookup_rs->stock_id();
        $accession_uniquename = $stock_lookup_rs->uniquename();
    }
    my $cross_id;
    if ($cross_uniquename){
        my $rs = $schema->resultset('Stock::Stock')->find({uniquename=>$cross_uniquename, type_id=>$cross_cvterm_id});
        if (!$rs){
            $c->stash->{rest} = {error=>'The cross name you provided does not match an existing cross name in the database.  Please make sure you are using the correct name or contact us.'};
            $c->detach();
        }
        $cross_id = $rs->stock_id();
    }
    my $source_id;
    my $source_is_seedlot = 0;
    if ($seedlot_source) {
        my $rs = $schema->resultset('Stock::Stock')->find({uniquename=>$seedlot_source, type_id => { -in => [ $seedlot_cvterm_id, $plot_cvterm_id, $subplot_cvterm_id, $plant_cvterm_id ] }});
        if ( !$rs ) {
            $c->stash->{rest} = {error=>'The given seedlot source name does not match an existing entry in the database. Seedlot sources must be an existing seedlot, plot, subplot, or plant name.'};
            $c->detach();
        }
        $source_id = $rs->stock_id();
        my $type_id = $rs->type_id();

        # Check the contents of the source seedlot against the new seedlots contents
        if ( $type_id eq $seedlot_cvterm_id ) {
            $source_is_seedlot = 1;
            my $source_seedlot = CXGN::Stock::Seedlot->new(schema => $schema, seedlot_id => $source_id);
            my $source_accession_name = $source_seedlot->accession() ? $source_seedlot->accession()->[1] : undef;
            my $source_cross_name = $source_seedlot->cross() ? $source_seedlot->cross()->[1] : undef;
            if ( $accession_uniquename && $accession_uniquename ne $source_accession_name ) {
                    $c->stash->{rest} = { error => "The source seedlot contents accession ($source_accession_name) does not match the new seedlot contents accession ($accession_uniquename)." };
                    $c->detach();
            }
            elsif ( $cross_uniquename && $cross_uniquename ne $source_cross_name ) {
                    $c->stash->{rest} = { error => "The source seedlot contents cross ($source_cross_name) does not match the new seedlot contents cross ($cross_uniquename)." };
                    $c->detach();
            }
        }

        # Check the seedlot accession or cross against the source plot / subplot / plant accession or cross
        elsif ( $type_id eq $plot_cvterm_id || $type_id eq $subplot_cvterm_id || $type_id eq $plant_cvterm_id ) {
            my $trial_related_stock = CXGN::Stock::RelatedStocks->new({dbic_schema => $schema, stock_id => $source_id});
            my $result = $trial_related_stock->get_trial_related_stock();
            my $source_stock_name;
            my $source_stock_type;
            foreach my $s (@$result) {
                my $t = $s->[2];
                my $n = $s->[1];
                if ( $t eq 'accession' ) {
                    $source_stock_type = 'accession';
                    $source_stock_name = $n;
                }
                elsif ( $t eq 'cross' ) {
                    $source_stock_type = 'cross';
                    $source_stock_name = $n;
                }
            }
            if ( $source_stock_type eq 'accession' ) {
                if ( $accession_uniquename ne $source_stock_name ) {
                    $c->stash->{rest} = { error => "The source stock accession ($source_stock_name) does not match the seedlot contents accession ($accession_uniquename)." };
                    $c->detach();
                }
            }
            elsif ( $source_stock_type eq 'cross' ) {
                if ( $cross_uniquename ne $source_stock_name ) {
                    $c->stash->{rest} = { error => "The source stock cross ($source_stock_name) does not match the seedlot contents cross ($cross_uniquename)." };
                    $c->detach();
                }
            }
            else {
                $c->stash->{rest} = { error => "Could not check seedlot source due to undefined source stock type" };
                $c->detach();
            }
        }

        else {
            $c->stash->{rest} = {error => 'Unsupported seedlot source type'};
            $c->detach();
        }
    }
    if ($accession_uniquename && !$accession_id){
        $c->stash->{rest} = {error=>'The given accession name is not in the database! Seedlots can only be added onto existing accessions.'};
        $c->detach();
    }
    if ($cross_uniquename && !$cross_id){
        $c->stash->{rest} = {error=>'The given cross name is not in the database! Seedlots can only be added onto existing crosses.'};
        $c->detach();
    }
    if ($accession_id && $cross_id){
        $c->stash->{rest} = {error=>'A seedlot must have either an accession OR a cross as contents. Not both.'};
        $c->detach();
    }
    if (!$accession_id && !$cross_id){
        $c->stash->{rest} = {error=>'A seedlot must have either an accession or a cross as contents.'};
        $c->detach();
    }

    my $from_stock_id = $source_id ? $source_id : $accession_id ? $accession_id : $cross_id;
    my $from_stock_uniquename = $seedlot_source ? $seedlot_source : $accession_uniquename ? $accession_uniquename : $cross_uniquename;
    my $population_name = $c->req->param("seedlot_population_name");
    my $organization = $c->req->param("seedlot_organization");
    my $amount = $c->req->param("seedlot_amount");
    my $weight = $c->req->param("seedlot_weight");
    my $timestamp = $c->req->param("seedlot_timestamp");
    my $transaction_description = $c->req->param("seedlot_transaction_description");
    my $breeding_program_id = $c->req->param("seedlot_breeding_program_id");

    if (!$timestamp){
        $c->stash->{rest} = {error=>'A seedlot must have a timestamp for the transaction.'};
        $c->detach();
    }

    if (!$breeding_program_id){
        $c->stash->{rest} = {error=>'A seedlot must have a breeding program.'};
        $c->detach();
    }

    my $operator;
    if ($c->user) {
        $operator = $c->user->get_object->get_username;
    }
    my $user_id = $c->user()->get_object()->get_sp_person_id();

    my $seedlot_id;

    eval {
        my $sl = CXGN::Stock::Seedlot->new(schema => $schema);
        $sl->uniquename($seedlot_uniquename);
        $sl->description($description);
        $sl->location_code($location_code);
        $sl->box_name($box_name);
        $sl->accession_stock_id($accession_id);
        $sl->cross_stock_id($cross_id);
        $sl->organization_name($organization);
        $sl->population_name($population_name);
        $sl->breeding_program_id($breeding_program_id);
	    $sl->quality($seedlot_quality);
        my $return = $sl->store();
        my $seedlot_id = $return->{seedlot_id};

        my $transaction = CXGN::Stock::Seedlot::Transaction->new(schema => $schema);
        $transaction->factor(1);
        $transaction->from_stock([$from_stock_id, $from_stock_uniquename]);
        $transaction->to_stock([$seedlot_id, $seedlot_uniquename]);
        if (defined($amount) && length($amount)){
            $transaction->amount($amount);
        } else {
            $transaction->amount('NA');
        }
        if (defined($weight) && length($weight)){
            $transaction->weight_gram($weight);
        } else {
            $transaction->weight_gram('NA');
        }
        $transaction->timestamp($timestamp);
        $transaction->description($transaction_description);
        $transaction->operator($operator);
        $transaction->store();

        my $sl_new = CXGN::Stock::Seedlot->new(schema => $schema, seedlot_id=>$seedlot_id);
        $sl_new->set_current_count_property();
        $sl_new->set_current_weight_property();

        if ( $source_is_seedlot ) {
            my $sl_origin = CXGN::Stock::Seedlot->new(schema => $schema, seedlot_id => $source_id);
            $sl_origin->set_current_count_property();
            $sl_origin->set_current_weight_property();
        }

        $phenome_schema->resultset("StockOwner")->find_or_create({
            stock_id     => $seedlot_id,
            sp_person_id =>  $user_id,
        });
    };

    if ($@) {
	$c->stash->{rest} = { success => 0, seedlot_id => 0, error => $@ };
	print STDERR "An error condition occurred, was not able to create seedlot. ($@).\n";
	return;
    }

    if ( $no_refresh ne 1 ) {
        my $dbh = $c->dbc->dbh();
        my $bs = CXGN::BreederSearch->new( { dbh=>$dbh, dbname=>$c->config->{dbname}, } );
        my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'stockprop', 'concurrent', $c->config->{basepath});
    }

    $c->stash->{rest} = { success => 1, seedlot_id => $seedlot_id };
}


sub upload_seedlots : Path('/ajax/breeders/seedlot-upload/') : ActionClass('REST') { }

sub upload_seedlots_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $user_id;
    my $user_name;
    my $user_role;
    my $session_id = $c->req->param("sgn_session_id");

    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{rest} = {error=>'You must be logged in to upload seedlots!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else{
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to upload seedlots!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }

    #if (($user_role ne 'curator') && ($user_role ne 'submitter')) {
    if ($c->stash->{access}->denied( $c->stash->{user_id}, "write", "stocks")) { 
        $c->stash->{rest} = {error=>'You do not have the privileges to upload seedlots'};
        $c->detach();
    }

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $breeding_program_id = $c->req->param("upload_seedlot_breeding_program_id");
    my $location = $c->req->param("upload_seedlot_location");
    my $population = $c->req->param("upload_seedlot_population_name");
    my $organization = $c->req->param("upload_seedlot_organization_name");
    my $upload_from_accessions = $c->req->upload('seedlot_uploaded_file');
    my $upload_harvested_from_crosses = $c->req->upload('seedlot_harvested_uploaded_file');
    if (!$upload_from_accessions && !$upload_harvested_from_crosses){
        $c->stash->{rest} = {error=>'You must upload a seedlot file!'};
        $c->detach();
    }
    my $upload;
    my $parser_type;
    if ($upload_from_accessions){
        $upload = $upload_from_accessions;
        $parser_type = 'SeedlotFromAccessionGeneric';
    }
    if ($upload_harvested_from_crosses){
        $upload = $upload_harvested_from_crosses;
        $parser_type = 'SeedlotFromCrossGeneric';
    }

    my $subdirectory = "seedlot_upload";
    my $upload_original_name = $upload->filename();
    my $upload_tempfile = $upload->tempname;
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();

    ## Store uploaded temporary file in archive
    my $uploader = CXGN::UploadFile->new({
        tempfile => $upload_tempfile,
        subdirectory => $subdirectory,
        archive_path => $c->config->{archive_path},
        archive_filename => $upload_original_name,
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $user_role
    });
    my $archived_filename_with_path = $uploader->archive();
    my $md5 = $uploader->get_md5($archived_filename_with_path);
    if (!$archived_filename_with_path) {
        $c->stash->{rest} = {error => "Could not save file $upload_original_name in archive",};
        $c->detach();
    }
    unlink $upload_tempfile;
    my $parser = CXGN::Stock::Seedlot::ParseUpload->new(chado_schema => $schema, filename => $archived_filename_with_path);
    $parser->load_plugin($parser_type);
    my $parsed_data = $parser->parse();

    if (!$parsed_data) {
        my $return_error = '';
        my $parse_errors;
        if (!$parser->has_parse_errors() ){
            $c->stash->{rest} = {error_string => "Could not get parsing errors"};
        } else {
            $parse_errors = $parser->get_parse_errors();

            foreach my $error_string (@{$parse_errors->{'error_messages'}}){
                $return_error .= $error_string."<br>";
            }
        }
        $c->stash->{rest} = {error_string => $return_error, missing_accessions => $parse_errors->{'missing_accessions'}, missing_crosses => $parse_errors->{'missing_crosses'}};
        $c->detach();
    }

    my @added_stocks;
    eval {
        while (my ($key, $val) = each(%$parsed_data)){
            my $sl;

            # Check for accession stock id or cross stock id
            if ( !defined $val->{accession_stock_id} && !defined $val->{cross_stock_id} ) {
                print STDERR "--> ERROR: Acc/Cross Stock ID not defined!";
                die "ERROR: Could not store/update seedlot $key (The specified accession or cross does not exist).";
            }

            if (defined($val->{seedlot_id})){
                $sl = CXGN::Stock::Seedlot->new(schema => $schema, seedlot_id=>$val->{seedlot_id}); #this allows update of existing seedlot
            } else {
                $sl = CXGN::Stock::Seedlot->new(schema => $schema);
            }

            $sl->uniquename($key);
            $sl->location_code($location);
            $sl->box_name($val->{box_name});
            $sl->accession_stock_id($val->{accession_stock_id});
            $sl->cross_stock_id($val->{cross_stock_id});
            $sl->description($val->{description});
            $sl->organization_name($organization);
            $sl->population_name($population);
            $sl->breeding_program_id($breeding_program_id);
            $sl->quality($val->{quality});
            $sl->check_name_exists(0); #already validated
            my $return = $sl->store();
            if ( defined $return->{error} ) {
                print STDERR "SEEDLOT STORE ERROR:\n";
                print STDERR Dumper $return->{error};
                die "ERROR: Could not store/update seedlot $key (" . $return->{error} . ")";
            }
            my $seedlot_id = $return->{seedlot_id};

            my $from_stock_id;
            my $from_stock_name;
            if ($val->{accession_stock_id}){
                $from_stock_id = $val->{accession_stock_id};
                $from_stock_name = $val->{accession};
            }
            elsif ($val->{cross_stock_id}){
                $from_stock_id = $val->{cross_stock_id};
                $from_stock_name = $val->{cross_name};
            }

            if (!$from_stock_id || !$from_stock_name){
                die "ERROR: Could not store/update seedlot $key (An accession or cross must be given to make a seedlot transaction).";
            }

            # if an alternate source is given, use that, but only if there is an accession present, and
            # there is no cross.
            #
            if ($val->{source_id} && $val->{accession_stock_id} && !$val->{cross_stock_id}) {
                $from_stock_id = $val->{source_id};
                $from_stock_name = $val->{source_name};
            }

            my $transaction_amount;
            my $transaction_weight;
            # If seedlot already exists in database, the system will update so that the current weight and current count match what was uploaded.
            if (defined($val->{seedlot_id})){
                my $sl = CXGN::Stock::Seedlot->new(schema => $schema, seedlot_id => $val->{seedlot_id});
                my $current_stored_count = $sl->get_current_count_property() && $sl->get_current_count_property() ne 'NA' ? $sl->get_current_count_property() : 0;
                my $current_stored_weight = $sl->get_current_weight_property() && $sl->get_current_weight_property() ne 'NA' ? $sl->get_current_weight_property() : 0;

                $val->{description} .= " Info: Seedlot XLS upload update.";

                if ($val->{weight_gram} ne 'NA'){
                    my $weight_difference = $val->{weight_gram} - $current_stored_weight;
                    my $weight_factor;
                    if ($weight_difference >= 0){
                        $weight_factor = 1;
                    } else {
                        $weight_factor = -1;
                        $weight_difference = $weight_difference * -1; #Store positive values only
                    }
                    my $transaction = CXGN::Stock::Seedlot::Transaction->new(schema => $schema);
                    $transaction->from_stock([$seedlot_id, $key]);
                    $transaction->to_stock([$seedlot_id, $key]);
                    $transaction->weight_gram($weight_difference);
                    $transaction->timestamp($timestamp);
                    $transaction->description($val->{description});
                    $transaction->operator($val->{operator_name});
                    $transaction->factor($weight_factor);
                    $transaction->store();
                }

                if ($val->{amount} ne 'NA'){
                    my $amount_difference = $val->{amount} - $current_stored_count;
                    my $amount_factor;
                    if ($amount_difference >= 0){
                        $amount_factor = 1;
                    } else {
                        $amount_factor = -1;
                        $amount_difference = $amount_difference * -1; #Store positive values only
                    }
                    my $transaction = CXGN::Stock::Seedlot::Transaction->new(schema => $schema);
                    $transaction->from_stock([$seedlot_id, $key]);
                    $transaction->to_stock([$seedlot_id, $key]);
                    $transaction->amount($amount_difference);
                    $transaction->timestamp($timestamp);
                    $transaction->description($val->{description});
                    $transaction->operator($val->{operator_name});
                    $transaction->factor($amount_factor);
                    $transaction->store();
                }
            }
            # If this is not updating an existing seedlot, then it just the initial transaction
            else {
                my $transaction = CXGN::Stock::Seedlot::Transaction->new(schema => $schema);
                $transaction->factor(1);
                $transaction->from_stock([$from_stock_id, $from_stock_name]);
                $transaction->to_stock([$seedlot_id, $key]);
                $transaction->amount($val->{amount});
                $transaction->weight_gram($val->{weight_gram});
                $transaction->timestamp($timestamp);
                $transaction->description($val->{description});
                $transaction->operator($val->{operator_name});
                $transaction->store();
            }

            my $sl_new = CXGN::Stock::Seedlot->new(schema => $schema, seedlot_id=>$seedlot_id);
            $sl_new->set_current_count_property();
            $sl_new->set_current_weight_property();
            push @added_stocks, $seedlot_id;
        }
    };
    if ($@) {
        $c->stash->{rest} = { error => $@ };
        print STDERR "An error condition occurred, was not able to upload seedlots. ($@).\n";
        $c->detach();
    }

    foreach my $stock_id (@added_stocks) {
        $phenome_schema->resultset("StockOwner")->find_or_create({
            stock_id     => $stock_id,
            sp_person_id =>  $user_id,
        });
    }

    my $dbh = $c->dbc->dbh();
    my $bs = CXGN::BreederSearch->new( { dbh=>$dbh, dbname=>$c->config->{dbname}, } );
    my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'stockprop', 'concurrent', $c->config->{basepath});

    $c->stash->{rest} = { success => 1, added_seedlot => \@added_stocks  };
}

sub upload_seedlots_inventory : Path('/ajax/breeders/seedlot-inventory-upload/') : ActionClass('REST') { }
sub upload_seedlots_inventory_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $user_id;
    my $user_name;
    my $user_role;
    my $session_id = $c->req->param("sgn_session_id");

    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{rest} = {error=>'You must be logged in to upload seedlot inventory!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else{
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to upload seedlot inventory!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }

#    if (($user_role ne 'curator') && ($user_role ne 'submitter')) {
#        $c->stash->{rest} = {error=>'Only a submitter or a curator can upload seedlot inventory'};
#        $c->detach();
#    }

    if ($c->stash->{access}->denied( $c->stash->{user_id}, "write", "stocks")) { 
        $c->stash->{rest} = {error=>'You do not have the privileges to upload seedlots'};
        $c->detach();
    }

    
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $upload = $c->req->upload('seedlot_uploaded_inventory_file');
    my $subdirectory = "seedlot_upload";
    my $upload_original_name = $upload->filename();
    my $upload_tempfile = $upload->tempname;
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();

    ## Store uploaded temporary file in archive
    my $uploader = CXGN::UploadFile->new({
        tempfile => $upload_tempfile,
        subdirectory => $subdirectory,
        archive_path => $c->config->{archive_path},
        archive_filename => $upload_original_name,
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $user_role
    });
    my $archived_filename_with_path = $uploader->archive();
    my $md5 = $uploader->get_md5($archived_filename_with_path);
    if (!$archived_filename_with_path) {
        $c->stash->{rest} = {error => "Could not save file $upload_original_name in archive",};
        $c->detach();
    }
    unlink $upload_tempfile;
    my $parser = CXGN::Stock::Seedlot::ParseUpload->new(chado_schema => $schema, filename => $archived_filename_with_path);
    $parser->load_plugin('SeedlotInventoryCSV');
    my $parsed_data = $parser->parse();
    #print STDERR Dumper $parsed_data;

    if (!$parsed_data) {
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
        $c->stash->{rest} = {error_string => $return_error, missing_seedlots => $parse_errors->{'missing_seedlots'} };
        $c->detach();
    }

    eval {
        while (my ($key, $val) = each(%$parsed_data)){
            my $sl = CXGN::Stock::Seedlot->new(schema => $schema, seedlot_id => $val->{seedlot_id});
            $sl->box_name($val->{box_id});
            $sl->description($val->{description});

	    print STDERR "QUALITY: $val->{quality}\n";
	    $sl->quality($val->{quality});

            my $return = $sl->store();

	    my $current_stored_count = $sl->get_current_count_property();
            my $current_stored_weight = $sl->get_current_weight_property();

            my $weight_difference = $val->{weight_gram} - $current_stored_weight;
            my $factor;
            if ($weight_difference >= 0){
                $factor = 1;
            } else {
                $factor = -1;
                $weight_difference = $weight_difference * -1; #Store positive values only
            }

            my $transaction = CXGN::Stock::Seedlot::Transaction->new(schema => $schema);
            $transaction->factor($factor);

	    my $from_stock_id = $val->{seedlot_id};
	    my $from_stock_name = $val->{seedlot_name};

	    if ($val->{source_id}) {
		$from_stock_id = $val->{source_id};
		$from_stock_name = $val->{source};
	    }

            $transaction->from_stock([ $from_stock_id, $from_stock_name ]);
            $transaction->to_stock([$val->{seedlot_id}, $val->{seedlot_name}]);
            $transaction->weight_gram($weight_difference);
            $transaction->timestamp($val->{inventory_date});
            $transaction->description('Seed inventory CSV upload.');
            $transaction->operator($val->{inventory_person});
            $transaction->store();

            my $sl_new = CXGN::Stock::Seedlot->new(schema => $schema, seedlot_id => $val->{seedlot_id});
            $sl_new->set_current_count_property();
            $sl_new->set_current_weight_property();
        }
    };
    if ($@) {
        $c->stash->{rest} = { error => $@ };
        print STDERR "An error condition occurred, was not able to upload seedlots inventory. ($@).\n";
        $c->detach();
    }

    my $dbh = $c->dbc->dbh();
    my $bs = CXGN::BreederSearch->new( { dbh=>$dbh, dbname=>$c->config->{dbname}, } );
    my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'stockprop', 'concurrent', $c->config->{basepath});

    $c->stash->{rest} = { success => 1 };
}



sub seedlot_transaction_base :Chained('seedlot_base') PathPart('transaction') CaptureArgs(1) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $seedlot_id = $c->stash->{seedlot}->seedlot_id();
    my $transaction_id = shift;
    my $t_obj = CXGN::Stock::Seedlot::Transaction->new(schema=>$schema, transaction_id=>$transaction_id, seedlot_id=>$seedlot_id);
    $c->stash->{transaction_id} = $transaction_id;
    $c->stash->{transaction_object} = $t_obj;
}

sub seedlot_transaction_details :Chained('seedlot_transaction_base') PathPart('') Args(0) {
    my $self = shift;
    my $c = shift;
    my $t = $c->stash->{transaction_object};
    my $factor = $t->factor;
    my $transaction_type;
    if ($factor == 1) {
        $transaction_type = 'added to this seedlot';
    } elsif ($factor == -1) {
        $transaction_type = 'removed from this seedlot';
    }

    $c->stash->{rest} = {
        success => 1,
        transaction_id => $t->transaction_id,
        description=>$t->description,
        amount=>$t->amount,
        weight_gram=>$t->weight_gram,
        operator=>$t->operator,
        timestamp=>$t->timestamp,
        factor=>$t->factor,
        transaction_type=>$transaction_type
    };
}

sub edit_seedlot_transaction :Chained('seedlot_transaction_base') PathPart('edit') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    if (!$c->user()){
        $c->stash->{rest} = { error => "You must be logged in to edit seedlot transactions" };
        $c->detach();
    }
    if (!$c->user()->check_roles("curator")) {
        $c->stash->{rest} = { error => "You do not have the correct role to edit seedlot transactions. Please contact us." };
        $c->detach();
    }

    my $t = $c->stash->{transaction_object};
    my $from_stock = $t->from_stock();
    my $from_stock_id = $from_stock->[0];
    my $from_stock_type = $from_stock->[2];
    my $to_stock = $t->to_stock();
    my $to_stock_id = $to_stock->[0];
    my $to_stock_type = $to_stock->[2];

    my $edit_operator = $c->req->param('operator');
    my $edit_amount = $c->req->param('amount');
    my $edit_weight = $c->req->param('weight_gram');
    my $edit_desc = $c->req->param('description');
    my $edit_timestamp = $c->req->param('timestamp');
    $t->operator($edit_operator);
    $t->amount($edit_amount);
    $t->weight_gram($edit_weight);
    $t->description($edit_desc);
    $t->timestamp($edit_timestamp);
    my $transaction_id = $t->store();

    my $seedlot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'seedlot', 'stock_type')->cvterm_id();

    if ($from_stock_type == $seedlot_cvterm_id) {
        my $from_stock_update = CXGN::Stock::Seedlot->new(schema => $schema, seedlot_id => $from_stock_id);
        $from_stock_update->set_current_count_property();
        $from_stock_update->set_current_weight_property();
    }

    if ($to_stock_type == $seedlot_cvterm_id) {
        my $to_stock_update = CXGN::Stock::Seedlot->new(schema => $schema, seedlot_id => $to_stock_id);
        $to_stock_update->set_current_count_property();
        $to_stock_update->set_current_weight_property();
    }

    if ($transaction_id){
        my $dbh = $c->dbc->dbh();
        my $bs = CXGN::BreederSearch->new( { dbh=>$dbh, dbname=>$c->config->{dbname}, } );
        my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'stockprop', 'concurrent', $c->config->{basepath});

        $c->stash->{rest} = { success => 1 };
    } else {
        $c->stash->{rest} = { error => "Something went wrong with the transaction update" };
    }
}

sub list_seedlot_transactions :Chained('seedlot_base') :PathPart('transactions') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $transactions = $c->stash->{seedlot}->transactions();
    my $type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "seedlot", "stock_type")->cvterm_id();
    my $cross_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "cross", "stock_type")->cvterm_id();
    my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "accession", "stock_type")->cvterm_id();
    my $plot_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "plot", "stock_type")->cvterm_id();
    my $subplot_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "subplot", "stock_type")->cvterm_id();
    my $plant_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "plant", "stock_type")->cvterm_id();
    my %types_hash = ( $type_id => 'seedlot', $accession_type_id => 'accession', $plot_type_id => 'plot', $subplot_type_id => 'subplot', $plant_type_id => 'plant', $cross_type_id => 'cross' );

    #print STDERR Dumper $transactions;
    my @transactions;
    foreach my $t (@$transactions) {
        my $value_field = '';
        if ($t->factor == 1 && $t->amount() ne 'NA'){
            $value_field = '<span style="color:green">+'.$t->factor()*$t->amount().'</span>';
        }
        if ($t->factor == -1 && $t->amount() ne 'NA'){
            $value_field = '<span style="color:red">'.$t->factor()*$t->amount().'</span>';
        }
        if ($t->amount() eq 'NA'){
            $value_field = $t->amount;
        }
        my $weight_value_field = '';
        if ($t->factor == 1 && $t->weight_gram() ne 'NA'){
            $weight_value_field = '<span style="color:green">+'.$t->factor()*$t->weight_gram().'</span>';
        }
        if ($t->factor == -1 && $t->weight_gram() ne 'NA'){
            $weight_value_field = '<span style="color:red">'.$t->factor()*$t->weight_gram().'</span>';
        }
        if ($t->weight_gram() eq 'NA'){
            $weight_value_field = $t->weight_gram;
        }
        my $from_url;
        my $to_url;
        if ($t->from_stock()->[2] == $type_id){
            $from_url = '<a href="/breeders/seedlot/'.$t->from_stock()->[0].'" >'.$t->from_stock()->[1].'</a> ('.$types_hash{$t->from_stock()->[2]}.')';
        } elsif ($t->from_stock()->[2] == $cross_type_id){
            $from_url = '<a href="/cross/'.$t->from_stock()->[0].'" >'.$t->from_stock()->[1].'</a> ('.$types_hash{$t->from_stock()->[2]}.')';
        } else {
            $from_url = '<a href="/stock/'.$t->from_stock()->[0].'/view" >'.$t->from_stock()->[1].'</a> ('.$types_hash{$t->from_stock()->[2]}.')';
        }

        if ($t->from_stock()->[0] == $t->to_stock()->[0]) {
            $to_url = 'NA';
        } else {
            if ($t->to_stock()->[2] == $type_id){
                $to_url = '<a href="/breeders/seedlot/'.$t->to_stock()->[0].'" >'.$t->to_stock()->[1].'</a> ('.$types_hash{$t->to_stock()->[2]}.')';
            } elsif ($t->from_stock()->[2] == $cross_type_id){
                $to_url = '<a href="/cross/'.$t->to_stock()->[0].'" >'.$t->to_stock()->[1].'</a> ('.$types_hash{$t->to_stock()->[2]}.')';
            } else {
                $to_url = '<a href="/stock/'.$t->to_stock()->[0].'/view" >'.$t->to_stock()->[1].'</a> ('.$types_hash{$t->to_stock()->[2]}.')';
            }
        }
        push @transactions, { "transaction_id"=>$t->transaction_id(), "timestamp"=>$t->timestamp(), "from"=>$from_url, "to"=>$to_url, "value"=>$value_field, "weight"=>$weight_value_field, "operator"=>$t->operator, "description"=>$t->description() };
    }

    $c->stash->{rest} = { data => \@transactions };
}

sub add_seedlot_transaction :Chained('seedlot_base') :PathPart('transaction/add') :Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");

    if (!$c->user){
        $c->stash->{rest} = {error=>'You must be logged in to add a seedlot transaction!'};
        $c->detach();
    }

#    if (!($c->user()->check_roles('curator') || $c->user()->check_roles('submitter'))) {
#        $c->stash->{rest} = { error => 'Only a submitter or a curator can add seedlot transaction' };
#        $c->detach();
#    }

    if ($c->stash->{access}->denied( $c->stash->{user_id}, "write", "stocks")) { 
        $c->stash->{rest} = {error=>'You do not have the privileges to upload seedlots'};
        $c->detach();
    }

    my $operator = $c->user->get_object->get_username;
    my $user_id = $c->user->get_object->get_sp_person_id;

    my $to_new_seedlot_name = $c->req->param('to_new_seedlot_name');
    my $stock_id;
    my $stock_uniquename;
    my $new_sl;
    if ($to_new_seedlot_name){
        $stock_uniquename = $to_new_seedlot_name;
        eval {
            my $location_code = $c->req->param('to_new_seedlot_location_name');
            my $box_name = $c->req->param('to_new_seedlot_box_name');
            my $accession_uniquename = $c->req->param('to_new_seedlot_accession_name');
            my $cross_uniquename = $c->req->param('to_new_seedlot_cross_name');
            my $organization = $c->req->param('to_new_seedlot_organization');
            my $population_name = $c->req->param('to_new_seedlot_population_name');
            my $breeding_program_id = $c->req->param('to_new_seedlot_breeding_program_id');
            my $amount = $c->req->param('to_new_seedlot_amount');
            my $weight = $c->req->param('to_new_seedlot_weight');
            my $timestamp = $c->req->param('to_new_seedlot_timestamp');
            my $transaction_description = $c->req->param('to_new_seedlot_transaction_description');
            my $description = $c->req->param('to_new_seedlot_description');

            my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
            my $seedlot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'seedlot', 'stock_type')->cvterm_id();
            my $cross_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'cross', 'stock_type')->cvterm_id();

            my $previous_seedlot = $schema->resultset('Stock::Stock')->find({uniquename=>$stock_uniquename, type_id=>$seedlot_cvterm_id});
            if ($previous_seedlot){
                $c->stash->{rest} = {error=>'The given seedlot uniquename has been taken. Please use another name or use the existing seedlot.'};
                $c->detach();
            }
            my $accession_id;
            if ($accession_uniquename){
                $accession_id = $schema->resultset('Stock::Stock')->find({uniquename=>$accession_uniquename, type_id=>$accession_cvterm_id})->stock_id();
            }
            my $cross_id;
            if ($cross_uniquename){
                $cross_id = $schema->resultset('Stock::Stock')->find({uniquename=>$cross_uniquename, type_id=>$cross_cvterm_id})->stock_id();
            }
            if ($accession_uniquename && !$accession_id){
                $c->stash->{rest} = {error=>'The given accession name is not in the database! Seedlots can only be added onto existing accessions.'};
                $c->detach();
            }
            if ($cross_uniquename && !$cross_id){
                $c->stash->{rest} = {error=>'The given cross name is not in the database! Seedlots can only be added onto existing crosses.'};
                $c->detach();
            }
            if ($accession_id && $cross_id){
                $c->stash->{rest} = {error=>'A seedlot must have either an accession OR a cross as contents. Not both.'};
                $c->detach();
            }
            if (!$accession_id && !$cross_id){
                $c->stash->{rest} = {error=>'A seedlot must have either an accession or a cross as contents.'};
                $c->detach();
            }

            my $sl = CXGN::Stock::Seedlot->new(schema => $schema);
            $sl->uniquename($to_new_seedlot_name);
            $sl->location_code($location_code);
            $sl->box_name($box_name);
            $sl->description($description);
            $sl->accession_stock_id($accession_id);
            $sl->cross_stock_id($cross_id);
            $sl->organization_name($organization);
            $sl->population_name($population_name);
            $sl->breeding_program_id($breeding_program_id);
            #TO DO
            #$sl->cross_id($cross_id);
            my $return = $sl->store();
            my $seedlot_id = $return->{seedlot_id};
            $stock_id = $seedlot_id;

            my $from_stock_name = $accession_uniquename ? $accession_uniquename : $cross_uniquename;
            my $from_stock_id = $accession_id ? $accession_id : $cross_id;
            my $transaction = CXGN::Stock::Seedlot::Transaction->new(schema => $schema);
            $transaction->factor(1);
            $transaction->from_stock([$from_stock_id, $from_stock_name]);
            $transaction->to_stock([$seedlot_id, $to_new_seedlot_name]);
            $transaction->amount($amount);
            $transaction->weight_gram($weight);
            $transaction->timestamp($timestamp);
            $transaction->description($transaction_description);
            $transaction->operator($operator);
            $transaction->store();

            my $sl_new = CXGN::Stock::Seedlot->new(schema => $schema, seedlot_id=>$seedlot_id);
            $new_sl = $sl_new;

            $phenome_schema->resultset("StockOwner")->find_or_create({
                stock_id     => $seedlot_id,
                sp_person_id =>  $user_id,
            });
        };

        if ($@) {
            $c->stash->{rest} = { success => 0, seedlot_id => 0, error => $@ };
            print STDERR "An error condition occurred, was not able to create new seedlot. ($@).\n";
            $c->detach();
        }
    }
    my $existing_sl;
    my $from_existing_seedlot_id = $c->req->param('from_existing_seedlot_id');
    if ($from_existing_seedlot_id){
        $stock_id = $from_existing_seedlot_id;
        $stock_uniquename = $schema->resultset('Stock::Stock')->find({stock_id=>$stock_id})->uniquename();
        $existing_sl = CXGN::Stock::Seedlot->new(
            schema => $c->stash->{schema},
            seedlot_id => $stock_id,
        );
    }
    my $to_existing_seedlot_id = $c->req->param('to_existing_seedlot_id');
    if ($to_existing_seedlot_id){
        $stock_id = $to_existing_seedlot_id;
        $stock_uniquename = $schema->resultset('Stock::Stock')->find({stock_id=>$stock_id})->uniquename();
        $existing_sl = CXGN::Stock::Seedlot->new(
            schema => $c->stash->{schema},
            seedlot_id => $stock_id,
        );
    }

    my $amount = $c->req->param("amount");
    my $weight = $c->req->param("weight");
    my $timestamp = $c->req->param("timestamp");
    my $description = $c->req->param("transaction_description");
    my $factor = $c->req->param("factor");
    my $transaction = CXGN::Stock::Seedlot::Transaction->new(schema => $c->stash->{schema});
    $transaction->factor($factor);
    if ($factor == 1){
        $transaction->from_stock([$stock_id, $stock_uniquename]);
        $transaction->to_stock([$c->stash->{seedlot_id}, $c->stash->{uniquename}]);
    } elsif ($factor == -1){
        $transaction->to_stock([$stock_id, $stock_uniquename]);
        $transaction->from_stock([$c->stash->{seedlot_id}, $c->stash->{uniquename}]);
    } else {
        die "factor not specified!\n";
    }
    $transaction->amount($amount);
    $transaction->weight_gram($weight);
    $transaction->timestamp($timestamp);
    $transaction->description($description);
    $transaction->operator($c->user->get_object->get_username);
    my $transaction_id = $transaction->store();

    if ($new_sl){
        $new_sl->set_current_count_property();
        $new_sl->set_current_weight_property();
    }
    if ($existing_sl){
        $existing_sl->set_current_count_property();
        $existing_sl->set_current_weight_property();
    }
    $c->stash->{seedlot}->set_current_count_property();
    $c->stash->{seedlot}->set_current_weight_property();

    my $dbh = $c->dbc->dbh();
    my $bs = CXGN::BreederSearch->new( { dbh=>$dbh, dbname=>$c->config->{dbname}, } );
    my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'stockprop', 'concurrent', $c->config->{basepath});

    $c->stash->{rest} = { success => 1, transaction_id => $transaction_id };
}

sub delete_seedlot_transaction :Chained('seedlot_transaction_base') PathPart('delete') Args(0) {
#depends on CXGN/Stock/Seedlot/Transaction.pm: delete_transaction sub
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    if (!$c->user()){
        $c->stash->{rest} = { error => "You must be logged in to delete seedlot transactions" };
        $c->detach();
    }
    if (!$c->user()->check_roles("curator")) {
        $c->stash->{rest} = { error => "You do not have the correct role to delete seedlot transactions. Please contact us." };
        $c->detach();
    }

    my $t = $c->stash->{transaction_object};
    my $from_stock = $t->from_stock();
    my $from_stock_id = $from_stock->[0];
    my $from_stock_type = $from_stock->[2];
    my $to_stock = $t->to_stock();
    my $to_stock_id = $to_stock->[0];
    my $to_stock_type = $to_stock->[2];
    my $delete = $t->delete_transaction();

    my $seedlot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'seedlot', 'stock_type')->cvterm_id();

    if ($from_stock_type == $seedlot_cvterm_id) {
        my $from_stock_update = CXGN::Stock::Seedlot->new(schema => $schema, seedlot_id => $from_stock_id);
        $from_stock_update->set_current_count_property();
        $from_stock_update->set_current_weight_property();
    }

    if ($to_stock_type == $seedlot_cvterm_id) {
        my $to_stock_update = CXGN::Stock::Seedlot->new(schema => $schema, seedlot_id => $to_stock_id);
        $to_stock_update->set_current_count_property();
        $to_stock_update->set_current_weight_property();
    }

    if ($delete){
        my $dbh = $c->dbc->dbh();
        my $bs = CXGN::BreederSearch->new( { dbh=>$dbh, dbname=>$c->config->{dbname}, } );
        my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'stockprop', 'concurrent', $c->config->{basepath});
        $c->stash->{rest} = { success => 1 };
    }
    else {
        $c->stash->{rest} = { error => "An error occured deleting the seedlot transaction" };
    }
}

#
# SEEDLOT MAINTENANCE EVENTS
#

#
# Get the Seedlot Maintenance Event Ontology terms
#   - the first level are used as categories
#   - the second level are the actual events
#   - the third level, if present, are allowed values
# PATH: GET /ajax/breeders/seedlot/maintenance/ontology
# RETURNS:
#   ontology: an array of objects with the child cvterm informion, with the following keys:
#       - cvterm_id = id of the child cvterm
#       - name = name of the child cvterm
#       - definition = definition of the child cvterm
#       - children = children of the child cvterm
#       - accession = dbxref accession of the child cvterm
#
sub seedlot_maintenance_ontology : Path('/ajax/breeders/seedlot/maintenance/ontology') :Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $onto = CXGN::Onto->new({ schema => $schema });

    # Make sure ontology is set in the conf file
    if ( !defined $c->config->{seedlot_maintenance_event_ontology_root} || $c->config->{seedlot_maintenance_event_ontology_root} eq '' ) {
        $c->stash->{rest} = { error => 'Seedlot Maintenance Events are not enabled on this server!' };
        $c->detach();
    }

    # Get cvterm of root term
    my ($db_name, $accession) = split ":", $c->config->{seedlot_maintenance_event_ontology_root};
    my $db = $schema->resultset('General::Db')->search({ name => $db_name })->first();
    my $dbxref;
    $dbxref = $db->find_related('dbxrefs', { accession => $accession }) if $db;
    my $root_cvterm;
    $root_cvterm = $dbxref->cvterm if $dbxref;
    my $root_cvterm_id;
    $root_cvterm_id = $root_cvterm->cvterm_id if $root_cvterm;

    # Get children (recursively) of root cvterm
    my $ontology;
    $ontology = $onto->get_children($root_cvterm_id) if $root_cvterm_id;

    $c->stash->{rest} = { ontology => $ontology };
}


#
# Search Seedlot Maintenance Events that match specified filter criteria
# PATH: POST /ajax/breeders/seedlot/maintenance/search
# PARAMS:
#   filters: an array of filter properties, with the following keys:
#       - names: an array of seedlot names
#       - dates: an array of date filter properies:
#           - date: date in YYYY-MM-DD format
#           - comp: date comparison type ('=', '<=', '<', '>=', '>')
#       - types: an array of event type/value filter properties
#           - cvterm_id: cvterm_id of maintenance event type
#           - values: array of allowed values
#       - operators: an array of operator names
#   page = (optional) the page number of results to return
#   pageSize = (optional) the number of results per page to return
# RETURNS: the results metadata and the matching seedlot events:
#       - page: current page number
#       - maxPage: the number of the last page
#       - pageSize: (max) number of results per page
#       - total: total number of results
#       - results: an array of events that match the filter criteria, with the following keys:
#           - stock_id: the unique id of the seedlot
#           - uniquename: the unique name of the seedlot
#           - stockprop_id: the unique id of the maintenance event
#           - cvterm_id: id of seedlot maintenance event ontology term
#           - cvterm_name: name of seedlot maintenance event ontology term
#           - value: value of the seedlot maintenance event
#           - notes: additional notes/comments about the event
#           - operator: username of the person creating the event
#           - timestamp: timestamp string of when the event was created ('YYYY-MM-DD HH:MM:SS' format)
#
sub seedlot_maintenance_event_search : Path('/ajax/breeders/seedlot/maintenance/search') : ActionClass('REST') { }
sub seedlot_maintenance_event_search_POST {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");

    # Get filter parameters
    my $body = $c->request->data;
    my $filters = $body->{filters};
    my $page = $body->{page};
    my $pageSize = $body->{pageSize};

    # Get events
    my $m = CXGN::Stock::Seedlot::Maintenance->new({ bcs_schema => $schema });
    my $results = $m->filter_events($filters, $page, $pageSize);

    # Return events
    $c->stash->{rest} = $results;
}


#
# Find Seedlots with overdue events
# PATH: POST /ajax/breeders/seedlot/maintenance/overdue
# PARAMS:
#   seedlots = array of the names of seedlots to check
#   event = cvterm_id of maintenance event
#   date = find seedlots that have not had the specified event performed on or after this date (YYYY-MM-DD format)
# RETURNS: an array with the status of the requested seedlots:
#   seedlot = seedlot name
#   overdue = 1 if the seedlot is overdue
#   timestamp = timestamp of the last time the event was performed, if the seedlot is not overdue
#
sub seedlot_maintenance_event_overdue : Path('/ajax/breeders/seedlot/maintenance/overdue') : ActionClass('REST') { }
sub seedlot_maintenance_event_overdue_POST {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    # Get search parameters
    my $body = $c->request->data;
    my $seedlots = $body->{seedlots};
    my $event = $body->{event};
    my $date = $body->{date};

    # Find overdue events
    my $m = CXGN::Stock::Seedlot::Maintenance->new({ bcs_schema => $schema });
    my $results = $m->overdue_events($seedlots, $event, $date);

    # Return seedlots
    $c->stash->{rest} = { results => $results };
}



#
# List all of the Maintenance Events for the specified Seedlot
# PATH: GET /ajax/breeders/seedlot/{seedlot id}/maintenance
# QUERY PARAMS:
#   - page = (optional) the page number of results to return
#   - pageSize = (optional) the number of results per page to return
# RETURNS: the results metadata and the seedlot events of the specified seedlot
#       - page: current page number
#       - maxPage: the number of the last page
#       - pageSize: (max) number of results per page
#       - total: total number of results
#       - results: an array of seedlot events, with the following keys:
#           - stock_id: the unique id of the seedlot
#           - uniquename: the unique name of the seedlot
#           - stockprop_id: the unique id of the maintenance event
#           - cvterm_id: id of seedlot maintenance event ontology term
#           - cvterm_name: name of seedlot maintenance event ontology term
#           - value: value of the seedlot maintenance event
#           - notes: additional notes/comments about the event
#           - operator: username of the person creating the event
#           - timestamp: timestamp string of when the event was created ('YYYY-MM-DD HH:MM:SS' format)
#
sub seedlot_maintenance_events : Chained('seedlot_base') PathPart('maintenance') Args(0) : ActionClass('REST') { }
sub seedlot_maintenance_events_GET {
    my $self = shift;
    my $c = shift;
    my $page = $c->req->param('page');
    my $pageSize = $c->req->param('pageSize');
    my $seedlot = $c->stash->{seedlot};

    my $results = $seedlot->get_events($page, $pageSize);

    $c->stash->{rest} = $results;
}


#
# Add one or more Maintenance Events to the specified Seedlot
# PATH: POST /ajax/breeders/seedlot/{seedlot id}/maintenance
# PARAMS:
#   events: the events to store in the databsae, an array of objects with the following keys:
#       - cvterm_id: id of seedlot maintenance event ontology term
#       - value: value of the seedlot maintenance event
#       - notes: (optional) additional notes/comments about the event
#       - operator: (optional, default=username of user making request) username of the person creating the event
#       - timestamp: (optional, default=now) timestamp of when the event was created (YYYY-MM-DD HH:MM:SS format)
# RETURNS:
#   events: the processed events stored in the database, an array of objects with the following keys:
#       - stock_id: stock id of the seedlot
#       - stockprop_id: seedlot maintenance event id (stockprop_id)
#       - cvterm_id: id of seedlot maintenance event ontology term
#       - cvterm_name: name of seedlot maintenance event ontology term
#       - value: value of seedlot maintenance event
#       - notes: additional notes/comments about the event
#       - operator: username of the person creating the event
#       - timestamp: timestamp of when the event was created (YYYY-MM-DD HH:MM:SS format)
#
sub seedlot_maintenance_events_POST {
    my $self = shift;
    my $c = shift;
    my $seedlot = $c->stash->{seedlot};
    my $strp = DateTime::Format::Strptime->new(pattern => '%Y-%m-%d %H:%M:%S', time_zone => 'local');

    # Require user login
    if (!$c->user){
        $c->stash->{rest} = {error => 'You must be logged in to add a seedlot transaction!'};
        $c->detach();
    }

    # Get user information and check role
    #if (!($c->user()->check_roles('curator') || $c->user()->check_roles('submitter'))) {
    #    $c->stash->{rest} = { error => 'You do not have the required privileges to seedlot maintenance events.' };
    #    $c->detach();
    #}

    if ($c->stash->{access}->denied( $c->stash->{user_id}, "write", "stocks")) { 
        $c->stash->{rest} = {error=>'You do not have the privileges to manage seedlots maintenance events'};
        $c->detach();
    }

    # Get event parameters
    my $body = $c->request->data;
    my $events = $body->{events};
    if ( !defined $events || $events eq '' || ref $events ne 'ARRAY' ) {
        $c->stash->{rest} = {error => 'Event parameters not provided!'};
        $c->detach();
    }

    # Process each Event
    my @args = ();
    foreach my $event (@$events) {

        # Set operator
        my $operator = $event->{operator} || $c->user()->get_object()->get_username();

        # Set timestamp
        my $timestamp;
        if ( defined $event->{timestamp} && $event->{timestamp} ne '' ) {
            $timestamp = $event->{timestamp};
        }
        else {
            my $d = DateTime->now(time_zone => 'local');
            $timestamp = $d->strftime("%Y-%m-%d %H:%M:%S");
        }

        # Build event arguments
        my %arg = (
            cvterm_id => $event->{cvterm_id},
            value => $event->{value},
            notes => $event->{notes},
            operator => $operator,
            timestamp => $timestamp
        );

        # Add event to arguments list
        push(@args, \%arg)

    }

    # Store the events
    eval {
        my $processed_events = $seedlot->store_events(\@args);
        $c->stash->{rest} = { events => $processed_events };
    };
    if ($@) {
        $c->stash->{rest} = {error => "Could not store seedlot maintenance events [$@]!"};
        $c->detach();
    }
}


#
# Get the details of the single specified Maintenance Event from the specified Seedlot
# PATH: GET /ajax/breeders/seedlot/{seedlot id}/maintenance/{event id}
# RETURNS:
#   event: the details of the specified event, with the following keys:
#       - stock_id: the unique id of the seedlot
#       - uniquename: the unique name of the seedlot
#       - stockprop_id: seedlot maintenance event id (stockprop_id)
#       - cvterm_id: id of seedlot maintenance event ontology term
#       - cvterm_name: name of seedlot maintenance event ontology term
#       - value: value of seedlot maintenance event
#       - notes: additional notes/comments about the event
#       - operator: username of the person creating the event
#       - timestamp: timestamp of when the event was created (YYYY-MM-DD HH:MM:SS format)
#
sub seedlot_maintenance_event : Chained('seedlot_base') PathPart('maintenance') Args(1) : ActionClass('REST') { }
sub seedlot_maintenance_event_GET {
    my $self = shift;
    my $c = shift;
    my $event_id = shift;
    my $seedlot = $c->stash->{seedlot};

    my $event = $seedlot->get_event($event_id);
    $c->stash->{rest} = { event => $event };
}

#
# Delete the specified event from the database
# PATH: DELETE /ajax/breeders/seedlot/{seedlot id}/maintenance/{event id}
# RETURNS:
#   - success: 1 if successful, 0 if not
#   - error: error message if not successful
#
sub seedlot_maintenance_event_DELETE {
    my $self = shift;
    my $c = shift;
    my $event_id = shift;
    my $seedlot = $c->stash->{seedlot};

    eval {
        $seedlot->remove_event($event_id);
    };
    if ($@) {
        print STDERR "Could not delete seedlot maintenance event. ($@).\n";
        $c->stash->{rest} = { success => 0, error => $@ };
        $c->detach();
    }

    $c->stash->{rest} = { success => 1 };
}

#
# Upload and process an Excel file of Seedlot events
# PATH: POST /ajax/breeders/seedlot/maintenance/upload
# PARAMS:
#   - file: the Excel (.xls) file of Seedlot events to process and store
# RETURNS:
#   - success: 1, if the upload was successfully verified and stored
#   - error: the error message(s) of any encountered error(s)
#   - missing_seedlots: a list of Seedlot names not found in the database (need to be added first)
#   - missing_events: a list of event type names not found in the maintenance event ontology
#
sub seedlot_maintenance_event_upload : Path('/ajax/breeders/seedlot/maitenance/upload') : ActionClass('REST') { }
sub seedlot_maintenance_event_upload_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my @params = $c->req->params();
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");

    # Check Logged In Status
    if (!$c->user){
        $c->stash->{rest} = {error => 'You must be logged in to do this!'};
        $c->detach();
    }
    my $user_id = $c->user()->get_object()->get_sp_person_id();
    my $user_role = $c->user->get_object->get_user_type();
#    if ( $user_role ne 'submitter' && $user_role ne 'curator' ) {
#        $c->stash->{rest} = {error => 'You do not have permission in the database to do this! Please contact us.'};
#        $c->detach();
    #    }

    if ($c->stash->{access}->denied( $c->stash->{user_id}, "write", "stocks")) { 
	$c->stash->{rest} = {error => 'You do not have permission in the database to do this! Please contact us.'};
        $c->detach();
    }

    # Archive upload file
    my $upload = $c->req->upload('file');
    if ( !defined $upload || $upload eq '' ) {
        $c->stash->{rest} = {error => 'You must provide the upload file!'};
        $c->detach();
    }
    else {
        my $upload_original_name = $upload->filename();
        my $upload_tempfile = $upload->tempname;
        my $time = DateTime->now();
        my $timestamp = $time->ymd()."_".$time->hms();
        my $subdirectory = "seedlot_maintenance_events_upload";

        # Upload and Archive file
        my $uploader = CXGN::UploadFile->new({
            tempfile => $upload_tempfile,
            subdirectory => $subdirectory,
            archive_path => $c->config->{archive_path},
            archive_filename => $upload_original_name,
            timestamp => $timestamp,
            user_id => $user_id,
            user_role => $user_role
        });
        my $archived_filepath = $uploader->archive();
        if (!$archived_filepath) {
            $c->stash->{rest} = {error => "Could not save file $upload_original_name in archive",};
            $c->detach();
        }
        unlink $upload_tempfile;

        # Parse the file
        my $parser = CXGN::Stock::Seedlot::ParseUpload->new(
            chado_schema => $schema,
            filename => $archived_filepath,
            event_ontology_root => $c->config->{seedlot_maintenance_event_ontology_root}
        );
        $parser->load_plugin('SeedlotMaintenanceEventXLS');
        my $parsed_data = $parser->parse();

        # No parsed data returned...
        if (!$parsed_data) {
            if (!$parser->has_parse_errors()) {
                $c->stash->{rest} = { error => "An unknown error occurred" };
                $c->detach();
            }
            else {
                my $parse_errors = $parser->get_parse_errors();
                my $return_error = '';
                foreach my $error_string(@{$parse_errors->{'error_messages'}}) {
                    $return_error .= $error_string."<br>";
                }
                $c->stash->{rest} = {
                    error => $return_error,
                    missing_seedlots => $parse_errors->{'missing_seedlots'},
                    missing_events => $parse_errors->{'missing_events'}
                };
                $c->detach();
            }
        }

        # Store the Parsed Data
        eval {
            foreach my $seedlot_id (keys %$parsed_data) {
                my $events = $parsed_data->{$seedlot_id};
                my $seedlot = CXGN::Stock::Seedlot->new(schema => $schema, phenome_schema => $phenome_schema, seedlot_id => $seedlot_id);
                $seedlot->store_events($events);
            }
        };
        if ($@) {
            $c->stash->{rest} = { error => $@ };
            print STDERR "An error condition occurred, was not able to upload seedlot maintenance events. ($@).\n";
            $c->detach();
        }
    }

    $c->stash->{rest} = { success => 1 };
}


sub discard_seedlots : Path('/ajax/breeders/seedlot/discard') :Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $dbh = $c->dbc->dbh();
    my $seedlot_list_id = $c->req->param("seedlot_list_id");
    my $seedlot_name = $c->req->param("seedlot_name");
    my $discard_reason = $c->req->param("discard_reason");
    my @seedlots_to_discard;

    my $time = DateTime->now();
    my $discard_date = $time->ymd();

    if (!$c->user()){
        $c->stash->{rest} = { error_string => "You must be logged in to discard seedlot" };
        return;
    }
    if (!$c->user()->check_roles("curator")) {
        $c->stash->{rest} = { error_string => "You do not have the correct role to discard seedlot. Please contact us." };
        return;
    }

    my $user_id = $c->user()->get_object()->get_sp_person_id();

    if (defined $seedlot_list_id) {
        my $list = CXGN::List->new( { dbh=>$dbh, list_id=>$seedlot_list_id });
        my $seedlots = $list->elements();
        @seedlots_to_discard = @$seedlots;

        my $seedlot_validator = CXGN::List::Validate->new();
        my @seedlots_missing = @{$seedlot_validator->validate($schema,'seedlots',\@seedlots_to_discard)->{'missing'}};

        if (scalar(@seedlots_missing) > 0){
            $c->stash->{rest} = { error_string => "The following seedlots are not in the database or are marked as discarded : ".join(',',@seedlots_missing) };
            return;
        }
    } elsif (defined $seedlot_name) {
        @seedlots_to_discard = ($seedlot_name);
    }

    my $seedlot_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "seedlot", 'stock_type')->cvterm_id();
    my $current_count_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "current_count", 'stock_property')->cvterm_id();
    my $current_weight_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "current_weight_gram", 'stock_property')->cvterm_id();

    foreach my $seedlot_name (@seedlots_to_discard) {
        my $seedlot_rs = $schema->resultset("Stock::Stock")->find( { uniquename => $seedlot_name, type_id => $seedlot_type_id });
        my $seedlot_id = $seedlot_rs->stock_id();

        my $current_count_rs = $seedlot_rs->stockprops({type_id=>$current_count_type_id});
        if ($current_count_rs->count == 1){
            $current_count_rs->first->update({value=>'DISCARDED'});
        }

        my $current_weight_rs = $seedlot_rs->stockprops({type_id=>$current_weight_type_id});
        if ($current_weight_rs->count == 1){
            $current_weight_rs->first->update({value=>"DISCARDED"});
        }

        my $seedlot_to_discard = CXGN::Stock::Seedlot::Discard->new({
            bcs_schema => $schema,
            parent_id => $seedlot_id,
        });

        $seedlot_to_discard->person_id($user_id);
        $seedlot_to_discard->discard_date($discard_date);
        $seedlot_to_discard->reason($discard_reason);

        $seedlot_to_discard->store();

        if (!$seedlot_to_discard->store()){
            $c->stash->{rest} = {error_string => "Error discarding seedlot",};
            return;
        }
    }

    my $bs = CXGN::BreederSearch->new( { dbh=>$dbh, dbname=>$c->config->{dbname}, } );
    my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'stockprop', 'concurrent', $c->config->{basepath});

    $c->stash->{rest} = {success => "1",};

}


sub undo_discarded_seedlots : Path('/ajax/breeders/seedlot/undo_discard') :Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $dbh = $c->dbc->dbh();
    my $seedlot_id = $c->req->param("seedlot_id");

    if (!$c->user()){
        $c->stash->{rest} = { error_string => "You must be logged in to undo discading this seedlot" };
        return;
    }
    if (!$c->user()->check_roles("curator")) {
        $c->stash->{rest} = { error_string => "You do not have the correct role to undo discarding this seedlot. Please contact us." };
        return;
    }

    my $user_id = $c->user()->get_object()->get_sp_person_id();

    my $discarded_metadata_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'discarded_metadata', 'stock_property')->cvterm_id();
    my $discarded_rs = $schema->resultset("Stock::Stockprop")->find({stock_id => $seedlot_id, type_id => $discarded_metadata_type_id});

    if (defined $discarded_rs->stockprop_id) {
        $discarded_rs->delete();
    }

    my $restored_seedlot = CXGN::Stock::Seedlot->new(schema => $schema, seedlot_id => $seedlot_id);
    $restored_seedlot->set_current_count_property();
    $restored_seedlot->set_current_weight_property();

    my $bs = CXGN::BreederSearch->new( { dbh=>$dbh, dbname=>$c->config->{dbname}, } );
    my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'stockprop', 'concurrent', $c->config->{basepath});

    $c->stash->{rest} = { success => 1 };

}


sub upload_transactions : Path('/ajax/breeders/upload_transactions') : ActionClass('REST') { }

sub upload_transactions_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $user_id;
    my $user_name;
    my $user_role;
    my $session_id = $c->req->param("sgn_session_id");

    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{rest} = {error=>'You must be logged in to upload seedlots!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else {
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to upload seedlots!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }

#    if (($user_role ne 'curator') && ($user_role ne 'submitter')) {
#        $c->stash->{rest} = {error=>'Only a submitter or a curator can upload seedlot transactions'};
#        $c->detach();
    #    }

    if ($c->stash->{access}->denied( $c->stash->{user_id}, "write", "stocks")) { 
	$c->stash->{rest} = {error => 'You do not have the privileges to upload seedlot transactions'};
        $c->detach();
    }

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $upload_seedlots_to_seedlots = $c->req->upload('seedlots_to_seedlots_file');
    my $upload_seedlots_to_new_seedlots = $c->req->upload('seedlots_to_new_seedlots_file');
    my $upload_seedlots_to_plots = $c->req->upload('seedlots_to_plots_file');
    my $upload_seedlots_to_unspecified_names = $c->req->upload('seedlots_to_unspecified_names_file');

    my $new_seedlot_breeding_program_id = $c->req->param("new_seedlot_breeding_program_id");
    my $new_seedlot_location = $c->req->param("new_seedlot_location");
    my $new_seedlot_organization = $c->req->param("new_seedlot_organization_name");

    if (!$upload_seedlots_to_seedlots && !$upload_seedlots_to_new_seedlots && !$upload_seedlots_to_plots && !$upload_seedlots_to_unspecified_names){
        $c->stash->{rest} = {error=>'You must upload a transaction file!'};
        $c->detach();
    }
    my $upload;
    my $parser_type;
    if (defined $upload_seedlots_to_seedlots){
        $upload = $upload_seedlots_to_seedlots;
        $parser_type = 'SeedlotsToSeedlots';
    }
    if (defined $upload_seedlots_to_new_seedlots){
        $upload = $upload_seedlots_to_new_seedlots;
        $parser_type = 'SeedlotsToNewSeedlots';
    }
    if (defined $upload_seedlots_to_plots){
        $upload = $upload_seedlots_to_plots;
        $parser_type = 'SeedlotsToPlots';
    }
    if (defined $upload_seedlots_to_unspecified_names){
        $upload = $upload_seedlots_to_unspecified_names;
        $parser_type = 'SeedlotsToUnspecifiedNames';
    }

    my $subdirectory = "seedlot_transaction_upload";
    my $upload_original_name = $upload->filename();
    my $upload_tempfile = $upload->tempname;
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();

    ## Store uploaded temporary file in archive
    my $uploader = CXGN::UploadFile->new({
        tempfile => $upload_tempfile,
        subdirectory => $subdirectory,
        archive_path => $c->config->{archive_path},
        archive_filename => $upload_original_name,
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $user_role
    });
    my $archived_filename_with_path = $uploader->archive();
    my $md5 = $uploader->get_md5($archived_filename_with_path);
    if (!$archived_filename_with_path) {
        $c->stash->{rest} = {error => "Could not save file $upload_original_name in archive",};
        $c->detach();
    }
    unlink $upload_tempfile;
    my $parser = CXGN::Stock::Seedlot::ParseUpload->new(chado_schema => $schema, filename => $archived_filename_with_path);
    $parser->load_plugin($parser_type);
    my $parsed_data = $parser->parse();

    if (!$parsed_data) {
        my $return_error = '';
        my $parse_errors;
        if (!$parser->has_parse_errors() ){
            $c->stash->{rest} = {error_string => "Could not get parsing errors"};
        } else {
            $parse_errors = $parser->get_parse_errors();

            foreach my $error_string (@{$parse_errors->{'error_messages'}}){
                $return_error .= $error_string."<br>";
            }
        }
        $c->stash->{rest} = {error_string => $return_error};
        $c->detach();
    }

    if (defined $parsed_data && ($parser_type eq 'SeedlotsToSeedlots')) {
        my $transactions = $parsed_data->{transactions};
        my @all_transactions = @$transactions;
        eval {
            foreach my $transaction_info (@all_transactions) {
#            print STDERR "EACH SEEDLOT TO SEEDLOT TRANSACTION INFO =".Dumper($transaction_info)."\n";
                my $transaction = CXGN::Stock::Seedlot::Transaction->new(schema => $schema);
                $transaction->from_stock([$transaction_info->{from_seedlot_id}, $transaction_info->{from_seedlot_name}]);
                $transaction->to_stock([$transaction_info->{to_seedlot_id}, $transaction_info->{to_seedlot_name}]);
                $transaction->amount($transaction_info->{amount});
                $transaction->weight_gram($transaction_info->{weight});
                $transaction->timestamp($timestamp);
                $transaction->description($transaction_info->{transaction_description});
                $transaction->operator($transaction_info->{operator});
                my $transaction_id = $transaction->store();

                my $current_from_seedlot = CXGN::Stock::Seedlot->new(schema => $schema, seedlot_id => $transaction_info->{from_seedlot_id});
                $current_from_seedlot->set_current_count_property();
                $current_from_seedlot->set_current_weight_property();

                my $current_to_seedlot = CXGN::Stock::Seedlot->new(schema => $schema, seedlot_id => $transaction_info->{to_seedlot_id});
                $current_to_seedlot->set_current_count_property();
                $current_to_seedlot->set_current_weight_property();
            }
        };
    } elsif (defined $parsed_data && ($parser_type eq 'SeedlotsToPlots')) {
        my $transactions = $parsed_data->{transactions};
        my @all_transactions = @$transactions;

        eval {
            foreach my $transaction_info (@all_transactions) {
#                print STDERR "EACH SEEDLOT TO PLOT TRANSACTION INFO =".Dumper($transaction_info)."\n";
                my $transaction = CXGN::Stock::Seedlot::Transaction->new(schema => $schema);
                $transaction->from_stock([$transaction_info->{from_seedlot_id}, $transaction_info->{from_seedlot_name}]);
                $transaction->to_stock([$transaction_info->{to_plot_id}, $transaction_info->{to_plot_name}]);
                $transaction->amount($transaction_info->{amount});
                $transaction->weight_gram($transaction_info->{weight});
                $transaction->timestamp($timestamp);
                $transaction->description($transaction_info->{transaction_description});
                $transaction->operator($transaction_info->{operator});
                my $transaction_id = $transaction->store();

                my $current_from_seedlot = CXGN::Stock::Seedlot->new(schema => $schema, seedlot_id => $transaction_info->{from_seedlot_id});
                $current_from_seedlot->set_current_count_property();
                $current_from_seedlot->set_current_weight_property();
            }
        };
    } elsif (defined $parsed_data && ($parser_type eq 'SeedlotsToNewSeedlots')) {
        my @added_seedlots;
        my $transactions = $parsed_data->{transactions};
        my @all_transactions = @$transactions;
        eval {
            foreach my $transaction_info (@all_transactions) {
#                print STDERR "EACH SEEDLOT TO NEW SEEDLOT TRANSACTION INFO =".Dumper($transaction_info)."\n";
                my $from_seedlot_id = $transaction_info->{from_seedlot_id};
                my $new_seedlot_info = $transaction_info->{new_seedlot_info};
                my $new_seedlot_name = $new_seedlot_info->[0];
                my $content_info = $new_seedlot_info->[1];
                my $new_seedlot_description = $new_seedlot_info->[2];
                my $new_seedlot_box_name = $new_seedlot_info->[3];
                my $new_seedlot_quality = $new_seedlot_info->[4];

                my $new_seedlot = CXGN::Stock::Seedlot->new(schema => $schema);
                $new_seedlot->uniquename($new_seedlot_name);
                $new_seedlot->location_code($new_seedlot_location);
                $new_seedlot->box_name($new_seedlot_box_name);
                $new_seedlot->description($new_seedlot_description);
                $new_seedlot->accession_stock_id($content_info->[0]);
                $new_seedlot->cross_stock_id($content_info->[1]);
                $new_seedlot->organization_name($new_seedlot_organization);
                $new_seedlot->breeding_program_id($new_seedlot_breeding_program_id);
                $new_seedlot->quality($new_seedlot_quality);
                my $return = $new_seedlot->store();
                my $new_seedlot_id = $return->{seedlot_id};
                push @added_seedlots, $new_seedlot_id;

                my $transaction = CXGN::Stock::Seedlot::Transaction->new(schema => $schema);
                $transaction->from_stock([$transaction_info->{from_seedlot_id}, $transaction_info->{from_seedlot_name}]);
                $transaction->to_stock([$new_seedlot_id, $new_seedlot_name]);
                $transaction->amount($transaction_info->{amount});
                $transaction->weight_gram($transaction_info->{weight});
                $transaction->timestamp($timestamp);
                $transaction->description($transaction_info->{transaction_description});
                $transaction->operator($transaction_info->{operator});

                my $transaction_id = $transaction->store();

                my $current_from_seedlot = CXGN::Stock::Seedlot->new(schema => $schema, seedlot_id => $transaction_info->{from_seedlot_id});
                $current_from_seedlot->set_current_count_property();
                $current_from_seedlot->set_current_weight_property();

                my $to_new_seedlot = CXGN::Stock::Seedlot->new(schema => $schema, seedlot_id => $new_seedlot_id);
                $to_new_seedlot->set_current_count_property();
                $to_new_seedlot->set_current_weight_property();
            }

            foreach my $seedlot_id (@added_seedlots) {
                $phenome_schema->resultset("StockOwner")->find_or_create({
                    stock_id     => $seedlot_id,
                    sp_person_id =>  $user_id,
                });
            }
        };
    } elsif (defined $parsed_data && ($parser_type eq 'SeedlotsToUnspecifiedNames')) {
            my $transactions = $parsed_data->{transactions};
            my @all_transactions = @$transactions;
            eval {
                foreach my $transaction_info (@all_transactions) {
    #            print STDERR "EACH SEEDLOT TO UNSPECIFY NAME TRANSACTION INFO =".Dumper($transaction_info)."\n";
                    my $transaction = CXGN::Stock::Seedlot::Transaction->new(schema => $schema);
                    $transaction->from_stock([$transaction_info->{from_seedlot_id}, $transaction_info->{from_seedlot_name}]);
                    $transaction->to_stock([$transaction_info->{from_seedlot_id}, $transaction_info->{from_seedlot_name}]);
                    $transaction->amount($transaction_info->{amount});
                    $transaction->weight_gram($transaction_info->{weight});
                    $transaction->timestamp($timestamp);
                    $transaction->description($transaction_info->{transaction_description});
                    $transaction->operator($transaction_info->{operator});
                    $transaction->factor(-1);
                    my $transaction_id = $transaction->store();

                    my $current_from_seedlot = CXGN::Stock::Seedlot->new(schema => $schema, seedlot_id => $transaction_info->{from_seedlot_id});
                    $current_from_seedlot->set_current_count_property();
                    $current_from_seedlot->set_current_weight_property();
                }
            };
    }

    if ($@) {
        $c->stash->{rest} = { error => $@ };
        print STDERR "An error condition occurred, was not able to upload transactions. ($@).\n";
        $c->detach();
    }

    my $dbh = $c->dbc->dbh();
    my $bs = CXGN::BreederSearch->new( { dbh=>$dbh, dbname=>$c->config->{dbname}, } );
    my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'stockprop', 'concurrent', $c->config->{basepath});

    $c->stash->{rest} = { success => 1};
}


sub add_transactions_using_list : Path('/ajax/breeders/add_transactions_using_list') : ActionClass('REST') { }

sub add_transactions_using_list_POST : Args(0) {
    my ($self, $c) = @_;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    if (!$c->user){
        $c->stash->{rest} = {error=>'You must be logged in to add seedlot transactions!'};
        $c->detach();
    }

#    if (!($c->user()->check_roles('curator') || $c->user()->check_roles('submitter'))) {
#        $c->stash->{rest} = { error => 'Only a submitter or a curator can add seedlot transactions' };
#        $c->detach();
    #    }

    if ($c->stash->{access}->denied( $c->stash->{user_id}, "write", "stocks")) { 
	$c->stash->{rest} = {error => 'You do not have privileges to add seedlot transactions.'};
        $c->detach();
    }

    my $operator = $c->user->get_object->get_username;
    my $user_id = $c->user->get_object->get_sp_person_id;
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();

    my $new_transaction_data = decode_json $c->req->param('new_transaction_data');
    print STDERR "NEW TRANSACTION DATA =".Dumper($new_transaction_data)."\n";

    foreach my $each_transaction (@$new_transaction_data) {
        my $seedlot_name = $each_transaction->{'seedlot_name'};
        my $weight_g = $each_transaction->{'weight_g'};
        my $number_of_seeds = $each_transaction->{'number_of_seeds'};
        if (!defined $weight_g) {
            $weight_g = 'NA';
        } elsif (!defined $number_of_seeds) {
            $number_of_seeds = 'NA';
        }
        my $transaction_description = $each_transaction->{'transaction_description'};

        my $seedlot_stock_id = $schema->resultset('Stock::Stock')->find({uniquename=>$seedlot_name})->stock_id();

        my $transaction = CXGN::Stock::Seedlot::Transaction->new(schema => $schema);
        $transaction->to_stock([$seedlot_stock_id, $seedlot_name]);
        $transaction->from_stock([$seedlot_stock_id, $seedlot_name]);
        $transaction->amount($number_of_seeds);
        $transaction->weight_gram($weight_g);
        $transaction->timestamp($timestamp);
        $transaction->description($transaction_description);
        $transaction->operator($operator);
        $transaction->factor(-1);
        my $transaction_id = $transaction->store();
        print STDERR "TRANSACTION ID =".Dumper($transaction_id)."\n";

        my $seedlot_rs = CXGN::Stock::Seedlot->new(schema => $schema, seedlot_id => $seedlot_stock_id);
        $seedlot_rs->set_current_count_property();
        $seedlot_rs->set_current_weight_property();
    }


    my $dbh = $c->dbc->dbh();
    my $bs = CXGN::BreederSearch->new( { dbh=>$dbh, dbname=>$c->config->{dbname}, } );
    my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'stockprop', 'concurrent', $c->config->{basepath});


    $c->stash->{rest} = { success => 1};


}


1;

no Moose;
__PACKAGE__->meta->make_immutable;
