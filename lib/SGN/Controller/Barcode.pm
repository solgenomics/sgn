
package SGN::Controller::Barcode;

use Moose;
use GD;

use DateTime;
use File::Slurp;
use Barcode::Code128;
use GD::Barcode::QRcode;
use Tie::UrlEncoder;
use PDF::LabelPage;
use Math::Base36 ':all';
use CXGN::QRcode;
use Data::Dumper;

our %urlencode;

BEGIN { extends 'Catalyst::Controller'; }

sub index : Path('/barcode') Args(0) {
    my $self =shift;
    my $c = shift;

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    # get projects
    my @rows = $schema->resultset('Project::Project')->all();
    my @projects = ();
    foreach my $row (@rows) {
	push @projects, [ $row->project_id, $row->name, $row->description ];
    }
    $c->stash->{projects} = \@projects;
    @rows = $schema->resultset('NaturalDiversity::NdGeolocation')->all();
    my @locations = ();
    foreach my $row (@rows) {
	push @locations,  [ $row->nd_geolocation_id,$row->description ];
    }

    $c->stash->{locations} = \@locations;
    $c->stash->{template} = '/barcode/index.mas';
}


=head2 barcode_image

 URL:          mapped to URL /barcode/image
 Params:       code : the code to represent in the barcode
               text : human readable text
               size : either small, large
               top  : pixels from the top
 Desc:         creates the barcode image, sets the content type to
               image/png and returns the barcode image to the browser
 Ret:
 Side Effects:
 Example:

=cut

sub barcode_image : Path('/barcode/image') Args(0) {
    my $self = shift;
    my $c = shift;

    my $code = $c->req->param("code");
    my $text = $c->req->param("text");
    my $size = $c->req->param("size");
    my $top  = $c->req->param("top");

    my $barcode = $self->barcode($code, $text, $size, $top);

    $c->res->headers->content_type('image/png');

    $c->res->body($barcode->png());
}


sub barcode_tempfile_jpg : Path('/barcode/tempfile') Args(4) {
    my $self = shift;
    my $c = shift;

    my $code = shift;
    my $text = shift;
    my $size = shift;
    my $top = shift;

    my $barcode = $self->barcode($code,
				 $text,
				 $size,
				 $top,
	);

    $c->tempfiles_subdir('barcode');
    my ($file, $uri) = $c->tempfile( TEMPLATE => [ 'barcode', 'bc-XXXXX'], SUFFIX=>'.jpg');

    open(my $F, ">", $file) || die "Can't open file $file $@";
    print $F $barcode->jpeg();
    close($F);

    return $file;
}

