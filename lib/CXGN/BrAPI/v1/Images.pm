package CXGN::BrAPI::v1::Images;

use Moose;
use Data::Dumper;
use File::Basename;
use File::Slurp qw | slurp |;
use Image::Size;
use SGN::Model::Cvterm;
use SGN::Image;
use CXGN::Image::Search;
use CXGN::Page;
use CXGN::Tag;

extends 'CXGN::BrAPI::v1::Common';

sub search {
    my $self = shift;
    my $params = shift;
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;
    my $page_obj = CXGN::Page->new();
    my $hostname = $page_obj->get_hostname();
    my @data_files;

    my $image_ids_arrayref = $params->{imageDbId} || ($params->{imageDbIds} || ());
    my $image_names_arrayref = $params->{imageName} || ($params->{imageNames} || ());
    my $stock_ids_arrayref = $params->{observationUnitDbId} || ($params->{observationUnitDbIds} || ());
    my $phenotype_ids_arrayref = $params->{observationDbId} || ($params->{observationDbIds} || ());
    my $descriptors_arrayref = $params->{descriptiveOntologyTerm} || ($params->{descriptiveOntologyTerms} || ());

    my $image_search = CXGN::Image::Search->new({
        bcs_schema=>$self->bcs_schema(),
        people_schema=>$self->people_schema(),
        phenome_schema=>$self->phenome_schema(),
        image_name_list=>$image_names_arrayref,
        description_list=>$descriptors_arrayref,
        stock_id_list=>$stock_ids_arrayref,
        image_id_list=>$image_ids_arrayref
        # still need to implement in the search
        # phenotype_id_list=>$phenotype_ids_arrayref,
    });
    my ($result, $total_count) = $image_search->search();

    my @data;
    foreach (@$result) {
        my $image = SGN::Image->new($self->bcs_schema()->storage->dbh(), $_->{'image_id'});
        my @cvterms = $image->get_cvterms();
        my $url = $hostname . $image->get_image_url('medium');
        my $filename = $image->get_filename();
        my $size = (stat($filename))[7];
        my ($width, $height) = imgsize($filename);

        push @data, {
            additionalInfo => {
                observationLevel => $_->{'stock_type_name'},
                observationUnitName => $_->{'stock_uniquename'},
                tags =>  $_->{'tags_array'},
            },
            copyright => $_->{'image_username'} . " " . substr($_->{'image_modified_date'},0,4),
            description => $_->{'image_description'},
            descriptiveOntologyTerms => \@cvterms,
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
            observationDbIds => [],
        };
    }

    my %result = (data => \@data);

    my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Image search result constructed');
}

