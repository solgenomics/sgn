package CXGN::BrAPI::v1::Images;

use Moose;
use Data::Dumper;
use File::Basename;
use File::Slurp qw | slurp |;
use Image::Size;
use SGN::Model::Cvterm;
use SGN::Image;
use CXGN::Image::Search;
#use CXGN::Page;
use CXGN::Tag;
use CXGN::Phenotypes::StorePhenotypes;
use Scalar::Util qw(looks_like_number);

extends 'CXGN::BrAPI::v1::Common';

sub search {
    my $self = shift;
    my $params = shift;
    my $main_production_site_url = shift;
    
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;
#    my $page_obj = CXGN::Page->new();
    #    my $hostname = $page_obj->get_hostname();
    
    my @data_files;

    my $image_ids_arrayref = $params->{imageDbId} || ($params->{imageDbIds} || ());
    my $image_names_arrayref = $params->{imageName} || ($params->{imageNames} || ());
    my $stock_ids_arrayref = $params->{observationUnitDbId} || ($params->{observationUnitDbIds} || ());
    my $phenotype_ids_arrayref = $params->{observationDbId} || ($params->{observationDbIds} || ());
    my $descriptors_arrayref = $params->{descriptiveOntologyTerm} || ($params->{descriptiveOntologyTerms} || ());

    my $start_index = $page*$page_size;
    my $end_index = $page*$page_size + $page_size;

    my $limit = $end_index-$start_index;
    my $offset = $start_index;

    my $image_search = CXGN::Image::Search->new({
        bcs_schema=>$self->bcs_schema(),
        people_schema=>$self->people_schema(),
        phenome_schema=>$self->phenome_schema(),
        image_name_list=>$image_names_arrayref,
        description_list=>$descriptors_arrayref,
        stock_id_list=>$stock_ids_arrayref,
        image_id_list=>$image_ids_arrayref,
        # still need to implement in the search
        # phenotype_id_list=>$phenotype_ids_arrayref,
        limit=>$limit,
        offset=>$offset
    });
    my ($result, $total_count) = $image_search->search();

    my @data;
    foreach (@$result) {
        my $image = SGN::Image->new($self->bcs_schema()->storage->dbh(), $_->{'image_id'});
        my @cvterms = $image->get_cvterms();
        my $url = $main_production_site_url. $image->get_image_url('medium');
        my $filename = $image->get_filename();
        my $size = (stat($filename))[7];
        my ($width, $height) = imgsize($filename);

        # Process cvterms
        my @cvterm_names;
        foreach (@cvterms) {
            push(@cvterm_names, $_->name);
        }

        # Get the observation variable db ids
        my @observationDbIds;
        my $observations_array = $_->{'observations_array'};

        foreach (@$observations_array) {
            my $observationDbId = $_->{'phenotype_id'};
            push @observationDbIds, $observationDbId
        }

        my %unique_tags;
        foreach (@{$_->{'tags_array'}}) {
            $unique_tags{$_->{tag_id}} = $_;
        }
        my @sorted_tags;
        foreach my $tag_id (sort keys %unique_tags) {
            push @sorted_tags, $unique_tags{$tag_id};
        }

        push @data, {
            additionalInfo => {
                observationLevel => $_->{'stock_type_name'},
                observationUnitName => $_->{'stock_uniquename'},
                tags => \@sorted_tags,
            },
            copyright => $_->{'image_username'} . " " . substr($_->{'image_modified_date'},0,4),
            description => $_->{'image_description'},
            descriptiveOntologyTerms => \@cvterm_names,
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
        };
    }

    my %result = (data => \@data);

    my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Image search result constructed');
}

sub detail {
    my $self = shift;
    my $inputs = shift;
    my $main_production_site_url = shift;
    
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;
#    my $page = CXGN::Page->new();
    #my $hostname = $page->get_hostname();
    my @data_files;

    my $image = SGN::Image->new($self->bcs_schema()->storage->dbh(), $inputs->{image_id});
    my @cvterms = $image->get_cvterms();
    my $url = $main_production_site_url . $image->get_image_url('medium');
    my $filename = $image->get_filename();
    my $size = (stat($filename))[7];
    my ($width, $height) = imgsize($filename);

    my @image_ids;
    push @image_ids, $inputs->{image_id};
    my $image_search = CXGN::Image::Search->new({
        bcs_schema=>$self->bcs_schema(),
        people_schema=>$self->people_schema(),
        phenome_schema=>$self->phenome_schema(),
        image_id_list=>\@image_ids
    });

    my ($search_result, $total_count) = $image_search->search();
    my %result;

    foreach (@$search_result) {

        # Process cvterms
        my @cvterm_names;
        foreach (@cvterms) {
            push(@cvterm_names, $_->name);
        }

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
                tags =>  $_->{'tags_array'},
            },
            copyright => $_->{'image_username'} . " " . substr($_->{'image_modified_date'},0,4),
            description => $_->{'image_description'},
            descriptiveOntologyTerms => \@cvterm_names,
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

    my $total_count = 1;
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Image detail constructed');
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
    my $main_production_site_url = shift;

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
        #my $page_obj = CXGN::Page->new();
        #my $hostname = $page_obj->get_hostname();
        my $url = $main_production_site_url . $sgn_image->get_image_url('medium');
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
    my $extension = shift || '';
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
