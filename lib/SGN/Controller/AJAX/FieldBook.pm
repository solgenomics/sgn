
=head1 NAME

SGN::Controller::AJAX::FieldBook - a REST controller class to provide the
backend for field book operations

=head1 DESCRIPTION

Creating and viewing trials

=head1 AUTHOR

Jeremy Edwards <jde22@cornell.edu>

=cut

package SGN::Controller::AJAX::FieldBook;

use Moose;
use List::MoreUtils qw /any /;
use Scalar::Util qw(looks_like_number);
use DateTime;
use Try::Tiny;
use File::Basename qw | basename dirname|;
use File::Copy;
use File::Slurp;
use File::Spec;
use File::Temp ();
use Encode ();
use Digest::MD5;
use JSON -support_by_pp;
use Spreadsheet::WriteExcel;
use SGN::View::Trial qw/design_layout_view design_info_view/;
use CXGN::Location::LocationLookup;
use CXGN::Stock::StockLookup;
use CXGN::UploadFile;
use CXGN::Fieldbook::TraitInfo;
use CXGN::Fieldbook::DownloadTrial;
use SGN::Model::Cvterm;
use CXGN::List;
use CXGN::List::Validate;
use CXGN::List::Transform;
use Data::Dumper;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
   );


sub create_fieldbook_from_trial : Path('/ajax/fieldbook/create') : ActionClass('REST') { }

sub create_fieldbook_from_trial_POST : Args(0) {
    my ($self, $c) = @_;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $sp_person_id);
    my $trial_id = $c->req->param('trial_id');
    my $data_level = $c->req->param('data_level') || 'plots';
    my $include_treatments = $c->req->param('treatments') || 'true';
    my $include_plot_order = $c->req->param('include_plot_order') eq 'true';
    my $plot_order = $c->req->param('plot_order');
    my $plot_start = $c->req->param('plot_start');
    my $metadata_schema = $c->dbic_schema('CXGN::Metadata::Schema', undef, $sp_person_id);
    my $phenome_schema = $c->dbic_schema('CXGN::Phenome::Schema', undef, $sp_person_id);

    chomp($trial_id);
    if (!$c->user()) {
        $c->stash->{rest} = {error => "You need to be logged in to create a field book" };
        return;
    }
    if (!any { $_ eq "curator" || $_ eq "submitter" } ($c->user()->roles)  ) {
        $c->stash->{rest} = {error =>  "You have insufficient privileges to create a field book." };
        return;
    }
    if (!$trial_id) {
        $c->stash->{rest} = {error =>  "No trial ID supplied." };
        return;
    }
    my $trial = $schema->resultset('Project::Project')->find({project_id => $trial_id});
    if (!$trial) {
        $c->stash->{rest} = {error =>  "Trial does not exist with id $trial_id." };
        return;
    }
    if ($data_level eq 'plants') {
        my $trial = CXGN::Trial->new( { bcs_schema => $schema, trial_id => $trial_id });
        if (!$trial->has_plant_entries()){
            $c->stash->{rest} = {error =>  "Trial does not have plant entries. You must first create plant entries." };
            return;
        }
    }
    if ($data_level eq 'subplots' || $data_level eq 'plants_subplots') {
        my $trial = CXGN::Trial->new( { bcs_schema => $schema, trial_id => $trial_id });
        if (!$trial->has_subplot_entries()) {
            $c->stash->{rest} = {error =>  "Trial does not have subplot entries." };
            return;
        }
    }

    my $trial_stock_type;
    if (!defined($c->req->param('trial_stock_type'))) {
        $trial_stock_type = 'accession';
    } else {
        $trial_stock_type = $c->req->param('trial_stock_type');
    }

    my $original_selected_columns = $c->req->param('selected_columns') ? decode_json $c->req->param('selected_columns') : {};

    my %modified_columns = %{$original_selected_columns};
    if (exists $modified_columns{'family_name'}) {
        delete $modified_columns{'family_name'};
        $modified_columns{'accession_name'} = 1;
    }
    if (exists $modified_columns{'cross_unique_id'}) {
        delete $modified_columns{'cross_unique_id'};
        $modified_columns{'accession_name'} = 1;
    }
    my $selected_columns = \%modified_columns;

