package SGN::Image;

=head1 NAME

SGN::Image - SGN Images

=head1 DESCRIPTION

This class provides database access and store functions as well as
image upload and certain image manipulation functions, such as image
file type conversion and image resizing; and functions to associate
tags with the image. Note that this was forked off from the insitu
image object. The insitu database needs to be re-factored to use this
image object.

The philosophy of the image object has changed slightly from the
Insitu::Image object. It now stores the images in a directory
specified by the conf object parameter "static_datasets_dir" plus
the conf parameter "image_dir" plus the directory name "image_files"
for the production server and the directory "image_files_sandbox" for
the test server. In those directories, it creates a subdirectory for
each image, with the subdirectory name being the corresponding image
id. In that directory are then several files, the originial image file
with the orignial name, the converted image into jpg in the standard
image sizes: large, medium, small and thumbnail with the names:
large.jpg, medium.jpg, small.jpg and thumbnail.jpg . All other
metadata about the image is stored in the database.

=head1 AUTHOR(S)

Lukas Mueller (lam87@cornell.edu)
Naama Menda (nm249@cornell.edu)


=head1 MEMBER FUNCTIONS

The following functions are provided in this class:

=cut

use Modern::Perl;

use IO::File;
use File::Path 'make_path';
use File::Temp qw/ tempfile tempdir /;
use File::Copy qw/ copy move /;
use File::Basename qw/ basename /;
use File::Spec;
use CXGN::DB::Connection;
use CXGN::Tag;
use CXGN::Metadata::Metadbdata;
use SGN::Model::Cvterm;
use Data::Dumper;

use CatalystX::GlobalContext '$c';

use base qw| CXGN::Image |;

=head2 new

 Usage:        my $image = SGN::Image->new($dbh)
 Desc:         constructor
 Ret:
 Args:         a database handle, optional identifier
 Side Effects: an empty object is returned.
               a database connection is established.
 Example:

=cut

sub new {
    my ( $class, $dbh, $image_id, $context ) = @_;
    $context ||= $c;

    my $self = $class->SUPER::new(
        dbh       => $dbh || $context->dbc->dbh,
        image_id  => $image_id,
        image_dir => $context->get_conf('static_datasets_path')."/".$context->get_conf('image_dir'),
      );

    $self->config( $context );

    return $self;
}



=head2 get_image_url

 Usage: $self->get_image_url($size)
 Desc:  get the url for the image with a given size
 Ret:   a url for the image
 Args:  size (large, medium, small, thumbnail,  original)
 Side Effects: none
 Example:

=cut

sub get_image_url {
    my $self = shift;
    my $size = shift;

    if( $self->config->test_mode && ! -e $self->get_filename($size) ) {
        # for performance, only try to stat the file if running in
        # test mode. doing lots of file stats over NFS can actually be
        # quite expensive.
        return '/img/image_temporarily_unavailable.png';
    }

    my $url = join '/', (
         '',
         $self->config()->get_conf('static_datasets_url'),
         $self->config()->get_conf('image_dir'),
         $self->get_filename($size, 'partial'),
     );
    $url =~ s!//!/!g;
    return $url;
}

=head2 process_image

 Usage:        $image->process_image($filename, "stock", 234);
 Desc:         creates the image and associates it to the type and type_id
 Ret:
 Args:         filename, type (experiment, stock, fish, locus, organism) , type_id
 Side Effects: Calls the relevant $image->associate_$type function
 Example:

=cut

sub process_image {
    my $self = shift;
    my ($filename, $type, $type_id, $linking_table_type_id) = @_;

    $self->SUPER::process_image($filename);

    if ( $type eq "experiment" ) {
        #print STDERR "Associating experiment $type_id...\n";
        $self->associate_experiment($type_id);
    }
    elsif ( $type eq "stock" ) {
        #print STDERR "Associating stock $type_id...\n";
        $self->associate_stock($type_id);
    }
    elsif ( $type eq "fish" ) {
        #print STDERR "Associating to fish experiment $type_id\n";
        $self->associate_fish_result($type_id);
    }
    elsif ( $type eq "locus" ) {
        #print STDERR "Associating to locus $type_id\n";
        $self->associate_locus($type_id);
    }
    elsif ( $type eq "organism" ) {
        $self->associate_organism($type_id);
    } 
    elsif ( $type eq "cvterm" ) {
	$self->associate_cvterm($type_id);
    }
    elsif ( $type eq "project" ) {
        $self->associate_project($type_id, $linking_table_type_id);
    }

    elsif ( $type eq "test") { 
	# need to return something to make this function happy
	return 1;
	
    }
    else {
        warn "type $type is not recognized as one of the legal types. Not associating image with any object. Please check if your loading script links the image with an sgn object! \n";
    }

}

