
package SGN::Controller::AJAX::Accessions::Rename;

use Moose;

use Data::Dumper;
use List::MoreUtils qw| any |;
use File::Temp qw| tempfile |;

use CXGN::List::Validate;


BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON'  },
   );


has 'schema' => (
		 is       => 'rw',
		 isa      => 'DBIx::Class::Schema',
		);


sub upload_rename_accessions_verify : Path('/ajax/rename_accessions/upload_verify') Args(0)  {
    my $self = shift;
    my $c = shift;
    my $session_id = $c->req->param("sgn_session_id");
    
    #my $separator_string = $c->config->{graft_separator_string};

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

	print STDERR "USER ROLE = $user_role\n";
    }
    
    if ($user_role ne "curator") {
	$c->stash->{rest} = {error =>  "You have insufficient privileges to rename accessions." };
	return;
    }
    
    my $time = DateTime->now();
#    my $user_id = $c->user()->get_object()->get_sp_person_id();
#    my $user_name = $c->user()->get_object()->get_username();
    my $timestamp = $time->ymd()."_".$time->hms();
    my $subdirectory = 'rename_accessions_upload';
    
    my $upload = $c->req->upload('rename_accessions_uploaded_file');
    my $upload_tempfile  = $upload->tempname;
    
    my $upload_original_name  = $upload->filename();
    
    # check file type by file name extension
    #
    if ($upload_original_name =~ /\.xls$|\.xlsx/) {
	$c->stash->{rest} = { error => "The rename accessions funtion requires a tab delimited file. Excel files (.xls and .xlsx) are currently not supported. Please convert the file and try again." };
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
    
    my ($header, $rename) = $self->_get_rename_accessions_from_file($c, $archived_filename_with_path);

    my $success = 1;
    
    my $info = $self->validate_rename_accessions($c, $header, $rename);
    my @errors;
    
    if (ref($info->{must_exist_missing}) eq "ARRAY" && scalar(@{ $info->{must_exist_missing}}) > 0) {
	$success = 0;
	print STDERR "There are missing accessions in the left column! That's an error!\n";
	push @errors, scalar(@{$info->{must_exist_missing}})." accession(s) to be renamed do not exist in the database. ". join("<br />", @{$info->{must_exist_missing}});
    }

    if (@{$info->{must_not_exist_present}}>0)  {
	$success = 0;
	push @errors, scalar(@{$info->{must_not_exist_present}})." accessions that are target of renames are already in the database. ".join("<br />", @{$info->{must_not_exist_present}});
    }
    
    $info->{archived_filename_with_path} = $archived_filename_with_path;
    $info->{success} = $success;

    if (@errors) {
	$info->{error} = join("<br />", @errors);
    }
    $c->stash->{rest} = $info;
}

sub upload_rename_accessions_store : Path('/ajax/rename_accessions/upload_store') Args(0)  {
    my $self = shift;
    my $c = shift;
    my $archived_filename = $c->req->param('archived_filename');
    my $store_old_name_as_synonym = $c->req->param('store_old_name_as_synonym');

    print STDERR "ARCHIVED FILENAME: $archived_filename\n";
    print STDERR "store_old_name_as_synonym = $store_old_name_as_synonym\n";
    my $session_id = $c->req->param("sgn_session_id");
    
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
    
    if (!any { $_ eq "curator" || $_ eq "submitter" } ($user_role)  ) {
	$c->stash->{rest} = {error =>  "You have insufficient privileges to rename accessions." };
	return;
    }

    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado", $user_id);
    
    my ($header, $rename) = $self->_get_rename_accessions_from_file($c, $archived_filename);

    my $info = $self->validate_rename_accessions($c, $header, $rename);
    
    print STDERR "FILE CONTENTS: ".Dumper($rename);
    
    my @renamed_accessions;
    my @accessions_already_present;
    my @error_accessions;
    
    if (exists($info->{accessions_already_present}) && defined($info->{accessions_already_present})) {
	@accessions_already_present = @{$info->{accessions_already_present}};
    }
    my $error;
    
    foreach my $g (@$rename) {
	my ($old_accession_name, $new_accession_name) = @$g;
	
	
	my $stock = CXGN::Stock->new( { schema => $schema, uniquename => $old_accession_name });
	
	$stock->uniquename($new_accession_name);
	
	if ($store_old_name_as_synonym eq "on") {
	    print STDERR "Storing old name ($old_accession_name) as synonym for $new_accession_name.\n";
	    $stock->add_synonym($old_accession_name);
	}
	else {
	    print STDERR "Synonym storing not requested. \n";
	}
	
	$stock->store();
	
	if (exists($info->{errors}) && defined($info->{error}) && $info->{error} ne ''){
	    push @error_accessions, $info->{error};
	}
	else {
	    push @renamed_accessions, $info->{renamed_accession};
	}
    }
    
    if (@error_accessions){
	$c->stash->{rest} = { error => join(", ",@error_accessions) };
        $c->detach();
    }
    $c->stash->{rest} = { success => 1, renamed_accession_count => \@renamed_accessions, renamed_accessions => $rename };
}

sub _get_rename_accessions_from_file {
    my $self = shift;
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
    
    my @rename;
    my $line_num = 2;
    while (<$F>) {
	chomp;
	s/\r//g;
	my ($old_accession_name, $new_accession_name) = split /\t/;
	
	$old_accession_name =~ s/^\s+|\s+$//g;     # trim whitespace from front and end..
	$new_accession_name =~ s/^\s+|\s+$//g; # trim also
	push @rename, [ $old_accession_name, $new_accession_name ];
    }
    
    return (\@header, \@rename);
}


sub validate_rename_accessions {
    my $self = shift;
    my $c = shift;
    my $header = shift;
    my $rename = shift;
    
    my $error = "";
    
    if ($header->[0] ne "old_name") {
	$error = "Column 1 header must be old_name. "; 
    }
    if ($header->[1] ne "new_name") {
	$error .= "Column 2 header must be new_name. ";
    }
    
    my @must_exist = map { $_->[0] } @$rename;
    
    my @must_not_exist = map { $_->[1] } @$rename;

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    $self->schema( $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id) );
    print STDERR "INPUT MUST EXIST: ".Dumper(\@must_exist);
    print STDERR "INPUT MUST NOT EXIST: ".Dumper(\@must_not_exist);
    my $list_validate = CXGN::List::Validate->new();
    
    my $must_exist_data = $list_validate->validate( $self->schema, 'accessions', \@must_exist );
    
    print STDERR "MUST EXIST: ".Dumper($must_exist_data);
    
    my $must_not_exist_data = $list_validate->validate( $self->schema, 'accessions', \@must_not_exist );
    
    my @missing = ();
    if (ref($must_not_exist_data->{missing})) { 
	@missing = @{$must_not_exist_data->{missing}};
    }
    
    print STDERR "MUST NOT EXIST MISSING: ".Dumper(\@missing);
    
    my @must_not_exist_but_present = ();
    foreach my $m (@must_not_exist) {
	print STDERR "checking $m...\n";
	if (! any { $m eq $_ } @missing) {
	    print STDERR "... $m is present, but most not exist!\n";
	    push @must_not_exist_but_present, $m;
	}
    }
    
    print STDERR "MUST NOT EXIST BUT PRESENT: ".Dumper(\@must_not_exist_but_present);
    
    return { error => $error, must_exist_missing => $must_exist_data->{missing}, must_not_exist_present => \@must_not_exist_but_present };
}

    

1;

