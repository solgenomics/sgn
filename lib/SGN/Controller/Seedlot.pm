
package SGN::Controller::Seedlot;

use Moose;

BEGIN { extends 'Catalyst::Controller'; }

use CXGN::Stock::Seedlot;
use CXGN::Onto;
use Data::Dumper;
use JSON::XS;
use CXGN::Stock::Seedlot::Discard;
use CXGN::People::Person;

sub seedlots :Path('/breeders/seedlots') :Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado", $sp_person_id);

    $c->stash->{preferred_species} = $c->config->{preferred_species};
    $c->stash->{timestamp} = localtime;
    my $user_role;
#    if ($c->user() && $c->user()->check_roles("curator")) {
#	$user_role = "curator";
    #    }

    if (my $message = $c->stash->{access}->denied( $c->stash->{user_id}, "read", "stocks" )) {
	$c->stash->{template} = '/access/access_denied.mas';
	$c->stash->{data_type} = 'stock';
	$c->stash->{message} = $message;
	return;
    }

    if ($c->stash->{access}->grant( $c->stash->{user_id}, "write", "stocks")) {
	$user_role = "curator";
    }

    my @editable_stock_props = split ',', $c->config->{editable_stock_props};
    my %editable_stock_props = map { $_=>1 } @editable_stock_props;

    my @editable_stock_props_definitions = split ',', $c->config->{editable_stock_props_definitions};
    my %def_hash;
    foreach (@editable_stock_props_definitions) {
        my @term_def = split ':', $_;
        $def_hash{$term_def[0]} = $term_def[1];
    }

    my $projects = CXGN::BreedersToolbox::Projects->new( { schema=> $schema } );
    my $breeding_programs = $projects->get_breeding_programs();

    my $default_seedlot_material_type = $c->config->{default_seedlot_material_type};

    $c->stash->{default_seedlot_material_type} = $default_seedlot_material_type;
    $c->stash->{editable_stock_props} = \%editable_stock_props;
    $c->stash->{editable_stock_props_definitions} = \%def_hash;
    $c->stash->{crossing_trials} = $projects->get_crossing_trials();
    $c->stash->{locations} = $projects->get_location_geojson_data();
    $c->stash->{programs} = $breeding_programs;
    $c->stash->{maintenance_enabled} = defined $c->config->{seedlot_maintenance_event_ontology_root} && $c->config->{seedlot_maintenance_event_ontology_root} ne '';
    $c->stash->{user_role} = $user_role;
    $c->stash->{template} = '/breeders_toolbox/seedlots.mas';
}

sub seedlot_detail :Path('/breeders/seedlot') Args(1) {
    my $self = shift;
    my $c = shift;
    my $seedlot_id = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado", $sp_person_id);
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema", undef, $sp_person_id);
    my $people_schema = $c->dbic_schema("CXGN::People::Schema", undef, $sp_person_id);
    my $dbh = $c->dbc->dbh;
    my $user_role;

    if (my $message = $c->stash->{access}->denied( $c->stash->{user_id}, "read", "stocks" )) {
	$c->stash->{template} = '/access/access_denied.mas';
	$c->stash->{data_type} = 'stock and seedlot';
	$c->stash->{message} = $message;
	return;
    }

    if ($c->stash->grant( $c->stash->{user_id}, "write", "stocks")) { 
	#if ($c->user() && $c->user()->check_roles("curator")) {
	$user_role = "curator";
    }

    my $sl = CXGN::Stock::Seedlot->new(
        schema => $schema,
        phenome_schema => $phenome_schema,
        seedlot_id => $seedlot_id
    );
    my @content_accession_names;
    my @content_cross_names;
    my $accessions = $sl->accession();
    my $accessions_html = '';
    if ($accessions){
        $accessions_html .= '<a href="/stock/'.$accessions->[0].'/view">'.$accessions->[1].'</a> (accession)';
        push @content_accession_names, $accessions->[1];
    }
    my $crosses = $sl->cross();
    my $crosses_html = '';
    if ($crosses){
        $crosses_html .= '<a href="/cross/'.$crosses->[0].'">'.$crosses->[1].'</a> (cross)';
        push @content_cross_names, $crosses->[1];
    }
    my $populations = $sl->populations();
    my $populations_html = '';
    foreach (@$populations){
        $populations_html .= '<a href="/stock/'.$_->[0].'/view">'.$_->[1].'</a> ';
    }
    my $owners = $sl->owners;
    my $owners_string = '';
    foreach (@$owners){
        my $p = $people_schema->resultset("SpPerson")->find({sp_person_id=>$_});
        $owners_string .= ' <a href="/solpeople/personal-info.pl?sp_person_id='.$p->sp_person_id.'">'.$p->username.'</a>';
    }

    my $page_current_count;
    my $page_current_weight;
    my $current_count = $sl->get_current_count_property();
    if ($current_count eq 'DISCARDED') {
        $page_current_count = '<span style="color:red">'.$current_count.'</span>';
    } else {
        $page_current_count = $current_count;
    }

    my $current_weight = $sl->get_current_weight_property();
    if ($current_weight eq 'DISCARDED') {
        $page_current_weight = '<span style="color:red">'.$current_weight.'</span>';
    } else {
        $page_current_weight = $current_weight;
    }

    my $page_discard_info;
    my $status;
    if (($current_count eq 'DISCARDED') || ($current_weight eq 'DISCARDED')) {
        my $discard_obj = CXGN::Stock::Seedlot::Discard->new({ bcs_schema => $schema, parent_id => $seedlot_id});
        my $discard_info = $discard_obj->get_discard_details();
        my $person_id = $discard_info->[0];
        my $person= CXGN::People::Person->new($dbh, $person_id);
        my $person_name=$person->get_first_name()." ".$person->get_last_name();
        my $operator_info = "Discarded by". ":"."".$person_name;
        my $date_info = "Discarded Date". ":"."".$discard_info->[1];
        my $reason_info = "Reason". ":"."".$discard_info->[2];
        my @all_info = ($operator_info, $date_info, $reason_info);
        my $all_info_string = join("<br>", @all_info);
        $page_discard_info = '<span style="color:red">'.$all_info_string.'</span>';
        $status = 'discarded';
    }

    my $default_seedlot_material_type = $c->config->{default_seedlot_material_type};
    $c->stash->{default_seedlot_material_type} = $default_seedlot_material_type;
    
    $c->stash->{seedlot_id} = $seedlot_id;
    $c->stash->{uniquename} = $sl->uniquename();
    $c->stash->{material_type} = $sl->material_type();
    $c->stash->{organization_name} = $sl->organization_name();
    $c->stash->{box_name} = $sl->box_name();
    $c->stash->{population_name} = $populations_html;
    $c->stash->{content_html} = $accessions_html ? $accessions_html : $crosses_html;
    $c->stash->{content_accession_name} = $content_accession_names[0];
    $c->stash->{content_cross_name} = $content_cross_names[0];
    $c->stash->{current_count} = $page_current_count;
    $c->stash->{current_weight} = $page_current_weight;
    $c->stash->{quality} = $sl->quality();
    $c->stash->{description} = $sl->description();
    $c->stash->{owners_string} = $owners_string;
    $c->stash->{timestamp} = localtime();
    $c->stash->{discard_info} = $page_discard_info;
    $c->stash->{status} = $status;
    $c->stash->{user_role} = $user_role;
    $c->stash->{maintenance_enabled} = defined $c->config->{seedlot_maintenance_event_ontology_root} && $c->config->{seedlot_maintenance_event_ontology_root} ne '';
    $c->stash->{template} = '/breeders_toolbox/seedlot_details.mas';
}