sub barcode_qrcode_jpg : Path('/barcode/tempfile') Args(2){
   my $self = shift;
   my $c = shift;
   my $stock_id = shift;
   my $stock_name = shift;
   my $field_info = shift;
   my $fieldbook_enabled = shift // "";
   my $stock_type = shift;
   print "STOCK TYPE!!!: $stock_type\n";
   my $text;
   if ($fieldbook_enabled eq "enable_fieldbook_2d_barcode"){
       $text = $stock_name;
   }
   elsif ($stock_type eq 'crossing') {
       #$text = $stock_id;
       $text = "stock name: ".$stock_name. "\n plot_id: ".$stock_id. "\n".$field_info;
   }
   else {
       $text = "stock name: ".$stock_name. "\n stock id: ". $stock_id. "\n".$field_info;
   }



   $c->tempfiles_subdir('barcode');
   my ($file_location, $uri) = $c->tempfile( TEMPLATE => [ 'barcode', 'bc-XXXXX'], SUFFIX=>'.jpg');

   my $barcode_generator = CXGN::QRcode->new( text => $text );
   my $barcode_file = $barcode_generator->get_barcode_file($file_location);

   close($barcode_file);
   return $barcode_file;
 }

 sub phenotyping_qrcode_jpg : Path('/barcode/tempfile') Args(2){
    my $self = shift;
    my $c = shift;
    my $stock_id = shift;
    my $stock_name = shift;
    my $field_info = shift;
    my $base_url = $c->config->{main_production_site_url};
    my $text = "$base_url/breeders/plot_phenotyping?stock_id=$stock_id";
    if ($field_info eq "trial"){
       $text =  "TrialID:".$stock_id."\n TrialName:".$stock_name;
    }

    $c->tempfiles_subdir('barcode');
    my ($file_location, $uri) = $c->tempfile( TEMPLATE => [ 'barcode', 'bc-XXXXX'], SUFFIX=>'.jpg');

    my $barcode_generator = CXGN::QRcode->new( text => $text );
    my $barcode_file = $barcode_generator->get_barcode_file($file_location);

    return $barcode_file;
  }

  sub trial_qrcode_jpg : Path('/barcode/trial') Args(2){
     my $self = shift;
     my $c = shift;
     my $trial_id = shift;
     my $format = shift;
     my $base_url = $c->config->{main_production_site_url};
     my $text = "$base_url/breeders/trial_phenotyping?trial_id=$trial_id";
     if ($format eq "stock_qrcode"){
        $text =  $trial_id;
     }

      $c->tempfiles_subdir('barcode');
      my ($file_location, $uri) = $c->tempfile( TEMPLATE => [ 'barcode', 'bc-XXXXX'], SUFFIX=>'.jpg');

      my $barcode_generator = CXGN::QRcode->new( text => $text );
      my $barcode_file = $barcode_generator->get_barcode_file($file_location);

       $c->res->headers->content_type('image/jpg');
       $c->res->body($barcode_file);
   }

=head2 barcode

 Usage:        $self->barcode($code, $text, $size, 30);
 Desc:         generates a barcode (GD image)
 Ret:          a GD::Image object
 Args:         $code, $text, $size, upper margin
 Side Effects: none
 Example:

=cut

sub barcode {
    my $self = shift;
    my $code = shift;
    my $text = shift;
    my $size = shift;
    my $top = shift;

    my $scale = 2;
    if ($size eq "small") { $scale = 1; }
    if ($size eq "huge") { $scale = 5; }
    my $barcode_object = Barcode::Code128->new();
    $barcode_object->barcode($code);
    $barcode_object->font('large');
    $barcode_object->border(2);
    $barcode_object->scale($scale);
    $barcode_object->top_margin($top);
    #$barcode_object->show_text($show_text);
    $barcode_object->font_align("center");
    my  $barcode = $barcode_object ->gd_image();
    my $text_width = gdLargeFont->width()*length($text);
    $barcode->string(gdLargeFont,int(($barcode->width()-$text_width)/2),10,$text, $barcode->colorAllocate(0, 0, 0));
    return $barcode;
}

#deprecated
sub code128_png :Path('/barcode/code128png') :Args(2) {
    my $self = shift;
    my $c = shift;
    my $identifier = shift;
    my $text = shift;

    $text =~ s/\+/ /g;
    $identifier =~ s/\+/ /g;

    my $barcode_object = Barcode::Code128->new();
    $barcode_object->barcode($identifier);
    $barcode_object->font('large');
    $barcode_object->border(2);
    $barcode_object->top_margin(30);
    $barcode_object->font_align("center");
    my  $barcode = $barcode_object ->gd_image();
    my $text_width = gdLargeFont->width()*length($text);
    $barcode->string(gdLargeFont,int(($barcode->width()-$text_width)/2),10,$text, $barcode->colorAllocate(0, 0, 0));
    $c->res->headers->content_type('image/png');

    $c->res->body($barcode->png());
}

# a barcode element for a continuous barcode

