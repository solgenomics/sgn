
=head1 NAME

    SGN::Controller::AJAX::Image - image ajax requests

=head1 DESCRIPTION

Implements the following endpoints:

 GET /ajax/image/<image_id> 

 GET /ajax/image/<image_id>/stock/<stock_id>/display_order

 POST /ajax/image/<image_id>/stock/<stock_id>/display_order/<display_order>

 GET /ajax/image/<image_id>/locus/<locus_id>/display_order

 POST /ajax/image/<image_id>/locus/<locus_id>/display_order/<display_order>

=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>

=cut

package SGN::Controller::AJAX::Image;

use Moose;
use Archive::Zip qw( :ERROR_CODES :CONSTANTS);
use File::Temp qw(tempdir);
use File::Basename qw(basename);
use JSON;
use SGN::Model::Cvterm;
use Data::Dumper;

BEGIN { extends 'Catalyst::Controller::REST' };

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
   );


# parse /ajax/image/<image_id>
#
sub basic_ajax_image :Chained('/') PathPart('ajax/image') CaptureArgs(1) ActionClass('REST') {  }

sub basic_ajax_image_GET { 
    my $self = shift;
    my $c = shift;
    
    $c->stash->{image_id} = shift;
    $c->stash->{image} = SGN::Image->new($c->dbc->dbh(), $c->stash->{image_id});    
}

sub basic_ajax_image_POST { 
    my $self = shift;
    my $c = shift;
    $c->stash->{image_id} = shift;

    $c->stash->{image} = SGN::Image->new($c->dbc->dbh(), $c->stash->{image_id});
}

# endpoint /ajax/image/<image_id>
#    
sub image_info :Chained('basic_ajax_image') PathPart('') Args(0) ActionClass('REST') {}

sub image_info_GET { 
    my $self = shift;
    my $c = shift;

    my @display_order_info = $c->stash->{image}->get_display_order_info();
    
    
    my $response = { 
	thumbnail => $c->stash->{image}->get_image_url("thumbnail"),
	small => $c->stash->{image}->get_image_url("small"),
	medium => $c->stash->{image}->get_image_url("medium"),
	large => $c->stash->{image}->get_image_url("large"),
	sp_person_id => $c->stash->{image}->get_sp_person_id(),
        md5sum => $c->stash->{image}->get_md5sum(),	    
	display_order => \@display_order_info
    };
    
    $c->stash->{rest} = $response;
}


# parse /ajax/image/<image_id>/stock/<stock_id>
#
sub image_stock_connection :Chained('basic_ajax_image') PathPart('stock') CaptureArgs(1) ActionClass('REST') { }

sub image_stock_connection_GET { 
    my $self = shift;
    my $c = shift;
    my $stock_id = shift;

    $self->image_stock_connection_POST($c, $stock_id);
}

sub image_stock_connection_POST {  
    my $self = shift;
    my $c = shift;

    $c->stash->{stock_id} = shift;
}

# GET endpoint /ajax/image/<image_id>/stock/<stock_id>/display_order
#
sub get_image_stock_display_order : Chained('image_stock_connection') PathPart('display_order') Args(0) ActionClass('REST') { }

sub get_image_stock_display_order_GET { 
    my $self = shift;
    my $c = shift;
    
    my $do = $c->stash->{image}->get_stock_page_display_order($c->stash->{stock_id});
    $c->stash->{rest} = { stock_id => $c->stash->{stock_id},
                          image_id => $c->stash->{image_id},
			  display_order => $do,
    };
}

# POST endpoint /ajax/image/<image_id>/stock/<stock_id>/display_order/<display_order>
#
sub add_image_stock_display_order :Chained('image_stock_connection') PathPart('display_order') Args(1) ActionClass('REST') { }

sub add_image_stock_display_order_GET { 
    my $self = shift;
    my $c = shift;
    my $display_order = shift;

    $self->add_image_stock_display_order_POST($c, $display_order);
}

sub add_image_stock_display_order_POST { 
    my $self = shift;
    my $c = shift;
    my $display_order = shift;

    if (!$c->user()) { 
	$c->stash->{rest} = { error => "you need to be logged in to modify the display order of images"};
	return;
    }
    
    if (!$c->user()->check_roles("curator") && $c->stash->{image}->get_sp_person_id() != $c->user()->get_object()->get_sp_person_id()) { 
	$c->stash->{rest} = { error => "You cannot modify an image that you don't own.\n" };
	return;
    }

    my $error = $c->stash->{image}->set_stock_page_display_order($c->stash->{stock_id}, $display_order);    
    if ($error) { 
	$c->stash->{rest} = { error => $error };
    }
    else { 
	$c->stash->{rest} = { success => 1 };
    }    
}