#    print STDERR "ORIGINAL SELECTED COLUMNS =".Dumper($original_selected_columns)."\n";
#    print STDERR "MODIFIED COLUMNS =".Dumper(\%modified_columns)."\n";
    my $include_measured = $c->req->param('include_measured') || '';
    my $all_stats = $c->req->param('all_stats') || '';
    my $use_synonyms = $c->req->param('use_synonyms') || '';
    my $selected_trait_list_id = $c->req->param('trait_list');
    my @selected_traits;
    if ($selected_trait_list_id){
        my $list = CXGN::List->new({ dbh => $c->dbc->dbh, list_id => $selected_trait_list_id });
        my @trait_list = @{$list->elements()};
        my $validator = CXGN::List::Validate->new();
        my @absent_traits = @{$validator->validate($schema, 'traits', \@trait_list)->{'missing'}};
        if (scalar(@absent_traits)>0){
            $c->stash->{rest} = {error =>  "Trait list is not valid because of these terms: ".join ',',@absent_traits };
            $c->detach();
	    return;
        }
        my $lt = CXGN::List::Transform->new();
        @selected_traits = @{$lt->transform($schema, "traits_2_trait_ids", \@trait_list)->{transform}};
    }

    my $dir = $c->tempfiles_subdir('/other');
    my $tempfile = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'other/excelXXXX');

    my $create_fieldbook = CXGN::Fieldbook::DownloadTrial->new({
        bcs_schema => $schema,
        metadata_schema => $metadata_schema,
        phenome_schema => $phenome_schema,
        trial_id => $trial_id,
        tempfile => $tempfile,
        archive_path => $c->config->{archive_path},
        user_id => $c->user()->get_object()->get_sp_person_id(),
        user_name => $c->user()->get_object()->get_username(),
        data_level => $data_level,
        include_treatments => $include_treatments,
        selected_columns => $selected_columns,
        include_measured => $include_measured,
        all_stats => $all_stats,
        use_synonyms => $use_synonyms,
        selected_trait_ids => \@selected_traits,
        trial_stock_type => $trial_stock_type,
        include_plot_order => $include_plot_order,
        plot_order => $plot_order,
        plot_start => $plot_start,
    });

    my $create_fieldbook_return = $create_fieldbook->download();
    my $error;
    if ($create_fieldbook_return->{'error_messages'}){
        $error = join ',', @{$create_fieldbook_return->{'error_messages'}};
    }

    $c->stash->{rest} = {
        error_string => $error,
        success => 1,
        result => $create_fieldbook_return->{'result'},
        file => $create_fieldbook_return->{'file'},
        file_id => $create_fieldbook_return->{'file_id'},
    };
}

sub create_trait_file_for_field_book : Path('/ajax/fieldbook/traitfile/create') : ActionClass('REST') { }

