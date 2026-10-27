=head1 SGN::Controller::AJAX::IdentifierGeneration

=head1 SYNOPSYS

A page for handling identifier generation. identifier generation is used by ACAI and Banana Agronomy to create barcodes that are not associated with entitities in the database. Can be used for any kind of "preprinting" where identifiers are printed and later assigned to entities.

=head1 AUTHOR

=cut

package SGN::Controller::AJAX::IdentifierGeneration;

use Moose;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::List;
use JSON;
use Tie::UrlEncoder; our(%urlencode);
use DateTime;
use HTML::Entities ();

BEGIN { extends 'Catalyst::Controller::REST' };

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
   );


sub new_identifier_generation : Path('/ajax/breeders/new_identifier_generation') Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $sp_person_id);

    if(!$c->user){
        $c->stash->{rest} = { error => $c->i18n->p("program.identifier.login", "You must be logged in first!")};
        $c->detach();
    }

    my $identifier_name = $c->req->param('identifier_name');
    my $identifier_prefix = $c->req->param('identifier_prefix');
    my $num_digits = $c->req->param('num_digits');
    my $current_number = $c->req->param('current_number');
    my $description = $c->req->param('description');
    if (!$identifier_name){
        $c->stash->{rest} = { error => $c->i18n->p("program.identifier.name", "Identifier Name is required!")};
        $c->detach();
    }
    if (!$identifier_prefix){
        $c->stash->{rest} = { error => $c->i18n->p("program.identifier.prefix", "Identifier Prefix is required!")};
        $c->detach();
    }
    if (!$num_digits){
        $c->stash->{rest} = { error => $c->i18n->p("program.identifier.digits", "Num digits is required!")};
        $c->detach();
    }
    if (!$current_number){
        $c->stash->{rest} = { error => $c->i18n->p("program.identifier.number", "Current number is required!")};
        $c->detach();
    }
    if (!$description){
        $c->stash->{rest} = { error => $c->i18n->p("program.identifier.description", "Identifier Description is required!")};
        $c->detach();
    }

    my %used_prefixes;
    my $available_public_lists = CXGN::List::available_public_lists($schema->storage->dbh, 'identifier_generation');
    foreach (@$available_public_lists){
        my $list = CXGN::List->new({ dbh => $schema->storage->dbh, list_id => $_->[0] });
        my $element = $list->elements()->[0];
        if($element){
            my $identifier_generator = decode_json $element;
            my $prefix = $identifier_generator->{identifier_prefix};
            $used_prefixes{$prefix}++;
        }
    }
    if (exists($used_prefixes{$identifier_prefix})) {
        $c->stash->{rest} = { error => $c->i18n->p("program.identifier.prefix_used", "That identifier prefix has already been used and so nothing was saved! Please use the identifier already in use")};
        $c->detach();
    }

    my $time = DateTime->now();
    my $timestamp = $time->ymd('/')."_".$time->hms();
    my $identifier = {
        identifier_prefix => $identifier_prefix,
        num_digits => $num_digits,
        current_number => $current_number,
        records => [{'timestamp' => $timestamp, 'username' => $c->user()->get_object->get_username(), 'next_number' => '0', 'type' => 'identifier_instantiation' }]
    };
    my $identifier_json = encode_json $identifier;

    my $new_list_id = CXGN::List::create_list($schema->storage->dbh, $identifier_name, $description, $c->user()->get_object->get_sp_person_id());
    my $list = CXGN::List->new({ dbh => $schema->storage->dbh, list_id => $new_list_id });
    $list->add_bulk([$identifier_json]);
    $list->type('identifier_generation');
    $list->make_public();

    $c->stash->{rest} = { new_list_id => $new_list_id, success => $c->i18n->p("program.identifier.stored", "Stored %{name}!", {name => "$identifier_name"}) };
}