# parse /ajax/image/<image_id>/locus/<locus_id>
#
sub image_locus_connection :Chained('basic_ajax_image') PathPart('locus') CaptureArgs(1) ActionClass('REST') { }

sub image_locus_connection_GET { 
    my $self = shift;
    my $c = shift;
    my $stock_id = shift;

    $self->image_locus_connection_POST($c, $stock_id);
}

sub image_locus_connection_POST {  
    my $self = shift;
    my $c = shift;

    $c->stash->{locus_id} = shift;

    if (!$c->user()) { 
	$c->stash->{rest} = { error => "you need to be logged in to modify the display order of images"};
	return;
    }
    
    if (!$c->user()->check_roles("curator") && $c->stash->{image}->get_sp_person_id() != $c->user()->get_object()->get_sp_person_id()) { 
	$c->stash->{rest} = { error => "You cannot modify an image that you don't own.\n" };
	return;
    }
}

# GET endpoint /ajax/image/<image_id>/locus/<locus_id>/display_order
#
sub get_image_locus_display_order :Chained('image_locus_connection') PathPart('display_order') Args(0) ActionClass('REST') { }

sub get_image_locus_display_order_GET { 
    my $self = shift;
    my $c = shift;
    
    my $do = $c->stash->{image}->get_locus_page_display_order($c->stash->{locus_id});
    $c->stash->{rest} = { locus_id => $c->stash->{locus_id},
                          image_id => $c->stash->{image_id},
			  display_order => $do,
    };
}

# POST endpoint /ajax/image/<image_id>/locus/<locus_id>/display_order/<display_order>
#
sub add_image_locus_display_order :Chained('image_locus_connection') PathPart('display_order') Args(1) ActionClass('REST') { }

sub add_image_locus_display_order_GET { 
    my $self = shift;
    my $c = shift;
    my $display_order = shift;

    $self->add_image_locus_display_order_POST($c, $display_order);
}

sub add_image_locus_display_order_POST { 
    my $self = shift;
    my $c = shift;

    my $display_order = shift;
    
    my $error = $c->stash->{image}->set_locus_page_display_order($c->stash->{image_id}, $display_order);

    if ($error) { 
	$c->stash->{rest} = { error => $error };
    }
    else { 
	$c->stash->{rest} = { success => 1 };
    }
}

sub verify_exif : Path('/ajax/image/verify_exif') : Args(0) : ActionClass('REST') { }

