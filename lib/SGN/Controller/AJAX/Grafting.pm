
package SGN::Controller::AJAX::Grafting;

use Moose;
use List::Util qw | any |;
use File::Slurp qw | read_file |;
use Data::Dumper;
use Bio::GeneticRelationships::Individual;
use Bio::GeneticRelationships::Pedigree;
use CXGN::Pedigree::AddGrafts;
use CXGN::List::Validate;
use SGN::Model::Cvterm;
use utf8;

BEGIN { extends 'Catalyst::Controller::REST'; }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON'  },
   );

has 'schema' => (
		 is       => 'rw',
		 isa      => 'DBIx::Class::Schema',
		 lazy_build => 1,
		);


sub upload_grafts_verify : Path('/ajax/grafts/upload_verify') Args(0)  {
    my $self = shift;
    my $c = shift;
    my $session_id = $c->req->param("sgn_session_id");
    
    my $separator_string = $c->config->{graft_separator_string};

    my $user_id;
    my $user_name;
    my $user_role;

    STDERR->autoflush(1);
    
    print STDERR "checking session_id...\n";
    if ($session_id){
	print STDERR "We have a session id!\n";
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
	print STDERR "We do not have a session id...\n";
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to upload seedlots!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }
    
    #if (!any { $_ eq "curator" || $_ eq "submitter" }  ($user_role)  ) {
    if ($c->stash->{access}->denied( $user_id, "write", "stocks")) { 
	$c->stash->{rest} = {error =>  "You have insufficient privileges to add grafts." };
	return;
    }
    
    my $time = DateTime->now();
#    my $user_id = $c->user()->get_object()->get_sp_person_id();
#    my $user_name = $c->user()->get_object()->get_username();
    my $timestamp = $time->ymd()."_".$time->hms();
    my $subdirectory = 'graft_upload';
    
    my $upload = $c->req->upload('graft_uploaded_file');
    my $upload_tempfile  = $upload->tempname;
    
    my $upload_original_name  = $upload->filename();
    
    # check file type by file name extension
    #
    if ($upload_original_name =~ /\.xls$|\.xlsx/) {
	$c->stash->{rest} = { error => "Grafting upload requires a tab delimited file. Excel files (.xls and .xlsx) are currently not supported. Please convert the file and try again." };
	return;
    }
    
    my $md5;
    
#    my @user_roles = $c->user()->roles();
#    my $user_role = shift @user_roles;
    
    my $params = {
	tempfile => $upload_tempfile,
	subdirectory => $subdirectory,
	archive_path => $c->config->{archive_path},
	archive_filename => $upload_original_name,
	timestamp => $timestamp,
	user_id => $user_id,
	user_role => $user_role,
    };
    
    my $uploader = CXGN::UploadFile->new( $params );
    
    my %upload_metadata;
    my $archived_filename_with_path = $uploader->archive();
    
    if (!$archived_filename_with_path) {
	$c->stash->{rest} = {error => "Could not save file $upload_original_name in archive",};
	return;
    }
    
    $md5 = $uploader->get_md5($archived_filename_with_path);
    unlink $upload_tempfile;
    
    my ($header, $grafts) = _get_grafts_from_file($c, $archived_filename_with_path);
    
    my $info = $self->validate_grafts($c, $header, $grafts);
    
    $info->{archived_filename_with_path} = $archived_filename_with_path;
    $info->{success} = 1;
    
    $c->stash->{rest} = $info;
}

