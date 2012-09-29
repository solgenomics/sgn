

package SGN::Controller::Barcode;

use Moose;
use GD;
use Barcode::Code128;
#use GD::Barcode::QRcode;
use Tie::UrlEncoder;

our %urlencode;

BEGIN { extends 'Catalyst::Controller'; }

sub index : Path('/barcode') Args(0) { 
    my $self =shift;
    my $c = shift;
    
    $c->stash->{template}='/barcode/index.mas';
}

sub barcode_image : Path('/barcode/image') Args(0) { 
    my $self = shift;
    my $c = shift;
    
    my $code = $c->req->param("code");
    my $text = $c->req->param("text");
    my $size = $c->req->param("size");
    my $top  = $c->req->param("top") || 30;
    
    my $scale = 2;
    if ($size eq "small") { $scale = 1; }
    if ($size eq "huge") { $scale = 3; }
    
    my $barcode_object = Barcode::Code128->new();
    $barcode_object->barcode($code);
    $barcode_object->font('large');
    $barcode_object->border(2);
    $barcode_object->scale($scale);
    $barcode_object->top_margin($top);
    $barcode_object->font_align("center");
    my  $barcode = $barcode_object ->gd_image();
    my $text_width = gdLargeFont->width()*length($text);
    $barcode->string(gdLargeFont,int(($barcode->width()-$text_width)/2),10,$text, $barcode->colorAllocate(0, 0, 0));
    $c->res->headers->content_type('image/png');
    
    $c->res->body($barcode->png());    
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
    
    my $operator = $c->req->param("operator");
    my $date     = $c->req->param("date");
    my $size     = $c->req->param("size");

    $c->stash->{operator} = $operator;
    $c->stash->{date}     = $date;
    $c->stash->{size}     = $size;
    

    $c->stash->{template} = '/barcode/tool/metadata.mas';
}

sub new_barcode_tool : Path('/barcode/tool/') Args(1) { 
    my $self = shift;
    my $c = shift;
    
    my $term = shift;

    $c->stash->{template} = '/barcode/tool/'.$term.'.mas';


}

1;