sub barcode_element : Path('/barcode/element/') :Args(2) {
    my $self = shift;
    my $c = shift;
    my $text = shift;
    my $height = shift;

    my $size = $c->req->param("size");

    my $scale = 1;
    if ($size eq "large") {
	$scale = 2;
    }

    my $barcode_object = Barcode::Code128->new();
    $barcode_object->barcode($text);
    $barcode_object->height(100);
    $barcode_object->scale($scale);
    #$barcode_object->width(200);
    $barcode_object->font('large');
    $barcode_object->border(0);
    $barcode_object->top_margin(0);
    my  $barcode = $barcode_object ->gd_image();

    my $barcode_slice = GD::Image->new($barcode->width, $height);
    my $white = $barcode_slice->colorAllocate(255,255,255);
    $barcode_slice->filledRectangle(0, 0, $barcode->width, $height, $white);

    print STDERR "Creating barcode with width ".($barcode->width)." and height $height\n";
    $barcode_slice->copy($barcode, 0, 0, 0, 0, $barcode->width, $height);

    $c->res->headers->content_type('image/png');

    $c->res->body($barcode_slice->png());
}

sub qrcode_png :Path('/barcode/qrcodepng') :Args(2) {
    my $self = shift;
    my $c = shift;
    my $link = shift;
    my $text = shift;

    $text =~ s/\+/ /g;
    $link =~ s/\+/ /g;

    my $bc = GD::Barcode::QRcode->new($link, { Ecc => 'L', Version=>2, ModuleSize => 2 });
    my $image = $bc->plot();

    $c->res->headers->content_type('image/png');
    $c->res->body($image->png());
}

sub barcode_tool :Path('/barcode/tool') Args(3) {
    my $self = shift;
    my $c = shift;
    my $cvterm = shift;
    my $tool_version = shift;
    my $values = shift;

    my ($db, $accession) = split ":", $cvterm;

    print STDERR "Searching $cvterm, DB $db...\n";
    my ($db_row) = $c->dbic_schema('Bio::Chado::Schema')->resultset('General::Db')->search( { name => $db } );

    print STDERR $db_row->db_id;
    print STDERR "DB_ID for $db: $\n";


    my $dbxref_rs = $c->dbic_schema('Bio::Chado::Schema')->resultset('General::Dbxref')->search_rs( { accession=>$accession, db_id=>$db_row->db_id } );

    my $cvterm_rs = $c->dbic_schema('Bio::Chado::Schema')->resultset('Cv::Cvterm')->search( { dbxref_id => $dbxref_rs->first->dbxref_id });

    my $cvterm_id = $cvterm_rs->first()->cvterm_id();
    my $cvterm_synonym_rs = ""; #$c->dbic_schema('Bio::Chado::Schema')->resultset('Cv::Cvtermsynonym')->search->( { cvterm_id=>$cvterm_id });

    $c->stash->{cvterm} = $cvterm;
    $c->stash->{cvterm_name} = $cvterm_rs->first()->name();
    $c->stash->{cvterm_definition} = $cvterm_rs->first()->definition();
    $c->stash->{cvterm_values} = $values;
    $c->stash->{tool_version} = $tool_version;
    $c->stash->{template} = '/barcode/tool/tool.mas';
#    $c->stash->{cvterm_synonym} = $cvterm_synonym_rs->synonym();
    $c->forward('View::Mason');
}