sub verify_exif_POST {
    my ($self, $c) = @_;
    my $user_id = $c->user()->get_object->get_sp_person_id;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', undef, $user_id);

    my $upload_param = $c->req->uploads->{"images"} || $c->req->uploads->{"images[]"};
    my @uploads = ref($upload_param) eq 'ARRAY' ? @$upload_param : ($upload_param);
    my @results;

    foreach my $upload (@uploads) {
        my $filename = $upload->filename;
        my $file_path = $upload->tempname;

        if ($filename =~ /\.zip$/i) {
            my $tempdir = tempdir(CLEANUP => 1);
            my $zip = Archive::Zip->new();

            unless ($zip->read($file_path) == AZ_OK) {
                push @results, { filename => $filename, status => "error", error => "Failed to read zip file" };
                next;
            }

            foreach my $member ($zip->members) {
                next if $member->isDirectory;
                my $member_name = $member->fileName;

                # skip non-image files
                next unless $member_name =~ /\.(jpg|jpeg|png)$/i;

                my $out_path = File::Spec->catfile($tempdir, basename($member_name));
                unless ($member->extractToFileNamed($out_path) == AZ_OK) {
                    push @results, { filename => $member_name, status => "error", error => "Failed to extract $member_name" };
                    next;
                }

                my $meta = CXGN::Image->extract_exif_info_class($out_path);
                if ($meta) {
                    push @results, { filename => basename($member_name), exif => $meta, status => "success" };
                } else {
                    push @results, { filename => basename($member_name), exif => undef, status => "no_exif" };
                }
            }
        } else {
            my $meta = CXGN::Image->extract_exif_info_class($file_path);
            if ($meta) {
                print STDERR "meta: " . Dumper($meta);
                my $decoded = decode_json($meta);
                print STDERR "decoded json: " . Dumper($decoded);
                my $id_type = $decoded->{study}->{study_unique_id_name};
                print STDERR "id type: " . $id_type;
                if ($id_type eq 'plot_name') {
                    my $plot_name = $decoded->{observation_unit}->{observation_unit_db_id};
                    print STDERR "plot_name: $plot_name\n";
                    my $type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "plot", "stock_type")->cvterm_id();
                    print STDERR "type_id: $type_id\n";
                    my $obs_unit_id = $schema->resultset("Stock::Stock")->find({ uniquename => $plot_name, type_id => $type_id})->stock_id();
                    $decoded->{observation_unit}->{observation_unit_db_id} = "$obs_unit_id";
                }

                push @results, { filename => $filename, exif => $decoded, status => "success" };
                
            } else {
                push @results, { filename => $filename, exif => undef, status => "no_eif" };
            }
        }
    }

    $c->stash->{rest} = { images => \@results };
}

 sub image_metadata_store {
    my $self = shift;
    my $params = shift;
    my $image_dir = shift;
    my $user_id = shift;
    my $user_type = shift;
    my $image_id = shift;
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;
    my $dbh = $self->bcs_schema()->storage()->dbh();

    my $imageName = $params->{imageName} ? $params->{imageName}[0] : "";
    my $description = $params->{description} ? $params->{description}[0] : "";
    my $imageFileName = $params->{imageFileName} ? $params->{imageFileName}[0] : "";
    my $mimeType = $params->{mimeType} ? $params->{mimeType}[0] : undef;
    my $observationUnitDbId = $params->{observationUnitDbId} ? $params->{observationUnitDbId}[0] : undef;
    my $descriptiveOntologyTerms_arrayref = $params->{descriptiveOntologyTerms} || ();
    my $observationDbIds_arrayref = $params->{observationDbIds} || ();

    # metadata store for the rest not yet implemented
    my $imageFileSize = $params->{imageFileSize} ? $params->{imageFileSize}[0] : undef;
    my $imageHeight = $params->{imageHeight} ? $params->{imageHeight}[0] : ();
    my $imageWidth = $params->{imageWidth} ? $params->{imageWidth}[0] : ();
    my $copyright = $params->{copyright} || "";
    my $imageTimeStamp = $params->{imageTimeStamp} || "";
    my $imageLocation_hashref = $params->{imageLocation} || ();
    my $additionalInfo_hashref = $params->{additionalInfo} || ();

     # Prechecks before storing
     # Check that our observation unit db id exists. If not return error.
     if ($observationUnitDbId) {
         my $stock = $self->bcs_schema()->resultset("Stock::Stock")->find({ stock_id => $observationUnitDbId });
         if (! defined $stock) {
             return CXGN::BrAPI::JSONResponse->return_error($self->status, 'Stock id is not valid. Cannot generate image metadata');
         }
     }


     # Check that the cvterms are valid before continuing
     my @cvterm_ids;
     foreach (@$descriptiveOntologyTerms_arrayref) {
         my $cvterm_id;
         # If is like number, search for id
         if (looks_like_number($_)) {
             # Check if the trait exists
             $cvterm_id = SGN::Model::Cvterm->find_trait_by_id($self->bcs_schema(), $_);
         }
         else {
             # else search for string
             $cvterm_id = SGN::Model::Cvterm->find_trait_by_name($self->bcs_schema(), $_);
         }

         if (!defined $cvterm_id) {
             return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('Descriptive ontology term %s not found. Cannot generate image metadata', $_));
         }

         push(@cvterm_ids, $cvterm_id);
     }

     # Check that the image type they want to pass in is supported.
     # If it is not converted, and is the same after _get_extension, it is not supported.
     my $extension_type = _get_extension($mimeType);
     if ($extension_type eq $mimeType) {
         return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('Mime type %s is not supported.', $mimeType));
     }

     # Check if an image id was passed in, and if that image exists
     my $image_obj = CXGN::Image->new( dbh=>$dbh, image_dir => $image_dir, image_id => $image_id);
     if ($image_id && ! defined $image_obj->get_create_date()) {
         return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('Image with id of %s, does not exist', $image_id));
     }

     # Check that the observationDbIds they passed exists
     foreach (@$observationDbIds_arrayref) {
         my $phenotype = $self->bcs_schema()->resultset("Phenotype::Phenotype")->find({ phenotype_id => $_ });
         if (! defined $phenotype) {
             return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('Observation with id of %s, does not exist', $_));
         }
     }


     # End of prechecks

     # Assign image properties
    unless ($image_id) { $image_obj->set_sp_person_id($user_id); }
    $image_obj->set_name($imageName);
    $image_obj->set_description($description);
    $image_obj->set_original_filename($imageFileName);
    $image_obj->set_file_ext($extension_type);

     # Save the image to the db
    $image_id = $image_obj->store();

     my $image = SGN::Image->new($self->bcs_schema()->storage->dbh(), $image_id);

     # Remove cvterms so we can reassign them later
     my @prev_cvterms = $image->get_cvterms();
     foreach (@prev_cvterms) {
        $image->remove_associated_cvterm($_->cvterm_id);
     }

     # Store desceriptiveOntologyTerms in the cvterm after finding the cvterm here.
     foreach (@cvterm_ids) {
         $image->associate_cvterm($_);
     }

     # Clear previously associated stocks.
     my @stocks = $image->get_stocks();
     foreach(@stocks){
        $image->remove_stock($_->stock_id);
     }

     # Associate our stock with the image, if a stock_id was provided.
    if ($observationUnitDbId) {
        my $person = CXGN::People::Person->new($dbh, $user_id);
        my $user_name = $person->get_username;
        $image->associate_stock($observationUnitDbId, $user_name);
    }

    # Clear previously associated phenotypes
    $image->remove_associated_phenotypes();

    # Associate the image with the observations specified
    foreach (@$observationDbIds_arrayref) {

        my $nd_experiment_phenotype = $self->bcs_schema()->resultset("NaturalDiversity::NdExperimentPhenotype")->find({ phenotype_id => $_ });

        if ($nd_experiment_phenotype) {
            my %image_hash = ($nd_experiment_phenotype->nd_experiment_id => $image_id);
            $image->associate_phenotype(\%image_hash);
        } else {
            return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('Cannot find experiment associated with observation with id of %s, does not exist', $_));
        }
    }

    my $url = "";

    my @image_ids;
    push @image_ids, $image_id;
    my $image_search = CXGN::Image::Search->new({
        bcs_schema=>$self->bcs_schema(),
        people_schema=>$self->people_schema(),
        phenome_schema=>$self->phenome_schema(),
        image_id_list=>\@image_ids
    });

    my ($search_result, $total_count) = $image_search->search();
    my %result;

    foreach (@$search_result) {

        # Get the cv terms assigned
        my $image = SGN::Image->new($self->bcs_schema()->storage->dbh(), $_->{'image_id'});
        my @cvterms = $image->get_cvterms();
        # Process cvterms
        my @cvterm_names;
        foreach (@cvterms) {
            if ($_->name) {
                push(@cvterm_names, $_->name);
            }
        }

        # Get the observation variable db ids
        my @observationDbIds;
        my $observations_array = $_->{'observations_array'};

        foreach (@$observations_array) {
            my $observationDbId = $_->{'phenotype_id'};
            push @observationDbIds, $observationDbId
        }

        # Construct the response
        %result = (
            additionalInfo => {
                observationLevel => $_->{'stock_type_name'},
                observationUnitName => $_->{'stock_uniquename'},
            },
            copyright => $_->{'image_username'} . " " . substr($_->{'image_modified_date'},0,4),
            description => $_->{'image_description'},
            descriptiveOntologyTerms => \@cvterm_names,
            imageDbId => $_->{'image_id'},
            imageFileName => $_->{'image_original_filename'},
            # Since breedbase doesn't care what file size is saved when the actual saving happens,
            # just return what the user passes in.
            imageFileSize => $imageFileSize,
            imageHeight => $imageHeight,
            imageWidth => $imageWidth,
            imageName => $_->{'image_name'},
            imageTimeStamp => $_->{'image_modified_date'},
            imageURL => $url,
            mimeType => _get_mimetype($_->{'image_file_ext'}),
            observationUnitDbId => $_->{'stock_id'},
            # location and linked phenotypes are not yet available for images in the db
            imageLocation => {
                geometry => {
                    coordinates => [],
                    type=> '',
                },
                type => '',
            },
            observationDbIds => [@observationDbIds],
        );
    }

    my $total_count = 1;
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success( \%result, $pagination, undef, $self->status());
}


 sub image_data_store {
    my $self = shift;
    my $image_dir = shift;
    my $image_id = shift;
    my $inputs = shift;
    my $content_type = shift;

    print STDERR "Image ID: $image_id. inputs to image metadata store: ".Dumper($inputs);

    # Get our image file extension type from the database
    my @image_ids;
    push @image_ids, $image_id;
    my $image_search = CXGN::Image::Search->new({
     bcs_schema=>$self->bcs_schema(),
     people_schema=>$self->people_schema(),
     phenome_schema=>$self->phenome_schema(),
     image_id_list=>\@image_ids
    });

    my ($search_result, $total_count) = $image_search->search();
    my $file_extension = @$search_result[0]->{'image_file_ext'};

    if (! defined $file_extension) {
        return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('Unsupported image type, %s', $file_extension));
    }

    my $tempfile = $inputs->filename();
    my $file_with_extension = $tempfile.$file_extension;
    rename($tempfile, $file_with_extension);

    print STDERR "TEMP FILE : $tempfile\n";

    # process image data through CXGN::Image...
    #
    my $cxgn_img = CXGN::Image->new(dbh=>$self->bcs_schema()->storage()->dbh(), image_dir => $image_dir, image_id => $image_id);

    eval {
        $cxgn_img->process_image($file_with_extension);
    };

    if ($@) {
           print STDERR "An error occurred during image processing... $@\n";
    }
    else {
           print STDERR "Image processed successfully.\n";
    }

    my %result = ( image_id => $image_id);

    foreach (@$search_result) {
        my $sgn_image = SGN::Image->new($self->bcs_schema()->storage->dbh(), $_->{'image_id'});
        my $page_obj = CXGN::Page->new();
        my $hostname = $page_obj->get_hostname();
        my $url = $hostname . $sgn_image->get_image_url('medium');
        my $filename = $sgn_image->get_filename();
        my $size = (stat($filename))[7];
        my ($width, $height) = imgsize($filename);

        # Get the observation variable db ids
        my @observationDbIds;
        my $observations_array = $_->{'observations_array'};

        foreach (@$observations_array) {
            my $observationDbId = $_->{'phenotype_id'};
            push @observationDbIds, $observationDbId
        }

     %result = (
         additionalInfo => {
             observationLevel => $_->{'stock_type_name'},
             observationUnitName => $_->{'stock_uniquename'},
         },
         copyright => $_->{'image_username'} . " " . substr($_->{'image_modified_date'},0,4),
         description => $_->{'image_description'},
         imageDbId => $_->{'image_id'},
         imageFileName => $_->{'image_original_filename'},
         imageFileSize => $size,
         imageHeight => $height,
         imageWidth => $width,
         imageName => $_->{'image_name'},
         imageTimeStamp => $_->{'image_modified_date'},
         imageURL => $url,
         mimeType => _get_mimetype($_->{'image_file_ext'}),
         observationUnitDbId => $_->{'stock_id'},
         # location and linked phenotypes are not yet available for images in the db
         imageLocation => {
             geometry => {
                 coordinates => [],
                 type=> '',
             },
             type => '',
         },
         observationDbIds => [@observationDbIds],
     );
    }

    my $pagination = CXGN::BrAPI::Pagination->pagination_response(1, 10, 0);
    return CXGN::BrAPI::JSONResponse->return_success( \%result, $pagination, [], $self->status(), 'Image data store successful');
}

sub _get_mimetype {
    my $extension = shift;
    my %mimetypes = (
        '.jpg' => 'image/jpeg',
        '.JPG' => 'image/jpeg',
        '.jpeg' => 'image/jpeg',
        '.png' => 'image/png',
        '.gif' => 'image/gif',
        '.svg' => 'image/svg+xml',
        '.pdf' => 'application/pdf',
        '.ps'  => 'application/postscript',
    );
    if ( defined $mimetypes{$extension} ) {
        return $mimetypes{$extension};
    } else {
        return $extension;
    }
}

sub _get_extension {
    my $mimetype = shift;
    my %extensions = (
        'image/jpeg'             => '.jpg',
        'image/png'              => '.png',
        'image/gif'              => '.gif',
        'image/svg+xml'          => '.svg',
        'application/pdf'        => '.pdf',
        'application/postscript' => '.ps'
    );
    if ( defined $extensions{$mimetype} ) {
        return $extensions{$mimetype};
    } else {
        return $mimetype;
    }
}
1;
