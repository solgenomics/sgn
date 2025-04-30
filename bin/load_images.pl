#!/usr/bin/perl

=head1 NAME

load_images.pl

=head1 SYNOPSYS

load_images.pl -D database_name -H hostname -i dirname -r chado table name [script will load image ids into ChadoTableprop ]  

=head1 DESCRIPTION

Loads  images  into the SGN database, using the SGN::Image framework.
Then link the loaded image with the user-supplied chado objects (e.g. stock, nd_experiment)  

Requires the following parameters: 

=over 8

=item -D

database name 

=item -H 

host name 

=item -m 

map file. If provided links between stock names - image file name , is read from a mapping file.
Row labels are expected to be unique file names, column header for the associated stocks is 'name' 

=item -i

a dirname that contains image filenames or subdirectories named after database accessions, containing one or more images (see option -d) .

=item -u

use name - from sgn_people.sp_person. 

=item -b

the dir where the database stores the images (the concatenated values from image_path and image_dir from sgn_local.conf or sgn.conf)

=item -d

files are stored in sub directories named after database accessions 

=item -e 

image file extension. Defaults to 'jpg'

=item -t

trial mode . Nothing will be stored.

=back

Errors and messages are output on STDERR.

=head1 AUTHOR(S)

Naama Menda (nm249@cornell.edu) October 2010.

Tweaks and move to sgn/bin: Lukas Mueller (lam87@cornell.edu) December 2023.

=cut

use strict;

use CXGN::Metadata::Schema;
use CXGN::Metadata::Metadbdata;
use CXGN::DB::InsertDBH;
use CXGN::Image;
use Bio::Chado::Schema;
use CXGN::People::Person;
use Carp qw /croak/;
use Data::Dumper qw / Dumper /;

use File::Basename;
use SGN::Context;
use Getopt::Std;

use CXGN::Tools::File::Spreadsheet;
use File::Glob qw | bsd_glob |;

our ($opt_H, $opt_D, $opt_t, $opt_i, $opt_u, $opt_r, $opt_d, $opt_e, $opt_m, $opt_b);
getopts('H:D:u:i:e:f:tdr:m:b:');

my $dbhost = $opt_H;
my $dbname = $opt_D;
my $dirname = $opt_i;
my $sp_person=$opt_u;
my $db_image_dir = $opt_b;
my $chado_table = $opt_r;
my $ext = $opt_e || 'jpg';

if (!$dbhost && !$dbname) { 
    print "dbhost = $dbhost , dbname = $dbname\n";
    print "opt_t = $opt_t, opt_u = $opt_u, opt_r = $chado_table, opt_i = $dirname\n";
    usage();
}

if (!$dirname) { print "dirname = $dirname\n" ; usage(); }

my $dbh = CXGN::DB::InsertDBH->new( { dbhost=>$dbhost,
				      dbname=>$dbname,
				    } );

my $schema= Bio::Chado::Schema->connect(  sub { $dbh->get_actual_dbh() } ,  { on_connect_do => ['SET search_path TO  public;'] }
    );


print STDERR "Generate metadata_id... ";
my $metadata_schema = CXGN::Metadata::Schema->connect("dbi:Pg:database=$dbname;host=".$dbh->dbhost(), "postgres", $dbh->dbpass(), {on_connect_do => "SET search_path TO 'metadata', 'public'", });

my $sp_person_id= CXGN::People::Person->get_person_by_username($dbh, $sp_person);
my %name2id = ();


#my $ch = SGN::Context->new();
print "PLEASE VERIFY:\n";
print "Using dbhost: $dbhost. DB name: $dbname. \n";
print "Path to image is: $db_image_dir\n";
print "CONTINUE? ";
my $a = (<STDIN>);
if ($a !~ /[yY]/) { exit(); }

my %image_hash = ();  # used to retrieve images that are already loaded
my %connections = (); # keep track of object -- image connections that have already been made.

print STDERR "Caching stock table...\n";
my $object_rs = $schema->resultset("Stock::Stock")->search( { } ) ;
while (my $object = $object_rs->next ) {
    my $id = $object->stock_id;
    my $name = $object->uniquename;
    $name2id{lc($name)} = $id;
}

# cache image chado object - image links to prevent reloading of the
# same data
#
print "Caching image $chado_table links...\n";