=head2 config, context, _app

Get the Catalyst context object we are running with.

=cut

sub config {
    my ($self,$obj) = @_;

    $self->{configuration_object} = $obj if $obj;

    return $self->{configuration_object};
}
*context = \&config;
*_app    = \&config;

=head2 get_img_src_tag

 Usage:
 Desc:
 Ret:
 Args:         "large" | "medium" | "small" | "thumbnail" | "original" | "tiny"
               default is medium
 Side Effects:
 Example:

=cut

sub get_img_src_tag {
    my $self = shift;
    my $size = shift;
    my $url  = $self->get_image_url($size);
    my $name = $self->get_name() || '';
    if ( $size && $size eq "original" ) {

        my $static = $self->config()->get_conf("static_datasets_url");

        return
            "<a href=\""
          . ($url)
          . "\"><span class=\"glyphicon glyphicon-floppy-save\" alt=\""
          . $name
          . "\" ></a>";
    }
    elsif ( $size && $size eq "tiny" ) {
        return
            "<img src=\""
          . ($url)
          . "\" width=\"20\" height=\"15\" border=\"0\" alt=\""
          . $name
          . "\" />\n";
    }
    else {
        return
            "<img src=\""
          . ($url)
          . "\" border=\"0\" alt=\""
          . $name
          . "\" />\n";
    }
}

=head2 get_temp_filename

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_temp_filename {
    my $self = shift;
    return $self->{temp_filename};

}

=head2 set_temp_filename

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub set_temp_filename {
    my $self = shift;
    $self->{temp_filename} = shift;
}

=head2 apache_upload_image

 DEPRECATED.

 Usage:        my $temp_file_name = $image->apache_upload_image($apache_upload_object);
 Desc:
 Ret:          the name of the intermediate tempfile that can be
               used to access down the road.
 Args:         an apache upload object
 Side Effects: generates an intermediate temp file from an apache request
               that can be handled more easily. Adds the remote IP addr to the
               filename so that different uploaders don\'t clobber but
               allows only one upload per remote addr at a time.
 Errors:       change 11/30/07 - removes temp file if already exists
               # returns -1 if the intermediate temp file already exists.
               # this probably means that the submission button was hit twice
               # and that an upload is already in progress.
 Example:

=cut

sub apache_upload_image {
    my $self   = shift;
    my $upload = shift;
    ###  deanx jan 03 2007
# Adjust File name if using Windows IE - it sends whole paht; drive letter, path, and filename
    my $upload_filename;
    if ( $ENV{HTTP_USER_AGENT} =~ /msie/i ) {
        my ( $directory, $filename ) = $upload->filename =~ m/(.*\\)(.*)$/;
        $upload_filename = $filename;
    }
    else {
        $upload_filename = $upload->filename;
    }

    my $upload_fh = $upload->fh;

    my $temp_file =
        $self->config()->get_conf("basepath") . "/"
      . $self->config()->get_conf("tempfiles_subdir")
      . "/temp_images/"
      . $ENV{REMOTE_ADDR} . "-"
      . $upload_filename;

    my $ret_temp_file = $self->upload_image($temp_file, $upload_fh);
    return $ret_temp_file;

}

