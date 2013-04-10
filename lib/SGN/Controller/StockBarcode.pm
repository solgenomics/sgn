
package SGN::Controller::StockBarcode;

use Moose;
use File::Slurp;
use PDF::Create;
use Bio::Chado::Schema::Result::Stock::Stock;
use CXGN::Stock::StockBarcode;
use Data::Dumper;

BEGIN { extends "Catalyst::Controller"; }

use CXGN::ZPL;


sub download_zpl_barcodes : Path('/barcode/stock/download/zpl') :Args(0) {
    my $self = shift;
    my $c = shift;

    my $stock_names = $c->req->param("stock_names");
    my $stock_names_file = $c->req->upload("stock_names_file");

    my $complete_list = $stock_names ."\n".$stock_names_file;

    $complete_list =~ s/\r//g; 
    
    my @names = split /\n/, $complete_list;

    my @not_found;
    my @found;
    my @labels;

    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    
    foreach my $name (@names) { 

	# skip empty lines
	#
	if (!$name) { 
	    next; 
	}

	my $stock = $schema->resultset("Stock::Stock")->find( { name=>$name });

	if (!$stock) { 
	    push @not_found, $name;
	    next;
	}

	my $stock_id = $stock->stock_id();

	push @found, $name;

	# generate new zdl label
	#
	my $label = CXGN::ZPL->new();
	$label->start_format();
	$label->barcode_code128($c->config->{identifier_prefix}.$stock_id);
	$label->end_format();
	push @labels, $label;

    }

    my $dir = $c->tempfiles_subdir('zpl');
    my ($FH, $filename) = $c->tempfile(TEMPLATE=>"zpl/zpl-XXXXX", UNLINK=>0);

    foreach my $label (@labels) { 
        print $FH $label->render();
    }
    close($FH);

    $c->stash->{not_found} = \@not_found;
    $c->stash->{found} = \@found;
    $c->stash->{file} = $filename;
    $c->stash->{filetype} = "ZPL";
    $c->stash->{template} = '/barcode/stock_download_result.mas';

}

sub download_pdf_labels :Path('/barcode/stock/download/pdf') :Args(0) { 
    my ($self, $c) = @_;
    
    my $stock_names = $c->req->param("stock_names");
    my $stock_names_file = $c->req->upload("stock_names_file");
    my $labels_per_page = $c->req->param("label_rows") || 10;
    my $labels_per_row  = $c->req->param("label_cols") || 1;
    my $page_format = $c->req->param("page_format") || "letter";
    my $top_margin_mm = $c->req->param("top_margin");
    my $left_margin_mm = $c->req->param("left_margin");
    my $bottom_margin_mm = $c->req->param("bottom_margin");
    my $right_margin_mm = $c->req->param("right_margin");

    # convert mm into pixels
    #
    my ($top_margin, $left_margin, $bottom_margin, $right_margin) = map { $_ * 2.846 } ($top_margin_mm, 
											$left_margin_mm, 
											$bottom_margin_mm, 
											$right_margin_mm);   

    # read file if upload
    #
    if ($stock_names_file) { 
	my $stock_file_contents = read_file($stock_names_file->{tempname});
	$stock_names = $stock_names ."\n".$stock_file_contents;
    }

    $stock_names =~ s/\r//g; 
    my @names = split /\n/, $stock_names;

    my @not_found;
    my @found;

    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    
    foreach my $name (@names) { 

	# skip empty lines
	#
	if (!$name) { 
	    next; 
	}

	my $stock = $schema->resultset("Stock::Stock")->find( { name=>$name });

	if (!$stock) { 
	    push @not_found, $name;
	    next;
	}

	my $stock_id = $stock->stock_id();

	push @found, [ $c->config->{identifier_prefix}.$stock_id, $name ];
	print "STOCK FOUND: $stock_id, $name.\n";
	
    }

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
    if (!$labels_per_page) { $labels_per_page = 8; }

    print STDERR "PAGE FORMAT IS: $page_format. LABELS PER PAGE: $labels_per_page\n";

    my $base_page = $pdf->new_page(Mediabox=>$pdf->get_page_size($page_format));
    
    my ($page_width, $page_height) = @{$pdf->get_page_size($page_format)}[2,3];

    my $label_height = int( ($page_height - $top_margin - $bottom_margin) / $labels_per_page);

    my @pages;
    foreach my $page (1..$self->label_to_page($labels_per_page, scalar(@found))) { 
	print STDERR "Generating page $page...\n";
	push @pages, $base_page->new_page();
    }
    
    for (my $i=0; $i<@found; $i++) { 
	my $label_count = $i + 1;

	my $page_nr = $self->label_to_page($labels_per_page, $label_count);

	my $label_on_page = ($label_count -1) % $labels_per_page;
	
	# generate barcode
	#
	my $tempfile = $c->forward('/barcode/barcode_tempfile_jpg', [ $found[$i]->[0],  $found[$i]->[1],  'large',  20  ]);
	my $image = $pdf->image($tempfile);
	print STDERR "IMAGE: ".Data::Dumper::Dumper($image);

	# note: pdf coord system zero is lower left corner
	#
	my $final_barcode_width = ($page_width - $right_margin - $left_margin) / $labels_per_row;

	my $scalex = $final_barcode_width / $image->{width};
	my $scaley = $label_height / $image->{height};

	if ($scalex < $scaley) { $scaley = $scalex; }
	else { $scalex = $scaley; }

	my $label_boundary = $page_height - ($label_on_page * $label_height) - $top_margin;

	my $ypos = $label_boundary - int( ($label_height - $image->{height} * $scaley) /2);

	$pages[$page_nr-1]->line($page_width -100, $label_boundary, $page_width, $label_boundary);

	foreach my $label_count (1..$labels_per_row) { 
	    $pages[$page_nr-1]->image(image=>$image, xpos=>$left_margin + ($label_count -1) * $final_barcode_width, ypos=>$ypos, xalign=>0, yalign=>2, xscale=>$scalex, yscale=>$scaley);

	}

#	$pages[$page_nr-1]->image(image=>$image, xpos=>$page_width - $final_barcode_width - 5, ypos=>$ypos , xalign=>0, yalign=>2, xscale=>$scalex, yscale=>$scaley);

    }

    $pdf->close();

    $c->stash->{not_found} = \@not_found;
    $c->stash->{found} = \@found;
    $c->stash->{file} = $filename;
    $c->stash->{filetype} = 'PDF';
    $c->stash->{template} = '/barcode/stock_download_result.mas';
}