my $q = "SELECT * FROM phenome.stock_image";
my $sth = $dbh->prepare($q);
$sth->execute();
while ( my $hashref = $sth->fetchrow_hashref() ) {
    my $image_id = $hashref->{image_id};
    my $chado_table_id = $hashref->{stock_id};  ##### table specific

    if ($chado_table_id % 10000 == 0) {
	print STDERR "CACHING $chado_table_id\n";
    }

    my $i = CXGN::Image->new(dbh=>$dbh, image_id=>$image_id, image_dir=>$db_image_dir); # SGN::Image...$ch
    my $original_filename = $i->get_original_filename();
    $image_hash{$original_filename} = $i; # this doesn't have the file extension
    $connections{$image_id."-".$chado_table_id}++;
}

#open (ERR, ">load_bcs_images.err") || die "Can't open error file\n";

my @files;
if (! $opt_d) { 
    @files = bsd_glob "$dirname/*.$ext";
}
else { 
    @files = bsd_glob "$dirname/*" if $opt_d ;
}

print STDERR "DIRS = ".(join("\n", @files))."\n";

my @sub_files;

my $new_image_count = 0;

my $metadata = CXGN::Metadata::Metadbdata->new($metadata_schema, $sp_person);
my $metadata_id = $metadata->store()->get_metadata_id();

#read from spreadsheet:
my $map_file = $opt_m; #
my %name_map;

if ($opt_m) {
    my $s = CXGN::Tools::File::Spreadsheet->new($map_file); #
    my @rows = $s->row_labels(); #
    my $image_id;
    foreach my $file_name (@rows) { #
    	my $stock_name = $s->value_at($file_name, 'name'); #
	$name_map{$file_name} = $stock_name;
	if (my $image_id = store_image($dbh, $db_image_dir, \%image_hash, \%name2id, $chado_table, $stock_name, $opt_i."/".$file_name, "", $sp_person_id, $new_image_count)) {
	    $new_image_count++;
	    
	    my $stock_row = $schema->resultset("Stock::Stock")->find( { uniquename => $stock_name } );
	    if (!$stock_row) {
		print STDERR "STOCK $stock_name NOT FOUND! PLEASE CHECK THIS!\n";
	    }
	    else { 
		print STDERR "FOUND STOCK $stock_name... associating...\n";
		link_image($image_id, $stock_row->stock_id, $metadata_id);
	    }
	}
    }

    print STDERR "DONE WITH MAPPING FILE $opt_m\n";
    exit(0);
}

print STDERR "Starting to process ".scalar(@files)." images...\n";

