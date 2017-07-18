
package SGN::Controller::AJAX::Pedigrees;

use Moose;
use List::Util qw | any |;
use File::Slurp qw | read_file |;
use Data::Dumper;
use Bio::GeneticRelationships::Individual;
use Bio::GeneticRelationships::Pedigree;
use CXGN::Pedigree::AddPedigrees;
use CXGN::List::Validate;

BEGIN { extends 'Catalyst::Controller::REST'; }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );

has 'schema' => (
		 is       => 'rw',
		 isa      => 'DBIx::Class::Schema',
		 lazy_build => 1,
		);


sub upload_pedigrees : Path('/ajax/pedigrees/upload') Args(0)  { 
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

#    my $temp_contents = read_file($upload_tempfile);
#    $c->stash->{rest} = { error => $temp_contents };
#    return;

    my $upload_original_name  = $upload->filename();

    # check file type by file name extension
    #
    if ($upload_original_name =~ /\.xls$|\.xlsx/) { 
	$c->stash->{rest} = { error => "Pedigree upload requires a tab delimited file. Excel files (.xls and .xlsx) are currently not supported. Please convert the file and try again." };
	return;
    }

    my $md5;
    print STDERR "TEMP FILE: $upload_tempfile\n";
    my $uploader = CXGN::UploadFile->new({
      tempfile => $upload_tempfile,
      subdirectory => $subdirectory,
      archive_path => $c->config->{archive_path},
      archive_filename => $upload_original_name,
      timestamp => $timestamp,
      user_id => $user_id,
      user_role => $c->user()->roles
    });

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
    open(my $F, "<", $archived_filename_with_path) || die "Can't open archive file $archived_filename_with_path";
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my %stocks;

    my $header = <$F>; 
    my %legal_cross_types = ( biparental => 1, open => 1, self => 1);
    my %errors;

    while (<$F>) { 
	chomp;
	$_ =~ s/\r//g;
	my @acc = split /\t/;
	for(my $i=0; $i<3; $i++) {
	    if ($acc[$i] =~ /\,/) { 
		my @a = split /\s*\,\s*/, $acc[$i];  # a comma separated list for an open pollination can be given
		foreach (@a) { $stocks{$_}++ if $_ };
	    }
	    else { 
		$stocks{$acc[$i]}++ if $acc[$i];
	    }
	}
	# check if the cross types are recognized...
	if ($acc[3] && !exists($legal_cross_types{lc($acc[3])})) { 
	    $errors{"not legal cross type: $acc[3] (should be biparental, self, or open)"}=1;
	}
    }    
    my @unique_stocks = keys(%stocks);
    my $accession_validator = CXGN::List::Validate->new();
    my @accessions_missing = @{$accession_validator->validate($schema,'accessions',\@unique_stocks)->{'missing'}};
    if (scalar(@accessions_missing)>0){
        $errors{"The following accessions are not in the database: ".(join ",", @accessions_missing)} = 1;
    }

    if (%errors) { 
	$c->stash->{rest} = { error => "There were problems loading the pedigree for the following accessions: ".(join ",", keys(%errors)).". Please fix these errors and try again. (errors: ".(join ", ", values(%errors)).")" };
	return;
    }
    close($F);
    
    open($F, "<", $archived_filename_with_path) || die "Can't open file $archived_filename_with_path";
    $header = <$F>; 
    my $female_parent;
    my $male_parent;
    my $child;

    my $cross_type = "";

    my @pedigrees;

    ## NEW FILE STRUCTURE: progeny_name, female parent, male parent, cross_type
    
    while (<$F>) { 
	chomp;
	$_ =~ s/\r//g;
	my ($progeny, $female, $male, $cross_type) = split /\t/;
	
	if (!$female && !$male) { 
	    print STDERR "No parents specified... skipping.\n";
	    next;
	}
	if (!$progeny) { 
	    print STDERR "No progeny specified... skipping.\n";
	    next;
	}
	
	if (($female eq $male) && ($cross_type ne 'self')) { 
	    $cross_type = "self";
	}
	
	elsif ($female && !$male) { 
	    if ($cross_type ne 'open') { 
		print STDERR "No male parent specified and cross_type is not open... setting to unknown\n";
            $c->stash->{rest} = { error => "For $progeny No male parent specified and cross_type is not open..." };
            $c->detach();
	    }
	}
	
    if($cross_type eq "self") { 
        if (!$female){
            $c->stash->{rest} = { error => "For $progeny Cross Type is self, but no female parent given" };
            $c->detach();
        }
        $female_parent = Bio::GeneticRelationships::Individual->new( { name => $female });
        $male_parent = Bio::GeneticRelationships::Individual->new( { name => $female });
    }
    elsif($cross_type eq "biparental") {
        if (!$female || !$male){
            $c->stash->{rest} = { error => "For $progeny Cross Type is biparental, but no female or male parent given" };
            $c->detach();
        }
	    $female_parent = Bio::GeneticRelationships::Individual->new( { name => $female });
	    $male_parent = Bio::GeneticRelationships::Individual->new( { name => $male });
	}
	elsif($cross_type eq "open") { 
        if (!$female){
            $c->stash->{rest} = { error => "For $progeny Cross Type is open, but no female parent given" };
            $c->detach();
        }
	     $female_parent = Bio::GeneticRelationships::Individual->new( { name => $female });

	     $male_parent = undef;
	#      my $population_name = "";
	#      my @male_parents = split /\s*\,\s*/, $male;

	#      if ($male) {
	# 	 $population_name = join "_", @male_parents;
	#      }
	#      else { 
	# 	 $population_name = $female."_open";
	#      }
	#      $male_parent = Bio::GeneticRelationships::Population->new( { name => $population_name});
	#      $male_parent->set_members(\@male_parents);
	     

	#      my $population_cvterm_id = $c->model("Cvterm")->get_cvterm_row($schema, "population", "stock_type");
	#      my $male_parent_cvterm_id = $c->model("Cvterm")->get_cvterm_row($schema, "male_parent", "stock_relationship");

	#      # create population stock entry
	#      # 
	#      my $pop_rs = $schema->resultset("Stock::Stock")->create( 
	# 	 { 
	# 	     name => $population_name,
	# 	     uniquename => $population_name,
	# 	     type_id => $population_cvterm_id->cvterm_id(),
	# 	 });

	#       # generate population connections to the male parents
	#      foreach my $p (@male_parents) { 
	# 	 my $p_row = $schema->resultset("Stock::Stock")->find({ uniquename => $p });
	# 	 my $connection = $schema->resultset("Stock::StockRelationship")->create( 
	# 	     {
	# 		 subject_id => $pop_rs->stock_id,
	# 		 object_id => $p_row->stock_id,
	# 		 type_id => $male_parent_cvterm_id->cvterm_id(),
	# 	     });
	#      }
	#      $male = $population_name;
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
    }

    my $add = CXGN::Pedigree::AddPedigrees->new( { schema=>$schema, pedigrees=>\@pedigrees, validate_accessions=>0 });
    eval { 
        my $ok = $add->add_pedigrees();
        if (!$ok){
            die "The pedigrees were not stored";
        }
    };
    if ($@) { 
        $c->stash->{rest} = { error => "An error occurred while storing the provided pedigree. Please check your file and try again ($@)" };
        $c->detach();
    }
    
    $c->stash->{rest} = { success => 1 };
}


1; 