sub create_trait_file_for_field_book_POST : Args(0) {
    my ($self, $c) = @_;

    if (!$c->user()) {
	$c->stash->{rest} = {error => "You need to be logged in to create a field book" };
	return;
    }
    if (!any { $_ eq "curator" || $_ eq "submitter" } ($c->user()->roles)  ) {
	$c->stash->{rest} = { error =>  "You have insufficient privileges to create a field book." };
	return;
    }

    my @trait_list;
    my $trait_file_name = $c->req->param('trait_file_name');
    my $include_notes = $c->req->param('include_notes');
    my $user_id = $c->user()->get_object()->get_sp_person_id();
    my $user_name = $c->user()->get_object()->get_username();
    my $subdirectory_name = "tablet_trait_files";
    my $archive_path = $c->config->{archive_path};
    my $dbh = $c->dbc->dbh();
    my @trait_ids;
    my $chado_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $user_id);

    my $parsed = eval {
        @trait_list = @{_parse_list_from_json($c->req->param('trait_list'))};
        if ($c->req->param('selected_listed')) {
            @trait_ids = @{_parse_list_from_json($c->req->param('trait_ids'))};
        } else {
            @trait_ids = $c->req->param('trait_ids');
            @trait_ids = $c->req->param('trait_ids[]') if !@trait_ids;
            @trait_ids = @{$trait_ids[0]} if @trait_ids == 1 && ref($trait_ids[0]) eq 'ARRAY';
        }
        1;
    };
    if (!$parsed || !@trait_list || @trait_list != @trait_ids || grep { !defined($_) || ref($_) || $_ !~ /^\d+$/ } @trait_ids) {
        $c->stash->{rest} = {error => 'Select a valid trait list or select traits directly, then try again.'};
        return;
    }
    if (!defined($trait_file_name) || $trait_file_name !~ /\S/) {
        $c->stash->{rest} = {error => 'A trait file name is required.'};
        return;
    }
    my $validation = CXGN::List::Validate->new()->validate($chado_schema, 'traits', \@trait_list);
    if (@{$validation->{missing} || []} || grep { !$chado_schema->resultset('Cv::Cvterm')->find({cvterm_id => $_}) } @trait_ids) {
        $c->stash->{rest} = {error => 'Some selected traits are not valid observation variables.'};
        return;
    }

    if (!-d $archive_path) {
	mkdir $archive_path;
    }

    if (! -d File::Spec->catfile($archive_path, $user_id)) {
	mkdir (File::Spec->catfile($archive_path, $user_id));
    }

    if (! -d File::Spec->catfile($archive_path, $user_id,$subdirectory_name)) {
	mkdir (File::Spec->catfile($archive_path, $user_id, $subdirectory_name));
    }
    
    $trait_file_name =~ s{[/\\\x00-\x1f]}{_}g;
    my ($FILE, $file_destination) = File::Temp::tempfile(
        $trait_file_name.'_XXXXXX',
        DIR => File::Spec->catfile($archive_path, $user_id, $subdirectory_name),
        SUFFIX => '.trt', UNLINK => 0,
    );
    binmode($FILE, ':encoding(UTF-8)');
    print $FILE "trait,format,defaultValue,minimum,maximum,details,categories,isVisible,realPosition\n";

    my $order = 0;

    foreach my $term (@trait_list) {
	#print STDERR "term is $term\n";
	my @parts = split (/\|/ , $term);
	my ($db_name, $accession) = split ":", pop @parts;
	my $trait_name = join ("|", @parts);
	#print STDERR "trait name is $trait_name, full cvterm accession is $full_cvterm_accession\n";
	#my ( $db_name , $accession ) = split (/:/ , $full_cvterm_accession);

	$accession =~ s/\s+$//;
	$accession =~ s/^\s+//;
	$db_name =~ s/\s+$//;
	$db_name =~ s/^\s+//;

	my $cvterm = CXGN::Chado::Cvterm->new( $dbh, $trait_ids[$order] );
	my $synonym = $cvterm->get_uppercase_synonym();
	my $name;
	if ($c->config->{fieldbook_trait_synonym}) {
	    print STDERR "synonym: $synonym, trait_name: $trait_name\n";
	    $name = $synonym || $trait_name; # use uppercase synonym if defined, otherwise use full trait name
	} else {
	    print STDERR "trait_name: $trait_name\n";
	    $name = $trait_name;
	}
	$order++;

	#get trait info

	my $trait_info_lookup = CXGN::Fieldbook::TraitInfo->new(
	    {
		chado_schema    => $chado_schema,
		db_name         => $db_name,
		trait_accession => $accession,
	    });
	
	my $trait_info_string = $trait_info_lookup->get_trait_info($trait_name);

	#return error if not $trait_info_string;
	#print line with trait info
	#print FILE "$trait_name:$db_name:$accession,text,,,,,,TRUE,$order\n";
	#print STDERR " Adding line \"$name\t\t\t|$db_name:$accession\",$trait_info_string,\"TRUE\",\"$order\" to trait file\n";
	my $label = "$name\t\t\t|$db_name:$accession";
	$label =~ s/"/""/g;
	print $FILE "\"$label\",$trait_info_string,\"TRUE\",\"$order\"\n";
    }

    if ($include_notes eq 'true') {
	$order++;
	#print STDERR " Adding notes line \"notes\",\"text\",\"\",\"\",\"\",\"Additional observations for future reference\",\"\",\"TRUE\",\"$order\"\n";
	print $FILE "\"notes\",\"text\",\"\",\"\",\"\",\"Additional observations for future reference\",\"\",\"TRUE\",\"$order\"\n";
    }
    
    close $FILE;
    
    open(my $F, "<", $file_destination) || die "Can't open file ";
    binmode $F;
    my $md5 = Digest::MD5->new();
    $md5->addfile($F);
    close($F);

    my $metadata_schema = $c->dbic_schema('CXGN::Metadata::Schema', undef, $user_id);
    
    my $md_row = $metadata_schema->resultset("MdMetadata")->create({
	create_person_id => $user_id,
								   });
    $md_row->insert();
    
    my $file_row = $metadata_schema->resultset("MdFiles")->create({
	basename => basename($file_destination),
	dirname => dirname($file_destination),
	filetype => 'tablet trait file',
	md5checksum => $md5->hexdigest(),
	metadata_id => $md_row->metadata_id(),
								  });
    $file_row->insert();
    
    my $id = $file_row->file_id();
    
    $c->stash->{rest} = {success => "1", file_id => $id, };
    
}


sub _parse_list_from_json {
    my $list_json = shift;
    
    return unless $list_json;
    
    # Catalyst form parameters can already be decoded Perl characters; other
    # callers supply UTF-8 bytes. decode_json alone rejects wide characters.
    my $decoded_list = JSON->new->utf8(!Encode::is_utf8($list_json))->decode($list_json);
    die "JSON array required" if ref($decoded_list) ne 'ARRAY';
    die "JSON list entries must be scalar values" if grep { !defined($_) || ref($_) } @$decoded_list;
    my @array_of_list_items = @$decoded_list;
    return \@array_of_list_items;
}


1;