sub upload_fieldbook_zipfile {
    my $self = shift;
    my $image_zip = shift;
    my $user_id = shift;
    my $c = $self->config();
    my $error_status;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $dbh = $schema->storage->dbh;
    my $archived_zip = CXGN::ZipFile->new(archived_zipfile_path=>$image_zip);
    my $file_members = $archived_zip->file_members();
    if (!$file_members){
        $error_status = 'Could not read your zipfile. Is is .zip format?</br></br>';
        return $error_status;
    }
    my $plot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id();
    my $plant_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant', 'stock_type')->cvterm_id();

    foreach (@$file_members) {
        my $image = SGN::Image->new( $dbh, undef, $c );
        #print STDERR Dumper $_;
        my $img_name = substr($_->fileName(), 0, -24);
        $img_name =~ s/^.*photos\///;
        my $stock = $schema->resultset("Stock::Stock")->find( { uniquename => $img_name, 'me.type_id' => [$plot_cvterm_id, $plant_cvterm_id] } );
        my $stock_id = $stock->stock_id;

        my $temp_file = $image->upload_zipfile_images($_);

        #Check if image already stored in database
        my $md5checksum = $image->calculate_md5sum($temp_file);
        #print STDERR "MD5: $md5checksum\n";
        my $md_image = $metadata_schema->resultset("MdImage")->search({md5sum=>$md5checksum})->count();
        #print STDERR "Count: $md_image\n";
        if ($md_image > 0) {
            print STDERR Dumper "Image $temp_file has already been added to the database and will not be added again.";
            $error_status .= "Image $temp_file has already been added to the database and will not be added again.<br/><br/>";
        } else {
            $image->set_sp_person_id($user_id);
            my $ret = $image->process_image($temp_file, 'stock', $stock_id);
            if (!$ret ) {
                $error_status .= "Image processing for $temp_file did not work. Image not associated to stock_id $stock_id.<br/><br/>";
            }
        }
    }
    return $error_status;
}

sub upload_phenotypes_associated_images_zipfile {
    my $self = shift;
    my $image_zip = shift;
    my $user_id = shift;
    my $image_observation_unit_hash = shift;
    my $image_type_name = shift;
    print STDERR "Doing upload_phenotypes_associated_images_zipfile\n";
    my $c = $self->config();
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $dbh = $schema->storage->dbh;
    my $archived_zip = CXGN::ZipFile->new(archived_zipfile_path=>$image_zip);
    my $file_members = $archived_zip->file_members();
    if (!$file_members){
        return {error => 'Could not read your zipfile. Is is .zip format?</br></br>'};
    }

    my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, $image_type_name, 'project_md_image')->cvterm_id();

    my $image_tag_id = CXGN::Tag::exists_tag_named($schema->storage->dbh, $image_type_name);
    if (!$image_tag_id) {
        my $image_tag = CXGN::Tag->new($schema->storage->dbh);
        $image_tag->set_name($image_type_name);
        $image_tag->set_description('Upload phenotype spreadsheet with associated images: '.$image_type_name);
        $image_tag->set_sp_person_id($user_id);
        $image_tag_id = $image_tag->store();
    }
    my $image_tag = CXGN::Tag->new($schema->storage->dbh, $image_tag_id);

    my %observationunit_stock_id_image_id;
    foreach (@$file_members) {
        my $image = SGN::Image->new( $dbh, undef, $c );
        my $img_name = basename($_->fileName());
        my $basename;
        my $file_ext;
        if ($img_name =~ m/(.*)(\.(?!\.).*)$/) {  # extension is what follows last .
            $basename = $1;
            $file_ext = $2;
        }
        my $stock_id = $image_observation_unit_hash->{$img_name}->{stock_id};
        my $project_id = $image_observation_unit_hash->{$img_name}->{project_id};
        if ($stock_id && $project_id) {
            my $temp_file = $image->upload_zipfile_images($_);

            #Check if image already stored in database
            $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
            my $q = "SELECT md_image.image_id FROM metadata.md_image AS md_image
                JOIN phenome.project_md_image AS project_md_image ON(project_md_image.image_id = md_image.image_id)
                JOIN phenome.stock_image AS stock_image ON (stock_image.image_id = md_image.image_id)
                WHERE md_image.obsolete = 'f' AND project_md_image.type_id = $linking_table_type_id AND project_md_image.project_id = $project_id AND stock_image.stock_id = $stock_id AND md_image.original_filename = '$basename';";
            my $h = $schema->storage->dbh->prepare($q);
            $h->execute();
            my ($saved_image_id) = $h->fetchrow_array();
            my $image_id;
            if ($saved_image_id) {
                print STDERR Dumper "Image $temp_file has already been added to the database and will not be added again.";
                $image = SGN::Image->new( $schema->storage->dbh, $saved_image_id, $c );
                $image_id = $image->get_image_id();
            }
            else {
                $image->set_sp_person_id($user_id);
                my $ret = $image->process_image($temp_file, 'project', $project_id, $linking_table_type_id);
                if (!$ret ) {
                    return {error => "Image processing for $temp_file did not work. Image not associated to stock_id $stock_id.<br/><br/>"};
                }
                print STDERR "Saved $temp_file\n";
                my $stock_associate = $image->associate_stock($stock_id);
                $image_id = $image->get_image_id();
                my $added_image_tag_id = $image->add_tag($image_tag);
            }
            $observationunit_stock_id_image_id{$stock_id} = $image_id;
        }
        else {
            print STDERR "$img_name Not Included in the uploaded phenotype spreadsheet, skipping..\n";
        }
    }
    return {return => \%observationunit_stock_id_image_id};
}

