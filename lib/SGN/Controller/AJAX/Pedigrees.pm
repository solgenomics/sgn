
package SGN::Controller::AJAX::Pedigrees;

use Moose;
use List::Util qw | any |;
use File::Slurp qw | read_file |;
use Data::Dumper;
use Bio::GeneticRelationships::Individual;
use Bio::GeneticRelationships::Pedigree;
use CXGN::Pedigree::AddPedigrees;
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


sub upload_pedigrees_verify : Path('/ajax/pedigrees/upload_verify') Args(0)  {
    my $self = shift;
    my $c = shift;

    if (!$c->user()) {
	print STDERR "User not logged in... not uploading pedigrees.\n";
	$c->stash->{rest} = {error => "You need to be logged in to upload pedigrees." };
	return;
    }

    if (!any { $_ eq "curator" || $_ eq "submitter" } ($c->user()->roles)  ) {
	$c->stash->{rest} = {error =>  "You have insufficient privileges to add pedigrees." };
	return;
    }

    my $time = DateTime->now();
    my $user_id = $c->user()->get_object()->get_sp_person_id();
    my $user_name = $c->user()->get_object()->get_username();
    my $timestamp = $time->ymd()."_".$time->hms();
    my $subdirectory = 'pedigree_upload';

    my $upload = $c->req->upload('pedigrees_uploaded_file');
    my $upload_tempfile  = $upload->tempname;

    my $upload_original_name  = $upload->filename();

    # check file type by file name extension
    #
    if ($upload_original_name =~ /\.xls$|\.xlsx/) {
	$c->stash->{rest} = { error => "Pedigree upload requires a tab delimited file. Excel files (.xls and .xlsx) are currently not supported. Please convert the file and try again." };
	return;
    }

    my $md5;

    my @user_roles = $c->user()->roles();
    my $user_role = shift @user_roles;

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

    # check if all accessions exist
    #
    open(my $F, "< :encoding(UTF-8)", $archived_filename_with_path) || die "Can't open archive file $archived_filename_with_path";
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my %stocks;

    my $header = <$F>;
    $header =~ s/\r//g;
    chomp($header);
    my ($progeny_name, $female_parent_accession, $male_parent_accession, $type) =split /\t/, $header;

    my %header_errors;

    if ($progeny_name ne 'progeny name') {
	$header_errors{'progeny name'} = "First column must have header 'progeny name' (not '$progeny_name'); ";
    }

    if ($female_parent_accession ne 'female parent accession') {
	$header_errors{'female parent accession'} = "Second column must have header 'female parent accession' (not '$female_parent_accession'); ";
    }

    if ($male_parent_accession ne 'male parent accession') {
	$header_errors{'male parent accession'} = "Third column must have header 'male parent accession' (not '$male_parent_accession'); ";
    }

    if ($type ne 'type') {
	$header_errors{'type'} = "Fourth column must have header 'type' (not '$type');";
    }

    if (%header_errors) {
	my $error = join "<br />", values %header_errors;
	$c->stash->{rest} = { error => $error, archived_filename_with_path => $archived_filename_with_path };
	return;
    }

    my %legal_cross_types = ( biparental => 1, open => 1, self => 1, sib => 1, polycross => 1, backcross => 1, reselected => 1 );
    my %errors;

    while (<$F>) {
        chomp;
        $_ =~ s/\r//g;
        my @acc = split /\t/;
        for(my $i=0; $i<3; $i++) {
            if ($acc[$i] =~ /\,/) {
                my @a = split /\s*\,\s*/, $acc[$i];  # a comma separated list for an open pollination can be given
                foreach (@a) {
                    if ($_){
                        $_ =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
                        $stocks{$_}++;
                    }
                };
            }
            else {
                if ($acc[$i]){
                    $acc[$i] =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
                    $stocks{$acc[$i]}++;
                }
            }
        }

        # check if the cross types are recognized...
	#
        if ($acc[3] && !exists($legal_cross_types{lc($acc[3])})) {
            $errors{"not legal cross type: $acc[3] (should be biparental, self, open, sib, backcross, reselected or polycross)"}=1;
        }
    }
    close($F);
    my @unique_stocks = keys(%stocks);
    my $accession_validator = CXGN::List::Validate->new();
    my @accessions_missing = @{$accession_validator->validate($schema,'accessions_or_populations',\@unique_stocks)->{'missing'}};
    my $cross_validator = CXGN::List::Validate->new();
    my @stocks_missing = @{$cross_validator->validate($schema,'crosses',\@accessions_missing)->{'missing'}};
    if (scalar(@stocks_missing)>0){
        $errors{"The following parents or progenies are not in the database: ".(join ",", @stocks_missing)} = 1;
    }

    if (%errors) {
        $c->stash->{rest} = { error => "There were problems loading the pedigree for the following accessions or populations: ".(join ",", keys(%errors)).". Please fix these errors and try again. (errors: ".(join ", ", values(%errors)).")" };
        return;
    }

    print STDERR "UploadPedigreeCheck1".localtime()."\n";
    my $pedigrees = _get_pedigrees_from_file($c, $archived_filename_with_path);
    print STDERR "UploadPedigreeCheck2".localtime()."\n";

    my $add = CXGN::Pedigree::AddPedigrees->new({ schema=>$schema, pedigrees=>$pedigrees });
    my $error;

    my $pedigree_check = $add->validate_pedigrees();
    print STDERR "UploadPedigreeCheck3".localtime()."Complete\n";
    #print STDERR Dumper $pedigree_check;
    if (!$pedigree_check){
        $error = "There was a problem validating pedigrees. Pedigrees were not stored.";
    }
    if ($pedigree_check->{error}){
        $c->stash->{rest} = {error => $pedigree_check->{error}, archived_file_name => $archived_filename_with_path};
    } else {
        $c->stash->{rest} = {archived_file_name => $archived_filename_with_path};
    }
}

