package SGN::Controller::Image;

use Moose;
use namespace::autoclean;
use File::Basename;
use SGN::Image;
use CXGN::Login;


use URI::FromHash 'uri';

BEGIN { extends 'Catalyst::Controller'; }

sub view :Path('/image/view/') Args(1) {
    my ( $self, $c, $image_id ) = @_;

    my $dbh = $c->dbc->dbh;

    my $image = $c->stash->{image} =
        SGN::Image->new( $dbh, $image_id+0, $c );

    $image->get_original_filename
        or $c->throw_404('Image not found.');

    $c->forward('get_user');

    $c->stash(
        template  => '/image/index.mas',

        object_id => $image_id,
        dbh       => $dbh,
        size      => $c->req->param("size")
       );
}

sub add :Path('/image/add') Args(0) {
    my ($self, $c) = @_;

    $c->forward('require_logged_in');

    $c->stash(
        template => '/image/add_image.mas',

        refering_page => $c->req->referer() || undef,
        type          => $c->req->param('type'),
        type_id       => $c->req->param('type_id'),
       );
}

sub confirm :Path('/image/confirm') {
    my ($self, $c) = @_;

    $c->forward('require_logged_in');

    my $upload = $c->req->upload('file')
        or $c->throw( public_message => 'No image file uploaded.', is_client_error => 1 );
    my $filename = $upload->filename();
    my $tempfile = $upload->tempname();
    #print STDERR "FILENAME: $filename TEMPNAME: $tempfile\n";

    if (! -e $tempfile) {
        die "No tempfile $tempfile\n";
    }
    
    my $filename_validation_msg =  $self->validate_image_filename(basename($filename));
    if ( $filename_validation_msg )  { #if non-blank, there is a problem with Filename, print messages

        unlink $tempfile;  # remove upload! prevents more errors on item we have rejected

        $c->throw( public_message => <<EOM, is_client_error => 1 );
There is a problem with the image file you selected: $filename <br />
Error: $filename_validation_msg <br />
EOM

    }
    my $image_url = $c->tempfiles_subdir('image')."/".basename($tempfile);
    my $confirm_filename = $c->get_conf('basepath')."/".$image_url;
    if (! -e $tempfile) { die "Temp file does not exit $tempfile\n"; }
    if (!$upload->copy_to( $confirm_filename  )) {
        die "Error copying $tempfile to $confirm_filename\n";
    }

    $c->stash(
        type => $c->req->param('type'),
        refering_page => $c->req->param('refering_page'),
        type_id => $c->req->param('type_id'),
        filename => $filename,
        tempfile => basename($tempfile),
        image_url => $image_url,
    );
}


sub store :Path('/image/store') {
    my $self = shift;
    my $c = shift;

    $c->forward('require_logged_in');

    my $image = SGN::Image->new( $c->dbc->dbh(), undef, $c );

    my $tempfile      = $c->req()->param('tempfile');
    my $filename      = $c->req()->param('filename');
    my $type          = $c->req()->param('type');
    my $type_id       = $c->req()->param('type_id');
    my $refering_page = $c->req()->param('refering_page');


    my $temp_image_dir = $c->get_conf("basepath")."/".$c->tempfiles_subdir('image');

    $image->set_sp_person_id( $c->stash->{person_id} );

    if ((my $err = $image->process_image($temp_image_dir."/".$tempfile, $type, $type_id, 1))<=0) {
        die "An error occurred during the upload. Is the file you are uploading an image file? [$err] ";

    }

    # set some image attributes...
    # the image owner...
    #print STDERR "Setting the submitter information in the image object...\n";

    $image->set_name($filename);

    $image->store();

   # send_image_email($c, "store", $image, $sp_person_id, $refering_page, $type, $type_id);
    #remove the temp_file
    #
    unlink $temp_image_dir."/".$tempfile;

    my $image_id = $image->get_image_id();

    # go to the image detail page
    # open for editing.....
    $c->res->redirect( $c->uri_for('view',$image_id )->relative() );
}

sub image_display_order :Path('/image/display_order') Args(0) { 
    my $self  = shift;
    my $c = shift;

    $c->stash->{image_id} = $c->req->param("image_id");
    $c->stash->{type} = $c->req->param("type");
    $c->stash->{id} = $c->req->param("id");
    $c->stash->{display_order} = $c->req->param("display_order");
    
    print STDERR "image_id = ".$c->stash->{image_id}."\n";
    
    $c->stash->{template} = '/image/display_order.mas';
}