sub upload_grafts_store : Path('/ajax/grafts/upload_store') Args(0)  {
    my $self = shift;
    my $c = shift;
    my $archived_filename = $c->req->param('archived_filename');

    print STDERR "ARCHIVED FILENAME: $archived_filename\n";
    
    my $overwrite_grafts = $c->req->param('overwrite_grafts') ne 'false' ? $c->req->param('overwrite_grafts') : 0;
    my $session_id = $c->req->param("sgn_session_id");
    
    my $separator_string = $c->config->{graft_separator_string};

    my $user_id;
    my $user_role;
    my $user_name;
    
    if ($session_id){
	print STDERR "We have a session id!\n";
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
	print STDERR "We do not have a session id...\n";
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to upload seedlots!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }
    
    #if (!any { $_ eq "curator" || $_ eq "submitter" } ($user_role)  ) {
    if ($c->stash->{access}->denied($user_id, "write", "stocks")) { 
	$c->stash->{rest} = {error =>  "You have insufficient privileges to add grafts." };
	return;
    }

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    
    my ($header, $grafts) = _get_grafts_from_file($c, $archived_filename);
    
    my $info = $self->validate_grafts($c, $header, $grafts);
    
    print STDERR "FILE CONTENTS: ".Dumper($grafts);
    
    my @added_grafts;
    my @grafts_already_present;
    my @error_grafts;

    if (exists($info->{grafts_already_present}) && defined($info->{grafts_already_present})) {
	@grafts_already_present = @{$info->{grafts_already_present}};
    }
    my $error;
    foreach my $g (@$grafts) {
	my ($scion, $rootstock) = @$g;
	print STDERR "Storing scion & rootstock: $scion & $rootstock.\n";
	my $add = CXGN::Pedigree::AddGrafts->new({ schema=>$schema });
	$add->scion($scion);
	$add->rootstock($rootstock);
	
	my $info = $add->add_grafts($separator_string);

	print STDERR "Added grafts info: ".Dumper($info);
	
	if (exists($info->{errors}) && defined($info->{error}) && $info->{error} ne ''){
	    push @error_grafts, $info->{error};
	}
	else {
	    push @added_grafts, $info->{graft};
	}
    }
    
    if (@error_grafts){
        $c->stash->{rest} = { error => join(", ",@error_grafts) };
        $c->detach();
    }
    $c->stash->{rest} = { success => 1, added_grafts => \@added_grafts, grafts_already_present =>\@grafts_already_present };
}

sub validate_grafts {
    my $self = shift;
    my $c = shift;
    my $header = shift;
    my $grafts = shift;
    
    # check if all accessions exist
    #
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $separator_string = $c->config->{graft_separator_string};
    
    my ($scion_accession, $rootstock_accession) = @$header;

    my %header_errors;
    my @grafts_already_present;
    my @missing_accessions;
    
    if ($scion_accession ne 'scion accession') {
	$header_errors{'scion accession'} = "First column must have header 'scion accession' (not '$scion_accession'); ";
    }
    
    if ($rootstock_accession ne 'rootstock accession') {
	$header_errors{'rootstock accession'} = "Second column must have header 'rootstock accession' (not '$rootstock_accession'); ";
    }
    
    if (%header_errors) {
	my $error = join "<br />", values %header_errors;
	return { error => $error  };
    }
    
    my @errors;
    foreach my $g (@$grafts) { 
	
	my ($scion, $rootstock) = @$g;
	
	if ($scion eq $rootstock) {
	    push @errors, "Scion and rootstock ($scion and $rootstock) designate the same accession. Not generating a graft.\n";
	    
	}
	
	my $add = CXGN::Pedigree::AddGrafts->new({ schema=>$schema });
	$add->scion($scion);
	$add->rootstock($rootstock);
       
	my $graft_check = $add->validate_grafts($separator_string);

	if ($graft_check) { 
	    push @missing_accessions, @{$graft_check->{missing_accessions}};
	    push @grafts_already_present, @{$graft_check->{grafts_already_present}};
	}
	
	if (defined($graft_check->{errors}) && @{$graft_check->{errors}} > 0){
	    push @errors, "There was a problem validating graft between $scion and $rootstock (".join("\n", @{$graft_check->{errors}}).")";
	}
    }

    if (@grafts_already_present == @$grafts) {
	push @errors, "All grafts are already in the database. Nothing remains to be done :-) ";
    }
    
    if (@errors){
        return {error => join",", @errors };
    } else {
        return { success => 1, grafts_already_present => \@grafts_already_present, missing_accessions => \@missing_accessions };
    }
}

sub _get_grafts_from_file {
    my $c = shift;
    my $archived_filename_with_path = shift;
    
    open(my $F, "< :encoding(UTF-8)", $archived_filename_with_path) || die "Can't open file $archived_filename_with_path";
    my $header = <$F>;
    $header =~ s/\r//g;
    chomp($header);

    my @header = split/\t/, $header;

    foreach my $h (@header) {
	$h =~ s/^\s+|\s+$//g
    }
    
    my @grafts;
    my $line_num = 2;
    while (<$F>) {
	chomp;
	s/\r//g;
	my ($scion, $rootstock) = split /\t/;
	
	$scion =~ s/^\s+|\s+$//g;     # trim whitespace from front and end..
	$rootstock =~ s/^\s+|\s+$//g; # trim also
	push @grafts, [ $scion, $rootstock ];
    }

    return \@header, \@grafts;
}