# maps the label number to a page number
sub label_to_page { 
    my $self = shift;
    my $labels_per_page = shift;
    my $label_count = shift;

    my $page_count = int( ($label_count -1) / $labels_per_page) +1;
    return $page_count;
}

sub upload_barcode_output : Path('/breeders/phenotype/upload') :Args(0) {
    my ($self, $c) = @_;
    my $upload = $c->req->upload('phenotype_file');
    my @contents = split /\n/, $upload->slurp;
    my $basename = $upload->basename;
    my $tempfile = $upload->tempname; #create a tempfile with the uploaded file
    if (! -e $tempfile) { 
        die "The file does not exist!\n\n";
    }
    print STDERR "***Basename= $basename, tempfile = $tempfile \n\n"; ##OK
    my $archive_path = $c->config->{archive_path};
 
    $tempfile = $archive_path . "/" . $basename ;
    print STDERR "**tempfile = $tempfile \n\n"; ##OK
    #chack for write permissions in $archive_path !    
    my $upload_success = $upload->copy_to($archive_path . "/" . $basename); #returns false for failure, true for success
    if (!$upload_success) { die "Could not upload!\n $upload_success" ; }
    my $sb = CXGN::Stock::StockBarcode->new( { schema=> $c->dbic_schema("Bio::Chado::Schema", 'sgn_chado') });
    my $identifier_prefix = $c->config->{identifier_prefix};
    my $db_name = $c->config->{trait_ontology_db_name};

    $sb->parse(\@contents, $identifier_prefix, $db_name);
    my $parse_errors = $sb->parse_errors;
    $sb->verify; #calling the verify function
    my $verify_errors = $sb->verify_errors;
    my @errors = (@$parse_errors, @$verify_errors);
    my $warnings = $sb->warnings;
    $c->stash->{tempfile} = $tempfile;
    $c->stash(
        template => '/stock/barcode/upload_confirm.mas',
        tempfile => $tempfile,
        errors   => \@errors,
        warnings => $warnings,
        feedback_email => $c->config->{feedback_email},
        );

}

sub store_barcode_output  : Path('/barcode/stock/store') :Args(0) {
    my ($self, $c) = @_;
    my $filename = $c->req->param('tempfile');
    
    my @contents = read_file($filename);

    my $sb = CXGN::Stock::StockBarcode->new( { schema=> $c->dbic_schema("Bio::Chado::Schema", 'sgn_chado') });
    my $identifier_prefix = $c->config->{identifier_prefix};
    my $db_name = $c->config->{trait_ontology_db_name};
    $sb->parse(\@contents, $identifier_prefix, $db_name);
    $sb->store;
    my $error = $sb->store_error;
    my $message = $sb->store_message;
    $c->stash(
        template => '/stock/barcode/confirm_store.mas',
        error    => $error,
        message  => $message,
        );
}

###
1;#
###