sub detail {
    my $self = shift;
    my $inputs = shift;
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;
    my $page = CXGN::Page->new();
    my $hostname = $page->get_hostname();
    my @data_files;

    my $image = SGN::Image->new($self->bcs_schema()->storage->dbh(), $inputs->{image_id});
    my @cvterms = $image->get_cvterms();
    my $url = $hostname . $image->get_image_url('medium');
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
        %result = (
            additionalInfo => {
                observationLevel => $_->{'stock_type_name'},
                observationUnitName => $_->{'stock_uniquename'},
                tags =>  $_->{'tags_array'},
            },
            copyright => $_->{'image_username'} . " " . substr($_->{'image_modified_date'},0,4),
            description => $_->{'image_description'},
            descriptiveOntologyTerms => \@cvterms,
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
            observationDbIds => [],
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

    if (!$user_id || ($user_type ne 'submitter' && $user_type ne 'sequencer' && $user_type ne 'curator')) {
        print STDERR 'Must be logged in with submitter privileges to post images! Please contact us!';
        push @$status, {'4003' => 'Permission Denied. Must have correct privilege.'};
        return CXGN::BrAPI::JSONResponse->return_error($status, 'Must be logged in with submitter privileges to post images! Please contact us!');
    }

    my $imageName = $params->{imageName} || "";
    my $description = $params->{description} || "";
    my $imageFileName = $params->{imageFileName} || "";
    my $mimeType = $params->{mimeType} || "";
    my $observationUnitDbId = $params->{observationUnitDbId} || "";
    my $descriptiveOntologyTerms_arrayref = $params->{descriptiveOntologyTerms} || ();

    # metadata store for the rest not yet implemented
    my $imageFileSize = $params->{imageFileSize} || "";
    my $imageHeight = $params->{imageHeight} || "";
    my $imageWidth = $params->{imageWidth} || "";
    my $copyright = $params->{copyright} || "";
    my $imageTimeStamp = $params->{imageTimeStamp} || "";
    my $observationDbIds_arrayref = $params->{observationDbIds} || ();
    my $imageLocation_hashref = $params->{imageLocation} || ();
    my $additionalInfo_hashref = $params->{additionalInfo} || ();

    my $image_obj = CXGN::Image->new( dbh=>$dbh, image_dir => $image_dir, image_id => $image_id);
    unless ($image_id) { $image_obj->set_sp_person_id($user_id); }
    $image_obj->set_name(@{$imageName}[0]);
    $image_obj->set_description(@{$description}[0]);
    $image_obj->set_original_filename(@{$imageFileName}[0]);
    $image_obj->set_file_ext(@{$mimeType}[0]);

    my $tag = CXGN::Tag->new($dbh);
    foreach (@$descriptiveOntologyTerms_arrayref) {
        $tag->set_name($_);
        $tag->set_sp_person_id($user_id);
        $image_obj->add_tag($tag);
    }

    $image_id = $image_obj->store();

    if (@{$observationUnitDbId}[0]) {
        my $person = CXGN::People::Person->new($dbh, $user_id);
        my $user_name = $person->get_username;
        my $image = SGN::Image->new($self->bcs_schema()->storage->dbh(), $image_id);
        $image->associate_stock(@{$observationUnitDbId}[0], $user_name);
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
        my $tags = $_->{'tags_array'};
        my @tag_names;
        foreach (@$tags) {
            my $taghashref = $_;
            my $name = $taghashref->{'name'};
            push @tag_names, $name;
        }
        %result = (
            additionalInfo => {
                observationLevel => $_->{'stock_type_name'},
                observationUnitName => $_->{'stock_uniquename'},
            },
            copyright => $_->{'image_username'} . " " . substr($_->{'image_modified_date'},0,4),
            description => $_->{'image_description'},
            descriptiveOntologyTerms => \@tag_names,
            imageDbId => $_->{'image_id'},
            imageFileName => $_->{'image_original_filename'},
            imageFileSize => 0,
            imageHeight => 0,
            imageWidth => 0,
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
            observationDbIds => [],
        );
    }

    #print STDERR "Result is ".Dumper(%result)."\n";

    my $total_count = 1;
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success( \%result, $pagination, undef, $self->status());
}


 sub image_data_store {
    my $self = shift;
    my $image_dir = shift;
    my $image_id = shift;
    my $inputs = shift;

    print STDERR "Image ID: $image_id. inputs to image metadata store: ".Dumper($inputs);

    my $tempfile = $inputs->filename();

    print STDERR "TEMP FILE : $tempfile\n";

    # process image data through CXGN::Image...
    #
    my $image = CXGN::Image->new(dbh=>$self->bcs_schema()->storage()->dbh(), image_dir => $image_dir, image_id => $image_id);

    eval {
	       $image->process_image($tempfile);
    };

    if ($@) {
	       print STDERR "An error occurred during image processing... $@\n";
    }
    else {
	       print STDERR "Image processed successfully.\n";
    }

    my $pagination = CXGN::BrAPI::Pagination->pagination_response(1, 10, 0);
    return CXGN::BrAPI::JSONResponse->return_success( { image_id => $image_id }, $pagination, [], $self->status());
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

1;