sub barcode_multitool :Path('/barcode/multitool') Args(0) {

    my $self  =shift;
    my $c = shift;

    $c->stash->{operator} = $c->req->param('operator');
    $c->stash->{date}     = $c->req->param('date');
    $c->stash->{project}  = $c->req->param('project');
    $c->stash->{location} = $c->req->param('location');

    my @cvterms = $c->req->param('cvterms');

    my $cvterm_data = [];

    foreach my $cvterm (@cvterms) {

	my ($db, $accession) = split ":", $cvterm;

	print STDERR "Searching $cvterm, DB $db...\n";
	my ($db_row) = $c->dbic_schema('Bio::Chado::Schema')->resultset('General::Db')->search( { name => $db } );

	print STDERR $db_row->db_id;
	print STDERR "DB_ID for $db: $\n";


	my $dbxref_rs = $c->dbic_schema('Bio::Chado::Schema')->resultset('General::Dbxref')->search_rs( { accession=>$accession, db_id=>$db_row->db_id } );

	my $cvterm_rs = $c->dbic_schema('Bio::Chado::Schema')->resultset('Cv::Cvterm')->search( { dbxref_id => $dbxref_rs->first->dbxref_id });

	my $cvterm_id = $cvterm_rs->first()->cvterm_id();
	my $cvterm_synonym_rs = ""; #$c->dbic_schema('Bio::Chado::Schema')->resultset('Cv::Cvtermsynonym')->search->( { cvterm_id=>$cvterm_id });

	push @$cvterm_data, { cvterm => $cvterm,
			      cvterm_name => $cvterm_rs->first()->name(),
			      cvterm_definition => $cvterm_rs->first->definition,
	};

    }

    $c->stash->{cvterms} = $cvterm_data;

    $c->stash->{template} = '/barcode/tool/multi_tool.mas';


}

sub continuous_scale : Path('/barcode/continuous_scale') Args(0) {
    my $self = shift;
    my $c = shift;
    my $start = $c->req->param("start");
    my $end = $c->req->param("end");
    my $step = $c->req->param("step");
    my $height = $c->req->param("height");

    my @barcodes = ();

    # barcodes all have to have the same with - use with of end value
    my $text_width = length($end);

    for(my $i = $start; $i <= $end; $i += $step) {
	my $text = $urlencode{sprintf "%".$text_width."d", $i};
	print STDERR "TEXT: $text\n";
	push @barcodes, qq { <img src="/barcode/element/$i/$height" align="right" /> };

    }

    $c->res->body("<table cellpadding=\"0\" cellspacing=\"0\">". (join "\n", (map { "<tr><td>$_</td></tr>"}  @barcodes)). "</table>");


}

sub continuous_scale_form : Path('/barcode/continuous_scale/input') :Args(0) {
    my $self = shift;
    my $c = shift;

    my $form = <<HTML;
<h1>Create continuous barcode</h1>

<form action="/barcode/continuous_scale">
Start value <input name="start" /><br />
End value <input name="end" /><br />
Step size <input name="step" /><br />
Increment (pixels) <input name="height" />

<input type="submit"  />
</form>

HTML

$c->res->body($form);

}

sub generate_barcode : Path('/barcode/generate') Args(0) {
    my $self = shift;
    my $c = shift;

    my $text = $c->req->param("text");
    my $size = $c->req->param("size");

    $c->stash->{code} = $text;
    $c->stash->{size} = $size;

    $c->stash->{template} = "/barcode/tool/generate.mas";

}

sub metadata_barcodes : Path('/barcode/metadata') Args(0) {
    my $self = shift;
    my $c = shift;



    $c->stash->{operator} = $c->req->param("operator");
    $c->stash->{date}     = $c->req->param("date");
    $c->stash->{size}     = $c->req->param("size");
    $c->stash->{project}  = $c->req->param("project");
    $c->stash->{location} = $c->req->param("location");

    $c->stash->{template} = '/barcode/tool/metadata.mas';
}

sub new_barcode_tool : Path('/barcode/tool/') Args(1) {
    my $self = shift;
    my $c = shift;

    my $term = shift;

    $c->stash->{template} = '/barcode/tool/'.$term.'.mas';
}

sub cross_tool : Path('/barcode/tool/cross') {
    my $self = shift;
    my $c = shift;

    $c->stash->{template} = '/barcode/tool/cross.mas';
}

sub dna_tool   : Path('/barcode/tool/dna/') {
    my $self =shift;
    my $c = shift;
    $c->stash->{template} = '/barcode/tool/dna.mas';
}

