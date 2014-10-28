
package SGN::Controller::AJAX::Pedigrees;

use Moose;
use List::Util qw | any |;
use File::Slurp qw | read_file |;
use Bio::GeneticRelationships::Individual;
use Bio::GeneticRelationships::Pedigree;
use CXGN::Pedigree::AddPedigrees;

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
   
    print STDERR "UPLOAD_PEDIGREES...\n";
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
    my $md5;

    my $uploader = CXGN::UploadFile->new();

    my %upload_metadata;
  ## Store uploaded temporary file in archive
    print STDERR "TEMP FILE: $upload_tempfile\n";
    my $archived_filename_with_path = $uploader->archive($c, $subdirectory, $upload_tempfile, $upload_original_name, $timestamp);

    if (!$archived_filename_with_path) {
	$c->stash->{rest} = {error => "Could not save file $upload_original_name in archive",};
	return;
    }
    $md5 = $uploader->get_md5($archived_filename_with_path);
    unlink $upload_tempfile;
    
    $upload_metadata{'archived_file'} = $archived_filename_with_path;
    $upload_metadata{'archived_file_type'}="trial upload file";
    $upload_metadata{'user_id'}=$user_id;
    $upload_metadata{'date'}="$timestamp";
    
    # check if all accessions exist
    #
    open(my $F, "<", $archived_filename_with_path) || die "Can't open archive file $archived_filename_with_path";
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my %stocks;
    while (<$F>) { 
	chomp;
	my @acc = split /\t/;
	if ($acc[3] eq "self") { 
	    $stocks{$acc[0]}++;
	    $stocks{$acc[1]}++;
	}
	elsif ($acc[3] eq "biparental" || !$acc[3]) { 
	    $stocks{$acc[0]}++;
	    $stocks{$acc[1]}++;
	    $stocks{$acc[2]}++;
	}
	else { 
	    $c->stash->{rest} = { error => "Unknown crosstype $acc[3]. Must be one of self, biparental, or empty (default biparental)" };
	    return;
	}
    }   
    
    my @unique_stocks = keys(%stocks);
    my %errors = $self->check_stocks($c, \@unique_stocks);

    if (%errors) { 
	$c->stash->{rest} = { error => "The following accessions are not in the database: ".(join ",", keys(%errors)).". Please fix these errors and try again." };
	return;
    }
    close($F);

    open($F, "<", $archived_filename_with_path) || die "Can't open file $archived_filename_with_path";

    my $female_parent;
    my $male_parent;
    my $child;
    my $cross_type;
    while (<$F>) { 
	chomp;
	my @f = split /\t/;
	
	if ($f[3] eq "self") { 
	    $female_parent = Bio::GeneticRelationships::Individual->new( { name => $f[1] });
	    $male_parent = Bio::GeneticRelationships::Individual->new( { name => $f[1] });
	    $child = Bio::GeneticRelationships::Individual->new( { name => $f[0] });
	    $cross_type = "self";
	}
	elsif($f[3] eq "biparental" || !$f[3]) { 
	    $female_parent = Bio::GeneticRelationships::Individual->new( { name => $f[1] });
	    $male_parent = Bio::GeneticRelationships::Individual->new( { name => $f[2] });
	    $child = Bio::GeneticRelationships::Individual->new( { name =>  $f[0] } );
	    $cross_type = "biparental";
	}
	my $p = Bio::GeneticRelationships::Pedigree->new( { 
	    cross_type => $cross_type,
	    female_parent => $female_parent,
	    male_parent => $male_parent,
	    name => $child
							  
							  });
    }
    $c->stash->{rest} = { success => 1 };
}

sub check_stocks { 
    my $self = shift;
    my $c = shift;
    my $stock_names = shift;

    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my %errors;
    my $error_alert = "";
    
    foreach my $stock_name (@$stock_names) {	
	my $stock;
	my $number_of_stocks_found;
	my $stock_lookup = CXGN::Stock::StockLookup->new(schema => $schema);
	$stock_lookup->set_stock_name($stock_name);
	$stock = $stock_lookup->get_stock();
	$number_of_stocks_found = $stock_lookup->get_matching_stock_count();
	if ($number_of_stocks_found > 1) {
	    $errors{$stock_name} = "Multiple stocks found matching $stock_name\n";
	}
	if (!$number_of_stocks_found) {
	    $errors{$stock_name} = "No stocks found matching $stock_name\n";
	}
    }

    return %errors;
}



1; 