sub upload_pedigrees_store : Path('/ajax/pedigrees/upload_store') Args(0)  {
    my $self = shift;
    my $c = shift;
    my $archived_file_name = $c->req->param('archived_file_name');
    my $overwrite_pedigrees = $c->req->param('overwrite_pedigrees') ne 'false' ? $c->req->param('overwrite_pedigrees') : 0;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $pedigrees = _get_pedigrees_from_file($c, $archived_file_name);

    my $add = CXGN::Pedigree::AddPedigrees->new({ schema=>$schema, pedigrees=>$pedigrees });
    my $error;

    my $return = $add->add_pedigrees($overwrite_pedigrees);
    #print STDERR Dumper $return;
    if (!$return){
        $error = "The pedigrees were not stored";
    }
    if ($return->{error}){
        $error = $return->{error};
    }

    if ($error){
        $c->stash->{rest} = { error => $error };
        $c->detach();
    }
    $c->stash->{rest} = { success => 1 };
}

sub _get_pedigrees_from_file {
    my $c = shift;
    my $archived_filename_with_path = shift;

    open(my $F, "< :encoding(UTF-8)", $archived_filename_with_path) || die "Can't open file $archived_filename_with_path";
    my $header = <$F>;
    my @pedigrees;
    my $line_num = 2;
    while (<$F>) {
        my $female_parent;
        my $male_parent;
        chomp;
        $_ =~ s/\r//g;
        my ($progeny, $female, $male, $cross_type) = split /\t/;
        $progeny =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
        $female =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
        $male =~ s/^\s+|\s+$//g; #trim whitespace from front and end...

        if (!$female && !$male) {
            $c->stash->{rest} = { error => "No male parent and no female parent on line $line_num!" };
            $c->detach();
        }
        if (!$progeny) {
            $c->stash->{rest} = { error => "No progeny specified on line $line_num!" };
            $c->detach();
        }
        if (!$female) {
            $c->stash->{rest} = { error => "No female parent on line $line_num for $progeny!" };
            $c->detach();
        }
        if (!$cross_type){
            $c->stash->{rest} = { error => "No cross type on line $line_num! Must be one of these: biparental, open, self, sib, backcross, reselected, polycross." };
            $c->detach();
        }
        if ($cross_type ne 'biparental' && $cross_type ne 'open' && $cross_type ne 'self' && $cross_type ne 'sib' && $cross_type ne 'polycross' && $cross_type ne 'backcross' && $cross_type ne 'reselected'){
            $c->stash->{rest} = { error => "Invalid cross type on line $line_num! Must be one of these: biparental, open, self, backcross, sib, reselected, polycross." };
            $c->detach();
        }
        if ($female eq $male) {
            if ($cross_type ne 'self' && $cross_type ne 'sib' && $cross_type ne 'reselected'){
                $c->stash->{rest} = { error => "Female parent and male parent are the same on line $line_num, but cross type is not self, sib or reselected." };
                $c->detach();
            }
        }
        if (($female && !$male) && ($cross_type ne 'open')) {
            $c->stash->{rest} = { error => "For $progeny on line number $line_num no male parent specified and cross_type is not open..." };
            $c->detach();
        }

        if(($cross_type eq "self") || ($cross_type eq "reselected")) {
            $female_parent = Bio::GeneticRelationships::Individual->new( { name => $female });
            $male_parent = Bio::GeneticRelationships::Individual->new( { name => $female });
        }
        elsif($cross_type eq 'biparental') {
            if (!$male){
                $c->stash->{rest} = { error => "For $progeny Cross Type is biparental, but no male parent given" };
                $c->detach();
            }
            $female_parent = Bio::GeneticRelationships::Individual->new( { name => $female });
            $male_parent = Bio::GeneticRelationships::Individual->new( { name => $male });
        }
        elsif($cross_type eq 'backcross') {
            if (!$male){
                $c->stash->{rest} = { error => "For $progeny Cross Type is backcross, but no male parent given" };
                $c->detach();
            }
            $female_parent = Bio::GeneticRelationships::Individual->new( { name => $female });
            $male_parent = Bio::GeneticRelationships::Individual->new( { name => $male });
        }
        elsif($cross_type eq "sib") {
            if (!$male){
                $c->stash->{rest} = { error => "For $progeny Cross Type is sib, but no male parent given" };
                $c->detach();
            }
            $female_parent = Bio::GeneticRelationships::Individual->new( { name => $female });
            $male_parent = Bio::GeneticRelationships::Individual->new( { name => $male });
        }
        elsif($cross_type eq "polycross") {
            if (!$male){
                $c->stash->{rest} = { error => "For $progeny Cross Type is polycross, but no male parent given" };
                $c->detach();
            }
            $female_parent = Bio::GeneticRelationships::Individual->new( { name => $female });
            $male_parent = Bio::GeneticRelationships::Individual->new( { name => $male });
        }
        elsif($cross_type eq "open") {
            $female_parent = Bio::GeneticRelationships::Individual->new( { name => $female });
            $male_parent = undef;
            if ($male){
                $male_parent = Bio::GeneticRelationships::Individual->new( { name => $male });
            }

        }

        my $opts = {
            cross_type => $cross_type,
            female_parent => $female_parent,
            name => $progeny
        };

        if ($male_parent) {
            $opts->{male_parent} = $male_parent;
        }

        my $p = Bio::GeneticRelationships::Pedigree->new($opts);
        push @pedigrees, $p;
        $line_num++;
    }
    return \@pedigrees;
}