sub upload_drone_imagery_zipfile {
    my $self = shift;
    my $image_zip = shift;
    my $user_id = shift;
    my $project_id = shift;
    my $c = $self->config();
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $dbh = $schema->storage->dbh;

    my $archived_zip = CXGN::ZipFile->new(archived_zipfile_path=>$image_zip);
    my $file_members = $archived_zip->file_members();
    if (!$file_members){
        return {error => 'Could not read your zipfile. Is it .zip format?</br></br>'};
    }

    my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'raw_drone_imagery', 'project_md_image')->cvterm_id();
    print STDERR Dumper scalar(@$file_members);
    my @image_files;
    foreach (@$file_members) {
        my $image = SGN::Image->new( $dbh, undef, $c );
        #print STDERR Dumper $_;
        my $temp_file = $image->upload_zipfile_images($_);
        push @image_files, $temp_file;
    }
    return {image_files => \@image_files};
}

sub upload_zipfile_images {
    my $self   = shift;
    my $file_member = shift;

    my $filename = $file_member->fileName();

    my $zipfile_image_temp_path = $self->config()->get_conf("basepath") . $self->config()->get_conf("tempfiles_subdir") . "/temp_images/photos";
    make_path($zipfile_image_temp_path);
    my $temp_file =
        $self->config()->get_conf("basepath")
      . $self->config()->get_conf("tempfiles_subdir")
      . "/temp_images/"
      . $filename;
    system("chmod 775 $zipfile_image_temp_path");
    $file_member->extractToFileNamed($temp_file);
    return $temp_file;
}


sub upload_image {
    my $self = shift;
    my $temp_file = shift;
    my $upload_fh = shift;
    my $fh;

    ### 11/30/07 - change this so it removes existing file
    #     -deanx
    # # only copy file if it doesn't already exist
    # #
    if ( -e $temp_file ) {
        unlink $temp_file;
    }

    open $fh, '>', $temp_file or die "Could not write to $temp_file: $!\n";

    binmode $fh;
    while (<$upload_fh>) {

        #warn "Read another chunk...\n";
        print UPLOADFILE;
    }
    close $fh;
    warn "Done uploading.\n";

    return $temp_file;
}

=head2 associate_stock

 Usage: $image->associate_stock($stock_id);
 Desc:  associate a Bio::Chado::Schema::Result::Stock::Stock object with this image
 Ret:   a database id (stock_image_id)
 Args:  stock_id
 Side Effects:
 Example:

=cut

sub associate_stock  {
    my $self = shift;
    my $stock_id = shift;
    my $username = shift;
    if ($stock_id) {
        if (!$username) {
            $username = $self->config->can('user_exists') ? $self->config->user->get_object->get_username : $self->config->username;
        }
        if ($username) {
            my $metadata_schema = $self->config->dbic_schema('CXGN::Metadata::Schema');
            my $metadata = CXGN::Metadata::Metadbdata->new($metadata_schema, $username);
            my $metadata_id = $metadata->store()->get_metadata_id();

            my $q = "INSERT INTO phenome.stock_image (stock_id, image_id, metadata_id) VALUES (?,?,?) RETURNING stock_image_id";
            my $sth = $self->get_dbh->prepare($q);
            $sth->execute($stock_id, $self->get_image_id, $metadata_id);
            my ($stock_image_id) = $sth->fetchrow_array;
            return $stock_image_id;
        }
        else {
            die "No username. Could not save image-stock association!\n";
        }
    }
    return;
}

=head2 remove_stock

 Usage: $image->remove_stock($stock_id);
 Desc:  remove an association to Bio::Chado::Schema::Result::Stock::Stock object with this image
 Ret:   a database id (stock_image_id)
 Args:  stock_id
 Side Effects:
 Example:

=cut