=head2 get_full_graft

Usage:
    GET "/ajax/grafts/get_full?stock_id=<STOCK_ID>";

Responds with JSON array containing graft relationship objects for the
accession identified by STOCK_ID and all of its parents (recursively).

=cut


=head2 get_relationships

Usage:
    POST "/ajax/grafts/get_relationships";
    BODY "stock_id=<STOCK_ID>[&stock_id=<STOCK_ID>...]"

Responds with JSON array containing graft relationship objects for the
accessions identified by the provided STOCK_IDs.

=cut

sub get_relationships : Path('/ajax/grafts/get_relationships') : ActionClass('REST') { }
sub get_relationships_POST {
    my $self = shift;
    my $c = shift;
    my $stock_ids = [];
    my $s_ids = $c->req->body_params->{stock_id};
    push @{$stock_ids}, (ref $s_ids eq 'ARRAY' ? @$s_ids : $s_ids);
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $mother_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'female_parent', 'stock_relationship')->cvterm_id();
    my $father_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'male_parent', 'stock_relationship')->cvterm_id();
    my $accession_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $nodes = [];
    while (@{$stock_ids}){
        push @{$nodes}, _get_relationships($schema, $mother_cvterm, $father_cvterm, $accession_cvterm, (shift @{$stock_ids}));
    }
    $c->stash->{rest} = $nodes;
}

sub _get_relationships {
    my $schema = shift;
    my $mother_cvterm = shift;
    my $father_cvterm = shift;
    my $accession_cvterm = shift;
    my $stock_id = shift;
    my $name = $schema->resultset("Stock::Stock")->find({stock_id=>$stock_id})->uniquename();
    my $parents = _get_graft_parents($schema, $mother_cvterm, $father_cvterm, $accession_cvterm, $stock_id);
    my $children = _get_graft_children($schema, $mother_cvterm, $father_cvterm, $accession_cvterm, $stock_id);
    return {
        id => $stock_id,
        name=>$name,
        parents=> $parents,
        children=> $children
    };
}

sub _get_graft_parents {
    my $schema = shift;
    my $mother_cvterm = shift;
    my $father_cvterm = shift;
    my $accession_cvterm = shift;
    my $stock_id = shift;
    my $edges = $schema->resultset("Stock::StockRelationship")->search([
        {
            'me.object_id' => $stock_id,
            'me.type_id' => $father_cvterm,
            'subject.type_id'=> $accession_cvterm
        },
        {
            'me.object_id' => $stock_id,
            'me.type_id' => $mother_cvterm,
            'subject.type_id'=> $accession_cvterm
        }
    ],{join => 'subject'});
    my $parents = {};
    while (my $edge = $edges->next) {
        if ($edge->type_id==$mother_cvterm){
            $parents->{mother}=$edge->subject_id;
        } else {
            $parents->{father}=$edge->subject_id;
        }
    }
    return $parents;
}

sub _get_graft_children {
    my $schema = shift;
    my $mother_cvterm = shift;
    my $father_cvterm = shift;
    my $accession_cvterm = shift;
    my $stock_id = shift;
    my $edges = $schema->resultset("Stock::StockRelationship")->search([
        {
            'me.subject_id' => $stock_id,
            'me.type_id' => $father_cvterm,
            'object.type_id'=> $accession_cvterm
        },
        {
            'me.subject_id' => $stock_id,
            'me.type_id' => $mother_cvterm,
            'object.type_id'=> $accession_cvterm
        }
    ],{join => 'object'});
    my $children = {};
    $children->{mother_of}=[];
    $children->{father_of}=[];
    while (my $edge = $edges->next) {
        if ($edge->type_id==$mother_cvterm){
            push @{$children->{mother_of}}, $edge->object_id;
        } else {
            push @{$children->{father_of}}, $edge->object_id;
        }
    }
    return $children;
}

# sub _trait_overlay {
#     my $schema = shift;
#     my $node_list = shift;
# }


1;