sub identifier_generation_list : Path('/ajax/breeders/identifier_generation_list') Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $sp_person_id);

    if(!$c->user){
        $c->stash->{rest} = { error => $c->i18n->p("program.identifier.login", "You must be logged in first!")};
        $c->detach();
    }

    my @data;
    my $available_public_lists = CXGN::List::available_public_lists($schema->storage->dbh, 'identifier_generation');
    foreach (@$available_public_lists){
        my $list = CXGN::List->new({ dbh => $schema->storage->dbh, list_id => $_->[0] });
        my $element = $list->elements()->[0];
        if($element){
            my $identifier_generator = decode_json $element;
            my $prefix = $identifier_generator->{identifier_prefix};
            my $num_digits = $identifier_generator->{num_digits};
            my $current_number = $identifier_generator->{current_number};
            my $num = sprintf '%0'.$num_digits.'d', $current_number;
            my $next_identifier = $prefix.$num;
            my $history_caption = HTML::Entities::encode_entities(do { local $_; local $@; local $!; $c->i18n->p("lists.render.action.view", "View") });
            my $history_button = '<button class="btn btn-primary" name="identifier_generation_history" data-list_id="'.$_->[0].'">'.$history_caption.'</button>';
            my $next_count_label = HTML::Entities::encode_entities(do { local $_; local $@; local $!; $c->i18n->p("program.identifiers.row.next_count_label", "Next Count: ") });
            my $next_count_placeholder = HTML::Entities::encode_entities(do { local $_; local $@; local $!; $c->i18n->p("program.identifiers.row.next_count_placeholder", "EG: 100") });
            my $download_next_caption = HTML::Entities::encode_entities(do { local $_; local $@; local $!; $c->i18n->p("program.identifiers.row.download_next", "Download Next") });
            my $button = '<div class="form-group"><label class="col-sm-4 control-label">'.$next_count_label.'</label><div class="col-sm-8"> <input type="number" class="form-control" id="identifier_generation_next_numbers_'.$_->[0].'" placeholder="'.$next_count_placeholder.'" /></div></div><button class="btn btn-primary" name="identifier_generation_download" data-list_id="'.$_->[0].'">'.$download_next_caption.'</button>';
            push @data, [$_->[1], $_->[2], $prefix, $num_digits, $current_number, $next_identifier, $history_button, $button];
        }
    }

    $c->stash->{rest} = { data => \@data };
}


sub identifier_generation_download : Path('/ajax/breeders/identifier_generation_download') Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $sp_person_id);

    if(!$c->user){
        $c->stash->{rest} = { error => $c->i18n->p("program.identifier.login", "You must be logged in first!")};
        $c->detach();
    }

    my $list_id = $c->req->param('list_id');
    my $next_number = $c->req->param('next_number');
    if(!$list_id){
        $c->stash->{rest} = { error => $c->i18n->p("program.identifier.list", "List id is required!")};
        $c->detach();
    }
    if(!$next_number){
        $c->stash->{rest} = { error => $c->i18n->p("program.identifier.next", "Next count is required!")};
        $c->detach();
    }

    my $list = CXGN::List->new({ dbh => $schema->storage->dbh, list_id => $list_id });
    my $element = $list->elements()->[0];
    my $identifier_generator = decode_json $element;
    my $prefix = $identifier_generator->{identifier_prefix};
    my $num_digits = $identifier_generator->{num_digits};
    my $current_number = $identifier_generator->{current_number};
    my $previous_records = $identifier_generator->{records} || [];

    my $dir = $c->tempfiles_subdir('/download');
    my $rel_file = $c->tempfile( TEMPLATE => 'download/downloadXXXXX');
    my $tempfile = $c->config->{basepath}."/".$rel_file.".csv";

    my @new_identifiers;
    open(my $fh, '>', $tempfile);
    my $num = 0;
    while ($num < $next_number){
        my $number = sprintf '%0'.$num_digits.'d', $current_number+$num;
        my $identifier = $prefix.$number;
        print $fh "$identifier\n";
        $num++;
        push @new_identifiers, $identifier;
    }
    close $fh;

    my $time = DateTime->now();
    my $timestamp = $time->ymd('/')."_".$time->hms();
    push @$previous_records, {'generated_identifiers' => [@new_identifiers], 'timestamp' => $timestamp, 'username' => $c->user()->get_object->get_username(), 'next_number' => $next_number, 'type' => 'identifier_download' };

    my $identifier = {
        identifier_prefix => $prefix,
        num_digits => $num_digits,
        current_number => $current_number+$next_number,
        records => $previous_records
    };
    my $identifier_json = encode_json $identifier;
    $list->remove_element($element);
    $list->add_bulk([$identifier_json]);

    $c->stash->{rest} = { success => 1, identifiers => \@new_identifiers, filename => $urlencode{$rel_file.".csv"} };
}

sub identifier_generation_history : Path('/ajax/breeders/identifier_generation_history') Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $sp_person_id);

    if(!$c->user){
        $c->stash->{rest} = { error => $c->i18n->p("program.identifier.login", "You must be logged in first!")};
        $c->detach();
    }

    my $list_id = $c->req->param('list_id');
    if(!$list_id){
        $c->stash->{rest} = { error => $c->i18n->p("program.identifier.list", "List id is required!")};
        $c->detach();
    }

    my $list = CXGN::List->new({ dbh => $schema->storage->dbh, list_id => $list_id });
    my $element = $list->elements()->[0];
    my $identifier_generator = decode_json $element;
    my $previous_records = $identifier_generator->{records} || [];

    $c->stash->{rest} = { success => 1, records => $previous_records };
}

1;