sub remove_stock  {
    my $self = shift;
    my $stock_id = shift;
    if ($stock_id) {
        my $q = "DELETE FROM phenome.stock_image WHERE stock_id = ? AND image_id = ?";
        my $sth = $self->get_dbh->prepare($q);
        $sth->execute($stock_id, $self->get_image_id);
    }
    return;
}

=head2 get_stocks

 Usage: $image->get_stocks
 Desc:  find all stock objects linked with this image
 Ret:   a list of Bio::Chado::Schema::Result::Stock::Stock
 Args:  none

=cut

sub get_stocks {
    my $self = shift;
    my $schema = $self->config->dbic_schema('Bio::Chado::Schema' , 'sgn_chado');
    my @stocks;
    my $q = "SELECT stock_id FROM phenome.stock_image WHERE image_id = ? ";
    my $sth = $self->get_dbh->prepare($q);
    $sth->execute($self->get_image_id);
    while (my ($stock_id) = $sth->fetchrow_array) {
        my $stock = $schema->resultset("Stock::Stock")->find( { stock_id => $stock_id } ) ;
        push @stocks, $stock;
    }
    return @stocks;
}

=head2 get_trials

Usage: $image->get_trials
 Desc:  find all trial objects linked with this image
 Ret:   a list of Bio::Chado::Schema::Result::Project::Project
 Args:  none

=cut

sub get_trials {
    my $self = shift;
    my $schema = $self->config->dbic_schema('Bio::Chado::Schema' , 'sgn_chado');
    my @trials;
    my $q = "SELECT DISTINCT project.project_id FROM phenome.stock_image JOIN stock ON phenome.stock_image.stock_id = stock.stock_id JOIN nd_experiment_stock ON stock.stock_id = nd_experiment_stock.stock_id JOIN nd_experiment ON nd_experiment_stock.nd_experiment_id = nd_experiment.nd_experiment_id JOIN nd_experiment_project ON nd_experiment.nd_experiment_id = nd_experiment_project.nd_experiment_id JOIN project ON nd_experiment_project.project_id = project.project_id WHERE stock_image.image_id = ?";
    my $sth = $self->get_dbh->prepare($q);
    $sth->execute($self->get_image_id);
    while (my ($trial_id) = $sth->fetchrow_array) {
        my $trial = $schema->resultset("Project::Project")->find( { project_id => $trial_id } );
        push @trials, $trial;
    }
    return @trials;

}

=head2 associate_individual

 Usage:        DEPRECATED, Individual table is not used any more . Please use stock instead
               $image->associate_individual($individual_id)
 Desc:         associate a CXGN::Phenome::Individual with this image
 Ret:          a database id (individual_image)
 Args:         individual_id
 Side Effects:
 Example:

=cut

sub associate_individual {
    my $self = shift;
    my $individual_id = shift;
    warn "DEPRECATED. Individual table is not used any more . Please use stock instead";
    my $query = "INSERT INTO phenome.individual_image
                   (individual_id, image_id) VALUES (?, ?)";
    my $sth = $self->get_dbh()->prepare($query);
    $sth->execute($individual_id, $self->get_image_id());

    my $id= $self->get_currval("phenome.individual_image_individual_image_id_seq");
    return $id;
}


=head2 get_individuals

 Usage:  DEPRECATED. Use the stock table .
        $self->get_individuals()
 Desc:  find associated individuals with the image
 Ret:   list of 'Individual' objects
 Args:  none
 Side Effects: none
 Example:

=cut

sub get_individuals {
    my $self = shift;
    warn "DEPRECATED. Individual table is not used any more . Please use stock instead";
    my $query = "SELECT individual_id FROM phenome.individual_image WHERE individual_image.image_id=?";
    my $sth = $self->get_dbh()->prepare($query);
    $sth->execute($self->get_image_id());
    my @individuals;
    while (my ($individual_id) = $sth->fetchrow_array()) {
        my $i = CXGN::Phenome::Individual->new($self->get_dbh(), $individual_id);
        if ( $i->get_individual_id() ) { push @individuals, $i; } #obsolete individuals should be ignored!
    }
    return @individuals;
}


=head2 associate_experiment

 Usage: $image->associate_experiment($experiment_id);
 Desc:  associate and image with and insitu experiment
 Ret:   a database id
 Args:  experiment_id
 Side Effects:
 Example:

=cut