foreach my $file (@files) {
    eval {
	chomp($file);
	@sub_files = ($file);
	@sub_files =  bsd_glob "$file/*"; # if $opt_d;

	print STDERR "FILES FOR $file: ".Dumper(\@sub_files)."\n";

	my $object =  basename($file, ".$ext" );

#	if (!$plot) { die "File $file has no object name in it!"; }
	my $stock = $schema->resultset("Stock::Stock")->find( {
	    stock_id => $name2id{ lc($object) }  } );
	foreach my $filename (@sub_files) {
	 
	    chomp $filename;
	 
	    print STDERR "FILENAME NOW: $filename\n";
	    my $image_base = basename($filename);
	    my ($object_name, $description, $extension);
	    if ($opt_m) {
		$object_name = $name_map{$object . "." . $ext } ;
	    }
	    
	    print STDERR "OBJECT = $object...\n";
#	    if ($image_base =~ /(.*?)\_(.*?)(\..*?)?$/) { 
	    if ($image_base =~ m/(.*)(\.$ext)/i) { 
		$extension = $2;
		$image_base = $1;
	    }
	    if ($image_base =~ m/(.*)\_(.*)/)  { 
		$object_name = $1;
		$description = $2;

	    }
	    else { 
		$object_name = $image_base;
	    }
	    print STDERR "Object: $object OBJECT NAME: $object_name DESCRPTION: $description EXTENSIO: $extension\n";


	    print STDOUT "Processing file $file...\n";
	    print STDOUT "Loading $object_name, image $filename\n";
	    print STDERR "Loading $object_name, image $filename\n";
	    my $image_id; # this will be set later, depending if the image is new or not
	    if (! -e $filename) { 
		warn "The specified file $filename does not exist! Skipping...\n";
	    	next();
	    }

	    if (!exists($name2id{lc($object)})) { 
		message ("$object does not exist in the database...\n");
	    }

	    else {
		print STDERR "Adding $filename...\n";
		if (exists($image_hash{$filename})) { 
		    print STDERR "$filename is already loaded into the database...\n";
		    $image_id = $image_hash{$filename}->get_image_id();
		    $connections{$image_id."-".$name2id{lc($object)}}++;
		    if ($connections{$image_id."-".$name2id{lc($object)}} > 1) { 
			print STDERR "The connection between $object and image $filename has already been made. Skipping...\n";
		    }
		    elsif ($image_hash{$filename}) { 
			print STDERR qq  { Associating $chado_table $name2id{lc($object)} with already loaded image $filename...\n };
		    }
		}
		else { 
		    print STDERR qq { Generating new image object for image $filename and associating it with $chado_table $object, id $name2id{lc($object) } ...\n };

		    if ($opt_t)  { 
			print STDOUT qq { Would associate file $filename to $chado_table $object_name, id $name2id{lc($object)}\n };
			$new_image_count++;
		    }
		    else { 
			# my $image = CXGN::Image->new(dbh=>$dbh, image_dir=>$db_image_dir);   
			# $image_hash{$filename}=$image;

			# my $error;
			# ($image_id, $error) = $image->process_image("$filename", $chado_table , $name2id{lc($object)}, 1);

			# print STDERR "IMAGE ID $image_id, ERROR: $error\n";

			# if ($error eq "ok") { 
			#     $image->set_description("$description");
			#     $image->set_name(basename($filename , ".$ext"));
			#     $image->set_sp_person_id($sp_person_id);
			#     $image->set_obsolete("f");
			#     $image_id = $image->store();
			#     #link the image with the BCS object 
			#     $new_image_count++;
			#     my $image_subpath = $image->image_subpath();
			#     print STDERR "FINAL IMAGE PATH = $db_image_dir/$image_subpath\n";
			#}

			if ($image_id = store_image($dbh, $db_image_dir, \%image_hash, \%name2id, $chado_table, $object, $filename, $description, $sp_person_id, $new_image_count)) {
			    $new_image_count++;
			}
		    }
		}
	    }

	    link_image($image_id, $name2id{lc($object)}, $metadata_id);
	    
	    # print STDERR "Connecting image $filename and id $image_id with stock ".$stock->stock_id()."\n";
            # #store the image_id - stock_id link
	    # my $q = "INSERT INTO phenome.stock_image (stock_id, image_id, metadata_id) VALUES (?,?,?)";
            # my $sth  = $dbh->prepare($q);
            # $sth->execute($stock->stock_id, $image_id, $metadata_id);
	}
    };
    if ($@) {
	print STDERR "ERROR OCCURRED WHILE SAVING NEW INFORMATION. $@\n";
	$dbh->rollback();
    }
    else {
	$dbh->commit();
    }
}

sub store_image {
    my $dbh = shift;
    my $db_image_dir = shift;
    my $image_hash = shift;
    my $name2id = shift;
    my $chado_table = shift;
    my $object = shift;
    my $filename = shift;
    my $description = shift;
    my $sp_person_id = shift;

    my $new_image_count;
    
    my $image = CXGN::Image->new(dbh=>$dbh, image_dir=>$db_image_dir);   
    $image_hash->{$filename}=$image;
    
    my ($image_id, $error) = $image->process_image("$filename", $chado_table , $name2id->{lc($object)}, 1);
    
    print STDERR "IMAGE ID $image_id, ERROR: $error\n";
    
    if ($error eq "ok") { 
	$image->set_description("$description");
	$image->set_name(basename($filename , ".$ext"));
	$image->set_sp_person_id($sp_person_id);
	$image->set_obsolete("f");
	$image_id = $image->store();
	#link the image with the BCS object 
	$new_image_count++;
	my $image_subpath = $image->image_subpath();
	print STDERR "FINAL IMAGE PATH = $db_image_dir/$image_subpath\n";
    }

    return $image_id;
}

sub link_image {
    my $image_id = shift;
    my $stock_id = shift;
    my $metadata_id = shift;
    print STDERR "Connecting image with id $image_id with stock ".$stock_id."\n";
    #store the image_id - stock_id link
    my $q = "INSERT INTO phenome.stock_image (stock_id, image_id, metadata_id) VALUES (?,?,?)";
    my $sth  = $dbh->prepare($q);
    $sth->execute($stock_id, $image_id, $metadata_id);
}

#close(ERR);
close(F);




print STDERR "Inserted  $new_image_count images.\n";
print STDERR "Done. \n";

sub usage { 
    print "Usage: load_images.pl -D dbname [ cxgn | sandbox ]  -H dbhost -t [trial mode ] -i input dir -r chado table name for the object to link with the image \n";
    exit();
}

sub message {
    my $message=shift;
    print STDERR $message;
}