sub validate_image_filename :Private {
    my $self = shift;
    my $fn = shift;
    my %file_types = ( '.jpg'  => 'JPEG file',
                       '.jpeg' => 'JPEG file',
                       '.gif'  => 'GIF file',
                       '.pdf'  => 'PDF file',
                       '.ps'   => 'PS file',
                       '.eps'  => 'EPS file',
                       '.png'  => 'PNG file');

    # first test is non-acceptable characters in filename
    my $OK_CHARS='-a-zA-Z0-9_.@\ '; # as recommend by CERT, test for what you will allow
    my $test_fn = $fn;
    $test_fn =~ s/[^$OK_CHARS]/_/go;
    if ( $fn ne $test_fn ) {
        #print STDERR "Upload Attempt with bad shell characters: $fn \n";
        return "Invalid characters found in filename, must not contain
        characters <b>\& ; : \` \' \\ \| \* \? ~ ^ < > ( ) [ ] { } \$</b>" ;
    }

    my $ext;
    if ($fn =~ m/^(.*)(\.\S{1,4})\r*$/) {
        $ext = lc ($2);
        #print STDERR "Upload Attempt with disallowed filename extension: $fn Extension: $ext\n";
        return "File Type must be one of: .png, .jpg, .jpeg, .gif, .pdf, .ps, or .eps" unless exists $file_types{$ext};
    } else {
        #print STDERR "Upload Attempt with filename extension we could not parse: $fn \n";
        return "File Type must be one of: .png, .jpg, .jpeg, .gif, .pdf, .ps, or .eps";
    }

    return 0;  # FALSE, if passes all tests
}

sub send_image_email :Private {
    my $self = shift;
    my $c = shift;
    my $action = shift;
    my $image = shift;
    my $sp_person_id = shift;
    my $refering_page=shift;
    my $type= shift;  #locus or...?
    my $type_id = shift; #the database id of the refering object (locus..)

    my $image_id = $image->get_image_id();

    my $person= CXGN::People::Person->new($c->dbc->dbh, $sp_person_id);
    my $user=$person->get_first_name()." ".$person->get_last_name();

    my $type_link;


    my $user_link = qq | http://sgn.cornell.edu/solpeople/personal-info.pl?sp_person_id=$sp_person_id|;
    my $usermail=$person->get_contact_email();
    my $image_link = qq |http://sgn.cornell.edu/image/?image_id=$image_id|;
    if ($type eq 'locus') {
        $type_link = qq | http://sgn.cornell.edu/phenome/locus_display.pl?locus_id=$type_id|;
    }
#    elsif ($type eq 'allele') {
#       $type_link = qq | http://sgn.cornell.edu/phenome/allele.pl?allele_id=$type_id|;
#     }
#     elsif ($type eq 'population') {
#       $type_link = qq | http://sgn.cornell.edu/phenome/population.pl?population_id=$type_id|;
#     }

    my $fdbk_body;
    my $subject;

    if ($action eq 'store') {

        $subject="[New image associated with $type: $type_id]";
        $fdbk_body="$user ($user_link) has associated image $image_link \n with $type: $type_link";
   }
    elsif($action eq 'delete') {


        $subject="[A image-$type association removed from $type: $type_id]";
        $fdbk_body="$user ($user_link) has removed publication $image_link \n from $type: $type_link";
    }

    CXGN::Contact::send_email($subject,$fdbk_body, 'sgn-db-curation@sgn.cornell.edu');

}

sub get_user : Private{
    my ( $self, $c ) = @_;

    my $dbh = $c->dbc->dbh;

    my $person_id               =
      $c->stash->{person_id}    =
      $c->stash->{sp_person_id} =
            CXGN::Login->new( $c->dbc->dbh )->has_session();

    if( $person_id ) {
        $c->stash->{person} = CXGN::People::Person->new( $dbh, $person_id );
    }
}


sub require_logged_in : Private {
    my ( $self, $c ) = @_;

    $c->forward('get_user');

    unless( $c->stash->{person_id} ) {
        $c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
    }

    return 1;
}


1;