sub associate_experiment {
    my $self = shift;
    my $experiment_id = shift;
    my $query = "INSERT INTO insitu.experiment_image
                 (image_id, experiment_id)
                 VALUES (?, ?)";
    my $sth = $self->get_dbh()->prepare($query);
    $sth->execute($self->get_image_id(), $experiment_id);
    my $id= $self->get_currval("insitu.experiment_image_experiment_image_id_seq");
    return $id;

}

=head2 get_experiments

 Usage:
 Desc:
 Ret:          a list of CXGN::Insitu::Experiment objects associated
               with this image
 Args:
 Side Effects:
 Example:

=cut

sub get_experiments {
    my $self = shift;
    my $query = "SELECT experiment_id FROM insitu.experiment_image
                 WHERE image_id=?";
    my $sth = $self->get_dbh()->prepare($query);
    $sth->execute($self->get_image_id());
    my @experiments = ();
    while (my ($experiment_id) = $sth->fetchrow_array()) {
        push @experiments, CXGN::Insitu::Experiment->new($self->get_dbh(), $experiment_id);
    }
    return @experiments;
}

=head2 associate_project

 Usage: $image->associate_project($project_id);
 Desc:  associate an image with an project entry via the phenome.project_md_image table
 Ret:   a database id
 Args:  experiment_id
 Side Effects:
 Example:

=cut

sub associate_project {
    my $self = shift;
    my $project_id = shift;
    my $linking_table_type_id = shift;
    my $query = "INSERT INTO phenome.project_md_image
                 (image_id, project_id, type_id)
                 VALUES (?, ?, ?)";
    my $sth = $self->get_dbh()->prepare($query);
    $sth->execute($self->get_image_id(), $project_id, $linking_table_type_id);
    my $id= $self->get_currval("phenome.project_md_image_project_md_image_id_seq");
    return $id;
}

=head2 associate_fish_result

 Usage:        $image->associate_fish_result($fish_result_id)
 Desc:         associate a CXGN::Phenome::Individual with this image
 Ret:          database_id
 Args:         fish_result_id
 Side Effects:
 Example:

=cut

sub associate_fish_result {
    my $self = shift;
    my $fish_result_id = shift;
    my $query = "INSERT INTO sgn.fish_result_image
                   (fish_result_id, image_id) VALUES (?, ?)";
    my $sth = $self->get_dbh()->prepare($query);
    $sth->execute($fish_result_id, $self->get_image_id());
    my $id= $self->get_currval("sgn.fish_result_image_fish_result_image_id_seq");
    return $id;
}

=head2 get_fish_result_clone_ids

 Usage:        my @clone_ids = $image->get_fish_result_clones();
 Desc:         because fish results are associated with genomic
               clones, this function returns the genomic clone ids
               that are associated through the fish results to
               this image. The clone ids can be used to construct
               links to the BAC detail page.
 Ret:          A list of clone_ids
 Args:
 Side Effects:
 Example:

=cut

sub get_fish_result_clone_ids {
    my $self = shift;
    my $query = "SELECT distinct(clone_id) FROM sgn.fish_result_image join sgn.fish_result using(fish_result_id)  WHERE fish_result_image.image_id=?";
    my $sth = $self->get_dbh()->prepare($query);
    $sth->execute($self->get_image_id());
    my @fish_result_clone_ids = ();
    while (my ($fish_result_clone_id) = $sth->fetchrow_array()) {
        push @fish_result_clone_ids, $fish_result_clone_id;
    }
    return @fish_result_clone_ids;
}

=head2 get_associated_objects

  Synopsis:
  Arguments:
  Returns:
  Side effects:
  Description:

=cut

sub get_associated_objects {
    my $self = shift;
    my @associations = ();
    my @stocks=$self->get_stocks();
    foreach my $stock (@stocks) {
        my $stock_id = $stock->stock_id();
        my $stock_name = $stock->name();
        push @associations, [ "stock", $stock_id, $stock_name ];
    }

    foreach my $exp ($self->get_experiments()) {
        my $experiment_id = $exp->get_experiment_id();
        my $experiment_name = $exp->get_name();

        push @associations, [ "experiment", $experiment_id, $experiment_name ];

        #print "<a href=\"/insitu/detail/experiment.pl?experiment_id=$experiment_id&amp;action=view\">".($exp->get_name())."</a>";
    }

    my @trials = $self->get_trials();
    foreach my $trial (@trials) {
        my $trial_id = $trial->project_id();
        my $trial_name = $trial->name();
        push @associations, ["trial", $trial_id, $trial_name ];
    }

    foreach my $fish_result_clone_id ($self->get_fish_result_clone_ids()) {
        push @associations, [ "fished_clone", $fish_result_clone_id ];
    }
    foreach my $locus ($self->get_loci() ) {
        push @associations, ["locus", $locus->get_locus_id(), $locus->get_locus_name];
    }
    foreach my $o ($self->get_organisms ) {
        push @associations, ["organism", $o->organism_id, $o->species];
    }

    foreach my $cvterm ( $self->get_cvterms ) {
	push @associations, ["cvterm" , $cvterm->cvterm_id, $cvterm->name];
    }
    return @associations;
}