=head2 get_full_pedigree

Usage:
    GET "/ajax/pedigrees/get_full?stock_id=<STOCK_ID>";

Responds with JSON array containing pedigree relationship objects for the
accession identified by STOCK_ID and all of its parents (recursively).

=cut

sub get_full_pedigree : Path('/ajax/pedigrees/get_full') : ActionClass('REST') { }
sub get_full_pedigree_GET {
    my $self = shift;
    my $c = shift;
    my $stock_id = $c->req->param('stock_id');
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $mother_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'female_parent', 'stock_relationship')->cvterm_id();
    my $father_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'male_parent', 'stock_relationship')->cvterm_id();
    my $accession_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my @queue = ($stock_id);
    my $nodes = [];
    while (@queue){
        my $node = pop @queue;
        my $relationships = _get_relationships($schema, $mother_cvterm, $father_cvterm, $accession_cvterm, $node);
        if ($relationships->{parents}->{mother}){
            push @queue, $relationships->{parents}->{mother};
        }
        if ($relationships->{parents}->{father}){
            push @queue, $relationships->{parents}->{father};
        }
        push @{$nodes}, $relationships;
    }
    $c->stash->{rest} = $nodes;
}

=head2 get_relationships

Usage:
    POST "/ajax/pedigrees/get_relationships";
    BODY "stock_id=<STOCK_ID>[&stock_id=<STOCK_ID>...]"

Responds with JSON array containing pedigree relationship objects for the
accessions identified by the provided STOCK_IDs.

=cut

sub get_relationships : Path('/ajax/pedigrees/get_relationships') : ActionClass('REST') { }
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
    my $parents = _get_pedigree_parents($schema, $mother_cvterm, $father_cvterm, $accession_cvterm, $stock_id);
    my $children = _get_pedigree_children($schema, $mother_cvterm, $father_cvterm, $accession_cvterm, $stock_id);
    return {
        id => $stock_id,
        name=>$name,
        parents=> $parents,
        children=> $children
    };
}

sub _get_pedigree_parents {
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

sub _get_pedigree_children {
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