sub generate_unique_barcode_labels : Path('/barcode/unique') Args(0) {
    my $self = shift;
    my $c = shift;

    if (! $c->user()) {
	$c->stash->{template} = 'generic_message.mas';
	$c->stash->{message} = 'You must be logged in to use the unique barcode tool.';
	return;
    }

    my $label_pages = $c->req->param("label_pages");
    my $label_rows = $c->req->param("label_rows") || 10;
    my $label_cols  = $c->req->param("label_cols") || 1;
    my $page_format = $c->req->param("page_format") || "letter";
    my $top_margin_mm = $c->req->param("top_margin");
    my $left_margin_mm = $c->req->param("left_margin");
    my $bottom_margin_mm = $c->req->param("bottom_margin");
    my $right_margin_mm = $c->req->param("right_margin");

    # convert mm into pixels
    #
    my ($top_margin, $left_margin, $bottom_margin, $right_margin) = map { int($_ * 2.846) } ($top_margin_mm,
											$left_margin_mm,
											$bottom_margin_mm,
											$right_margin_mm);
    my $total_labels = $label_pages * $label_cols * $label_rows;


    my $dir = $c->tempfiles_subdir('pdfs');
    my ($FH, $filename) = $c->tempfile(TEMPLATE=>"pdfs/pdf-XXXXX", SUFFIX=>".pdf", UNLINK=>0);
    print STDERR "FILENAME: $filename \n\n\n";
    my $pdf = PDF::Create->new(filename=>$c->path_to($filename),
			       Author=>$c->config->{project_name},
			       Title=>'Labels',
			       CreationDate => [ localtime ],
			       Version=>1.2,
	);

    if (!$page_format) { $page_format = "Letter"; }

    print STDERR "PAGE FORMAT IS: $page_format. LABEL ROWS: $label_rows, COLS: $label_cols. TOTAL LABELS: $total_labels\n";

    my @pages = ();
    push @pages, PDF::LabelPage->new( { top_margin=>$top_margin, bottom_margin=>$bottom_margin, left_margin=>$left_margin, right_margin=>$right_margin, pdf=>$pdf, cols => $label_cols, rows => $label_rows });

    foreach my $label_count (1..$total_labels) {
	my $label_code = $self->generate_label_code($c);

	print STDERR "LABEL CODE: $label_code\n";

	# generate barcode
	#
	my $tempfile = $c->forward('/barcode/barcode_tempfile_jpg', [ $label_code, $label_code ,  'large',  20  ]);
	my $image = $pdf->image($tempfile);
	print STDERR "IMAGE: ".Data::Dumper::Dumper($image);

	# note: pdf coord system zero is lower left corner
	#

	if ($pages[-1]->need_more_labels()) {
	    print STDERR "ADDING LABEL...\n";
	    $pages[-1]->add_label($image);
	}

	else {
	    print STDERR "CREATING NEW PAGE...\n";

	    push @pages, PDF::LabelPage->new({ top_margin=>$top_margin, bottom_margin=>$bottom_margin, left_margin=>$left_margin, right_margin=>$right_margin, pdf=>$pdf, cols => $label_cols, rows => $label_rows });

	    $pages[-1]->add_label($image);
	}

    }

    foreach my $p (@pages) {
	$p->render();
    }

    $pdf->close();

    #$c->stash->{not_found} = \@not_found;
    #$c->stash->{found} = \@found;
    $c->stash->{file} = $filename;
    $c->stash->{filetype} = 'PDF';
    $c->stash->{template} = '/barcode/unique_barcode_download.mas';
}



sub generate_label_code {
    my $self = shift;
    my $c = shift;

    my $dbh = $c->dbc->dbh();

    my $h = $dbh->prepare("SELECT nextval('phenome.unique_barcode_label_id_seq')");
    $h->execute();
    my ($next_val) = $h->fetchrow_array();

    print STDERR "nextval is $next_val\n";

    my $encoded = Math::Base36::encode_base36($next_val, 7);

    return $encoded;

}


sub read_barcode : Path('/barcode/read') Args(0) {
    my $self = shift;
    my $c = shift;

    $c->stash->{template} = '/barcode/read.mas';
}


1;