=head2 associate_locus

 Usage:        $image->associate_locus($locus_id)
 Desc:         associate a locus with this image
 Ret:          database_id
 Args:         locus_id
 Side Effects:
 Example:

=cut

sub associate_locus {
    my $self = shift;
    my $locus_id = shift;
    my $sp_person_id= $self->get_sp_person_id();
    my $query = "INSERT INTO phenome.locus_image
                   (locus_id,
                   sp_person_id,
                   image_id)
                 VALUES (?, ?, ?)";
    my $sth = $self->get_dbh()->prepare($query);
    $sth->execute(
                $locus_id,
                $sp_person_id,
                $self->get_image_id()
                );

    my $locus_image_id= $self->get_currval("phenome.locus_image_locus_image_id_seq");
    return $locus_image_id;
}


=head2 get_loci

 Usage:   $self->get_loci
 Desc:    find the locus objects asociated with this image
 Ret:     a list of locus objects
 Args:    none
 Side Effects: none
 Example:

=cut

sub get_loci {
    my $self = shift;
    my $query = "SELECT locus_id FROM phenome.locus_image WHERE locus_image.obsolete = 'f' and locus_image.image_id=?";
    my $sth = $self->get_dbh()->prepare($query);
    $sth->execute($self->get_image_id());
    my $locus;
    my @loci = ();
    while (my ($locus_id) = $sth->fetchrow_array()) {
       $locus = CXGN::Phenome::Locus->new($self->get_dbh(), $locus_id);
        push @loci, $locus;
    }
    return @loci;
}


=head2 associate_organism

 Usage:        $image->associate_organism($organism_id)
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub associate_organism {
    my $self = shift;
    my $organism_id = shift;
    my $sp_person_id= $self->get_sp_person_id();
    my $query = "INSERT INTO metadata.md_image_organism
                   (image_id,
                   sp_person_id,
                   organism_id)
                 VALUES (?, ?, ?) RETURNING md_image_organism_id";
    my $sth = $self->get_dbh()->prepare($query);
    $sth->execute(
        $self->get_image_id,
        $sp_person_id,
        $organism_id,
        );
    my ($image_organism_id) = $sth->fetchrow_array;
    return $image_organism_id;
}

=head2 get_organisms

 Usage:   $self->get_organisms
 Desc:    find the organism objects asociated with this image
 Ret:     a list of BCS Organism objects
 Args:    none
 Side Effects: none
 Example:

=cut

sub get_organisms {
    my $self = shift;
    my $schema = $self->config->dbic_schema('Bio::Chado::Schema' , 'sgn_chado');
    my $query = "SELECT organism_id FROM metadata.md_image_organism WHERE md_image_organism.obsolete != 't' and md_image_organism.image_id=?";
    my $sth = $self->get_dbh()->prepare($query);
    $sth->execute($self->get_image_id());
    my @organisms = ();
    while (my ($o_id) = $sth->fetchrow_array ) {
        push @organisms, $schema->resultset("Organism::Organism")->find(
            { organism_id => $o_id } );
    }
    return @organisms;
}


=head2 get_associated_object_links

  Synopsis:
  Arguments:
  Returns:      a string
  Side effects:
  Description:  gets the associated objects as links in tabular format

=cut