sub seedlot_maintenance : Path('/breeders/seedlot/maintenance') {
    my $self = shift;
    my $c = shift;

    if (my $message = $c->stash->{access}->denied( $c->stash->{user_id}, "read", "stocks" )) {
	$c->stash->{template} = '/access/access_denied.mas';
	$c->stash->{data_type} = 'stock and seedlot';
	$c->stash->{message} = $message;
	return;
    }

    
    # Make sure the seedlot maintenance event ontology is set
    if ( !defined $c->config->{seedlot_maintenance_event_ontology_root} || $c->config->{seedlot_maintenance_event_ontology_root} eq '' ) {
        $c->stash->{template} = '/generic_message.mas';
        $c->stash->{message} = 'Seedlot Maintenance Events are not enabled on this server!';
        return;
    }

    $c->stash->{tool} = $c->req->param('tool');
    $c->stash->{template} = '/breeders_toolbox/seedlot_maintenance/main.mas';
}


sub seedlot_maintenance_record : Path('/breeders/seedlot/maintenance/record') {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $sp_person_id);
    my $onto = CXGN::Onto->new({ schema => $schema });

    # Make sure the user is logged in
    if (!$c->user()) {
        my $url = '/' . $c->req->path;
        $c->res->redirect("/user/login?goto_url=$url");
        return;
    }

    if (my $message = $c->stash->{access}->denied( $c->stash->{user_id}, "write", "stocks" )) {
	$c->stash->{template} = '/access/access_denied.mas';
	$c->stash->{data_type} = 'stock and seedlot';
	$c->stash->{message} = $message;
	$c->detach();
    }

    # Make sure the user has submitter or curator privileges
#    if (!($c->user()->check_roles('curator') || $c->user()->check_roles('submitter'))) {
#        $c->stash->{template} = '/generic_message.mas';
#        $c->stash->{message} = 'Your account must have either submitter or curator privileges to add seedlot maintenance events.';
#        return;
#    }

    # Make sure the seedlot maintenance event ontology is set
    if ( !defined $c->config->{seedlot_maintenance_event_ontology_root} || $c->config->{seedlot_maintenance_event_ontology_root} eq '' ) {
        $c->stash->{template} = '/generic_message.mas';
        $c->stash->{message} = 'Seedlot Maintenance Events are not enabled on this server!';
        return;
    }

    # Get cvterm id of event ontology
    my $dbxref;
    my $root_cvterm;
    my $root_cvterm_id;
    my ($db_name, $accession) = split ":", $c->config->{seedlot_maintenance_event_ontology_root};
    my $db = $schema->resultset('General::Db')->search({ name => $db_name })->first();
    $dbxref = $db->find_related('dbxrefs', { accession => $accession }) if $db;
    $root_cvterm = $dbxref->cvterm if $dbxref;
    $root_cvterm_id = $root_cvterm->cvterm_id if $root_cvterm;

    # Get cvterm id(s) of events for seedlot info
    my @info_event_cvterms = ();
    my $info_event_cvterms_str = $c->config->{seedlot_maintenance_info_cvterms};
    if ( $info_event_cvterms_str && $info_event_cvterms_str ne '' ) {
        @info_event_cvterms = split(',', $info_event_cvterms_str);
    }

    $c->stash->{ontology} = $onto->get_children($root_cvterm_id) if $root_cvterm_id;
    $c->stash->{info_event_cvterms} = \@info_event_cvterms;
    $c->stash->{operator} = $c->user()->get_object()->get_username();
    $c->stash->{template} = '/breeders_toolbox/seedlot_maintenance/record.mas';
}

1;