sub get_associated_object_links {
    my $self = shift;
    my $s = "";
    foreach my $assoc ($self->get_associated_objects()) {

        if ($assoc->[0] eq "stock") {
            $s .= "<a href=\"/stock/$assoc->[1]/view\">Stock name: $assoc->[2].</a>";
            $s .= " | ";
        }

        if ($assoc->[0] eq "trial") {
            $s .= "<a href=\"/breeders/trial/$assoc->[1]/\">Trial name: $assoc->[2].</a>";
            $s .= " | ";
        }

        if ($assoc->[0] eq "experiment") {
            $s .= "<a href=\"/insitu/detail/experiment.pl?experiment_id=$assoc->[1]&amp;action=view\">insitu experiment $assoc->[2]</a>";
        }

        if ($assoc->[0] eq "fished_clone") {
            $s .= qq { <a href="/maps/physical/clone_info.pl?id=$assoc->[1]">FISHed clone id:$assoc->[1]</a> };
        }
        if ($assoc->[0] eq "locus" ) {
            $s .= qq { <a href="/phenome/locus_display.pl?locus_id=$assoc->[1]">Locus name:$assoc->[2]</a> };
        }
        if ($assoc->[0] eq "organism" ) {
            $s .= qq { <a href="/organism/$assoc->[1]/view/">Organism name:$assoc->[2]</a> };
        }
	if ($assoc->[0] eq "cvterm" ) {
	    $s .= qq { <a href="/cvterm/$assoc->[1]/view/">Cvterm: $assoc->[2]</a> };
	}
    }
    return $s;
}


=head2 associate_cvterm

 Usage: $image->associate_cvterm($cvterm_id)
 Desc:  link uploaded image with a cvterm        
 Ret:   database ID md_image_cvterm_id
 Args:  $cvterm_id
 Side Effects: Insert database row
 Example:

=cut

sub associate_cvterm {
    my $self = shift;
    my $cvterm_id = shift;
    my $sp_person_id= $self->get_sp_person_id();
    my $query = "INSERT INTO metadata.md_image_cvterm
                   (image_id,
                   sp_person_id,
                   cvterm_id)
                 VALUES (?, ?, ?) RETURNING md_image_cvterm_id";
    my $sth = $self->get_dbh()->prepare($query);
    $sth->execute(
        $self->get_image_id,
        $sp_person_id,
        $cvterm_id,
        );
    my ($image_cvterm_id) = $sth->fetchrow_array;
    return $image_cvterm_id;
}

=head2 get_cvterms

 Usage:   $self->get_cvterms
 Desc:    find the cvterm objects asociated with this image
 Ret:     a list of BCS Cvterm objects
 Args:    none
 Side Effects: none
 Example:

=cut

sub get_cvterms {
    my $self = shift;
    my $schema = $self->config->dbic_schema('Bio::Chado::Schema' , 'sgn_chado');
    my $query = "SELECT cvterm_id FROM metadata.md_image_cvterm WHERE md_image_cvterm.obsolete != 't' and md_image_cvterm.image_id=?";
    my $sth = $self->get_dbh()->prepare($query);
    $sth->execute( $self->get_image_id() );
    my @cvterms = ();
    while (my ($cvterm_id) = $sth->fetchrow_array ) {
        push @cvterms, $schema->resultset("Cv::Cvterm")->find(
            { cvterm_id => $cvterm_id } );
    }
    return @cvterms;
}

=head2 remove_associated_cvterm

 Usage:   $self->remove_associated_cvterm($cvterm_id)
 Desc:    removes the specified cvterm associated with this image
 Ret:     none
 Args:    none
 Side Effects: none
 Example:

=cut

sub remove_associated_cvterm {

    my $self = shift;
    my $cvterm_id = shift;
    my $query = "DELETE FROM metadata.md_image_cvterm
                    WHERE cvterm_id=? and image_id=?";

    my $sth = $self->get_dbh()->prepare($query);
    $sth->execute(
        $cvterm_id,
        $self->get_image_id,
    );

    return;
}

sub associate_phenotype {

    my $self = shift;
    my $image_hash = shift;

    # Copied from CXGN::Phenotypes:StorePhenotypes->save_archived_images_metadata because
    # the class required too many parameters to instantiate.
    my $query = "INSERT into phenome.nd_experiment_md_images (nd_experiment_id, image_id) VALUES (?, ?);";
    my $sth = $self->get_dbh()->prepare($query);

    while (my ($nd_experiment_id, $image_id) = each %$image_hash) {
        $sth->execute($nd_experiment_id, $image_id);
    }

    return;
}

sub remove_associated_phenotypes {

    my $self = shift;

    # Find the information for creating our association row
    my $query = "DELETE from phenome.nd_experiment_md_images where image_id = ?";

    my $sth = $self->get_dbh()->prepare($query);
    $sth->execute(
        $self->get_image_id,
    );

}

1;
