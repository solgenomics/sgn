
###NOTE: This is deprecated and has been moved to CXGN::Trial::Download.

package SGN::Controller::BreedersToolbox::Download;

use Moose;

BEGIN { extends 'Catalyst::Controller'; }

use strict;
use warnings;
use JSON qw( decode_json );
use Data::Dumper;
use CGI;
use CXGN::Trial;
use CXGN::Trial::TrialLayout;
use File::Slurp qw | read_file |;
use File::Temp 'tempfile';
use File::Basename; 
use File::Copy;
use URI::FromHash 'uri';
use CXGN::List::Transform;
use Spreadsheet::WriteExcel;
use CXGN::Trial::Download;

sub breeder_download : Path('/breeders/download/') Args(0) { 
    my $self = shift;
    my $c = shift;

    if (!$c->user()) { 	
	# redirect to login page
	$c->res->redirect( uri( path => '/solpeople/login.pl', query => { goto_url => $c->req->uri->path_query } ) ); 
	return;
    }
    
    $c->stash->{template} = '/breeders_toolbox/download.mas';
}

sub download_trial_layout_action : Path('/breeders/trial/layout/download') Args(1) { 
    my $self = shift;
    my $c = shift;
    my $trial_id = shift;
    my $format = $c->req->param("format");

    my $trial = CXGN::Trial::TrialLayout -> new({ schema => $c->dbic_schema("Bio::Chado::Schema"), trial_id => $trial_id });

    my $design = $trial->get_design();

    $self->trial_download_log($c, $trial_id, "trial layout");

    if ($format eq "csv") { 
	$self->download_layout_csv($c, $trial_id, $design);
    }
    else { 
	$self->download_layout_excel($c, $trial_id, $design);
    }
}

sub download_layout_csv { 
    my $self = shift;
    my $c = shift;
    my $trial_id = shift;

    $c->tempfiles_subdir("downloads"); # make sure the dir exists
    my ($fh, $tempfile) = $c->tempfile(TEMPLATE=>"download/trial_layout_".$trial_id."_XXXXX");

    close($fh);

    my $file_path = $c->config->{basepath}."/".$tempfile.".csv"; # need xls extension to avoid trouble
    
    move($tempfile, $file_path);

    my $td = CXGN::Trial::Download->new( 
	{ 
	    bcs_schema => $c->dbic_schema("Bio::Chado::Schema"), 
	    trial_id => $trial_id,
	    filename => $file_path,
	    format => "TrialLayoutCSV",
	},
	);

    $td->download();
     my $file_name = basename($file_path);    
     $c->res->content_type('Application/csv');    
     $c->res->header('Content-Disposition', qq[attachment; filename="$file_name"]);   

    my $output = read_file($file_path);

    $c->res->body($output);
}

sub download_layout_excel { 
    my $self = shift;
    my $c = shift;
    my $trial_id = shift;

    $c->tempfiles_subdir("downloads"); # make sure the dir exists
    my ($fh, $tempfile) = $c->tempfile(TEMPLATE=>"downloads/trial_layout_".$trial_id."_XXXXX");

    close($fh);

    my $file_path = $c->config->{basepath}."/".$tempfile.".xls"; # need xls extension to avoid trouble
    
    move($tempfile, $file_path);

    my $td = CXGN::Trial::Download->new( 
	{ 
	    bcs_schema => $c->dbic_schema("Bio::Chado::Schema"), 
	    trial_id => $trial_id,
	    filename => $file_path,
	    format => "TrialLayoutExcel",
	},
	);

    $td->download();
      my $file_name = basename($file_path);    
     $c->res->content_type('Application/xls');    
     $c->res->header('Content-Disposition', qq[attachment; filename="$file_name"]);   

    my $output = read_file($file_path);

    $c->res->body($output);

}




sub download_multiple_trials_action : Path('/breeders/trials/phenotype/download') Args(1) { 
    my $self = shift;
    my $c = shift;
    my $trial_ids = shift;
    my $format = $c->req->param("format");
    
    $self->trial_download_log($c, $trial_ids, "trial phenotypes");
    
    my @trial_ids = split ",", $trial_ids;
    my $trial_sql = join ",", map { "\'$_\'" } @trial_ids;
    
    my $bs = CXGN::BreederSearch->new( { dbh=>$c->dbc->dbh() });
    my @data = $bs->get_extended_phenotype_info_matrix(undef,$trial_sql, undef);
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    
    $c->tempfiles_subdir("data_export"); # make sure the dir exists
    
    if ($format eq "csv") { 
	###$self->phenotype_download_csv($c, $trial_id, $program_name, $location, $year, \@data);
	$self->phenotype_download_csv($c, '', '', '', '', \@data);
    }
    else { 
	###$self->phenotype_download_excel($c, $trial_id, $program_name, $location, $year, \@data);
	$self->phenotype_download_excel($c, '', '', '', '', \@data);
    }
}


sub download_trial_phenotype_action : Path('/breeders/trial/phenotype/download') Args(1) { 
    my $self = shift;
    my $c = shift;
    my $trial_id = shift;
    my $format = $c->req->param("format");
    
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $plugin = "TrialPhenotypeExcel";
    if ($format eq "csv") { $plugin = "TrialPhenotypeCSV"; }

    my $t = CXGN::Trial->new( { bcs_schema => $schema, trial_id => $trial_id });

    $c->tempfiles_subdir("download");
    my $trial_name = $t->get_name();
    $trial_name =~ s/ /\_/g;
    my $location = $t->get_location()->[1];
    $location =~ s/ /\_/g;
    my ($fh, $tempfile) = $c->tempfile(TEMPLATE=>"download/trial_".$trial_name."_phenotypes_".$location."_".$trial_id."_XXXXX");

    close($fh);
    my $file_path = $c->config->{basepath}."/".$tempfile.".".$format;
    move($tempfile, $file_path);

    
    my $td = CXGN::Trial::Download->new( { 
	bcs_schema => $schema,
	trial_id => $trial_id,
	format => $plugin,
        filename => $file_path,
	user_id => $c->user->get_object()->get_sp_person_id(),
	trial_download_logfile => $c->config->{trial_download_logfile},
    }
    );

    $td->download();

	     my $file_name = basename($file_path);    

     $c->res->content_type('Application/'.$format);    
     $c->res->header('Content-Disposition', qq[attachment; filename="$file_name"]);   

    my $output = read_file($file_path);

    $c->res->body($output);
}
	
sub phenotype_download_csv { 
    my $self = shift;
    my $c = shift;
    my $trial_id = shift;
    my $program_name = shift;
    my $location = shift;
    my $year = shift;
    my $dataref = shift;
    my @data = @$dataref;

    my ($fh, $tempfile) = $c->tempfile(TEMPLATE=>"data_export/trial_".$program_name."_phenotypes_".$location."_".$trial_id."_XXXXX");

    close($fh);
    my $file_path = $c->config->{basepath}."/".$tempfile.".csv";
    move($tempfile, $file_path);

    open(my $F, ">", $file_path) || die "Can't open file $file_path\n";
    for (my $line =0; $line< @data; $line++) { 
	my @columns = split /\t/, $data[$line];
	
	print $F join(",", @columns);
	print $F "\n";
    }

    my $path = $file_path;
    my $output = read_file($path);

    my $file_name = basename($file_path);    
    $c->res->content_type('Application/csv');    
    $c->res->header('Content-Disposition', qq[attachment; filename="$file_name"]);   



    close($F);
    $c->res->body($output);
}

sub phenotype_download_excel { 
    my $self = shift;
    my $c = shift;
    my $trial_id = shift;
    my $program_name = shift;
    my $location = shift;
    my $year = shift;
    my $dataref = shift;
    my @data = @$dataref;

    my ($fh, $tempfile) = $c->tempfile(TEMPLATE=>"data_export/trial_".$program_name."_phenotypes_".$location."_".$trial_id."_XXXXX");

    my $file_path = $c->config->{basepath}."/".$tempfile.".xls";
    move($tempfile, $file_path);
    my $ss = Spreadsheet::WriteExcel->new($file_path);
    my $ws = $ss->add_worksheet();

    for (my $line =0; $line< @data; $line++) { 
	my @columns = split /\t/, $data[$line];
	for(my $col = 0; $col<@columns; $col++) { 
	    $ws->write($line, $col, $columns[$col]);
	}
    }
    $ws->write(0, 0, "$program_name, $location ($year)");
    $ss ->close();

    my $file_name = basename($file_path);    
    $c->res->content_type('Application/xls');    
    $c->res->header('Content-Disposition', qq[attachment; filename="$file_name"]);   

    my $output = read_file($file_path, binmode=>':raw');

    close($fh);
    $c->res->body($output);
}


sub download_action : Path('/breeders/download_action') Args(0) { 
    my $self = shift;
    my $c = shift;
    
    my $accession_list_id = $c->req->param("accession_list_list_select");
    my $trial_list_id     = $c->req->param("trial_list_list_select");
    my $trait_list_id     = $c->req->param("trait_list_list_select");
    my $data_type         = $c->req->param("data_type")|| "phenotype";

    my $format            = $c->req->param("format");

    my $accession_data;
    if ($accession_list_id) { 
	$accession_data = SGN::Controller::AJAX::List->retrieve_list($c, $accession_list_id);
    }

    my $trial_data;
    if ($trial_list_id) { 
	$trial_data = SGN::Controller::AJAX::List->retrieve_list($c, $trial_list_id);
    }

    my $trait_data;
    if ($trait_list_id) { 
	$trait_data = SGN::Controller::AJAX::List->retrieve_list($c, $trait_list_id);
    }

    my @accession_list = map { $_->[1] } @$accession_data;
    my @trial_list = map { $_->[1] } @$trial_data;
    my @trait_list = map { $_->[1] } @$trait_data;

    my $tf = CXGN::List::Transform->new();
    
    my $unique_transform = $tf->can_transform("accession_synonyms", "accession_names");
    
    my $unique_list = $tf->transform($c->dbic_schema("Bio::Chado::Schema"), $unique_transform, \@accession_list);
    
    # get array ref out of hash ref so Transform/Plugins can use it
    my %unique_hash = %$unique_list;
    my $unique_accessions = $unique_hash{transform};

    my $bs = CXGN::BreederSearch->new( { dbh=>$c->dbc->dbh() });

    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
    my $t = CXGN::List::Transform->new();
    
    my $acc_t = $t->can_transform("accessions", "accession_ids");
    my $accession_id_data = $t->transform($schema, $acc_t, $unique_accessions);

    my $trial_t = $t->can_transform("trials", "trial_ids");
    my $trial_id_data = $t->transform($schema, $trial_t, \@trial_list);
    
    my $trait_t = $t->can_transform("traits", "trait_ids");
    my $trait_id_data = $t->transform($schema, $trait_t, \@trait_list);

    my $accession_sql = join ",", map { "\'$_\'" } @{$accession_id_data->{transform}};
    my $trial_sql = join ",", map { "\'$_\'" } @{$trial_id_data->{transform}};
    my $trait_sql = join ",", map { "\'$_\'" } @{$trait_id_data->{transform}};

    my $data; 
    my $output = "";
    
    if ($data_type eq "phenotype") { 
	$data = $bs->get_phenotype_info($accession_sql, $trial_sql, $trait_sql);
	
	$output = "";
	foreach my $d (@$data) { 
	    $output .= join ",", @$d;
	    $output .= "\n";
	}
    }

    if ($data_type eq "genotype") { 
	$data = $bs->get_genotype_info($accession_sql, $trial_sql);
	
	$output = "";
	foreach my $d (@$data) { 
	    $output .= join "\t", @$d;
	    $output .= "\n";
	}
    }
    $c->res->content_type("text/plain");
    $c->res->body($output);
}

#=pod
sub download_gbs_action : Path('/breeders/download_gbs_action') Args(0) { 
    my $self = shift;
    my $c = shift;
    
    my $accession_list_id = $c->req->param("genotype_accession_list_list_select");
    my $trial_list_id     = $c->req->param("genotype_trial_list_list_select");
  #  my $trait_list_id     = $c->req->param("trait_list_list_select");
    my $data_type         = $c->req->param("data_type") || "genotype";
    my $format            = $c->req->param("format");

    #print STDERR "IDS: $accession_list_id, $trial_list_id \n";

    my $accession_data;
    if ($accession_list_id) { 
	$accession_data = SGN::Controller::AJAX::List->retrieve_list($c, $accession_list_id);
    }
    my $trial_data;
    if ($trial_list_id) { 
	$trial_data = SGN::Controller::AJAX::List->retrieve_list($c, $trial_list_id);
    }
   # my $trait_data = SGN::Controller::AJAX::List->retrieve_list($c, $trait_list_id);

    my @accession_list = map { $_->[1] } @$accession_data;
    my @trial_list = map { $_->[1] } @$trial_data;
   # my @trait_list = map { $_->[1] } @$trait_data;

    my $bs = CXGN::BreederSearch->new( { dbh=>$c->dbc->dbh() });

    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
    my $t = CXGN::List::Transform->new();
    
    #print STDERR Data::Dumper::Dumper(\@accession_list);
     #print STDERR Data::Dumper::Dumper(\@trial_list);
#    print STDERR Data::Dumper::Dumper(\@trait_list);

    my $acc_t = $t->can_transform("accessions", "accession_ids");
    my $accession_id_data = $t->transform($schema, $acc_t, \@accession_list);

    my $trial_t = $t->can_transform("trials", "trial_ids");
    my $trial_id_data = $t->transform($schema, $trial_t, \@trial_list);
    
    #my $trait_t = $t->can_transform("traits", "trait_ids");
    #my $trait_id_data = $t->transform($schema, $trait_t, \@trait_list);
    
    my $accession_sql = "";
    if ($accession_id_data) { 
	$accession_sql = join ",", map { "\'$_\'" } @{$accession_id_data->{transform}};
    }

    my $trial_sql = "";
    if ($trial_id_data) { 
	$trial_sql = join ",", map { "\'$_\'" } @{$trial_id_data->{transform}};
    }

    #print STDERR "SQL-READY: $accession_sql | $trial_sql \n";

    my $data; 
    my $output = "";

    my ($tempfile, $uri) = $c->tempfile(TEMPLATE => "download_XXXXX", UNLINK=> 0);
    open my $TEMP, '>', $tempfile or die "Cannot open output_test00.txt: $!";

    print $TEMP "Marker\t";
    for my $i (0 .. $#accession_list){

	print $TEMP "$accession_list[$i]\t";

    }

    print $TEMP "\n";

    if ($data_type eq "genotype") { 		
        print "Download genotype data\n";

	$data = $bs->get_genotype_info($accession_sql, $trial_sql);        
	$output = "";

	#print STDERR "your list has ", scalar(@$data)," element \n"; 
       my @AoH = ();

     for (my $i=0; $i < scalar(@$data) ; $i++) 
     {
      my $decoded = decode_json($data->[$i][1]);
      push(@AoH, $decoded); 
     } 
	#print STDERR "your array has ", scalar(@AoH)," element \n";
	
        my @k=();
	for my $i ( 0 .. $#AoH ){
	   @k = keys   %{ $AoH[$i] }
	}


        for my $j (0 .. $#k){
	    print $TEMP "$k[$j]\t";

	    for my $i ( 0 .. $#AoH ) {
             
            if($i == $#AoH ){  
		print $TEMP "$AoH[$i]{$k[$j]}";

            }else{
		print $TEMP "$AoH[$i]{$k[$j]}\t";
	    }
             
            }

 print $TEMP "\n";

	}

    }

    #print STDERR "download file is", $tempfile,"\n";


      my $contents = $tempfile;

      $c->res->content_type("application/text");
      $c->res->body($contents);


}
#=pod

#=cut
sub gbs_qc_action : Path('/breeders/gbs_qc_action') Args(0) { 
    my $self = shift;
    my $c = shift;
    
    my $accession_list_id = $c->req->param("genotype_accession_list_list_select");
    my $trial_list_id     = $c->req->param("genotype_trial_list_list_select");
  #  my $trait_list_id     = $c->req->param("trait_list_list_select");
    my $data_type         = $c->req->param("data_type") || "genotype";
    my $format            = $c->req->param("format");


    #print STDERR "IDS: $accession_list_id, $trial_list_id \n";

    my $accession_data = SGN::Controller::AJAX::List->retrieve_list($c, $accession_list_id);
    my $trial_data = SGN::Controller::AJAX::List->retrieve_list($c, $trial_list_id);
   # my $trait_data = SGN::Controller::AJAX::List->retrieve_list($c, $trait_list_id);

    my @accession_list = map { $_->[1] } @$accession_data;
    my @trial_list = map { $_->[1] } @$trial_data;
   # my @trait_list = map { $_->[1] } @$trait_data;

    my $bs = CXGN::BreederSearch->new( { dbh=>$c->dbc->dbh() });

    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
    my $t = CXGN::List::Transform->new();
    
#    print STDERR Data::Dumper::Dumper(\@accession_list);
#    print STDERR Data::Dumper::Dumper(\@trial_list);
#    print STDERR Data::Dumper::Dumper(\@trait_list);

    my $acc_t = $t->can_transform("accessions", "accession_ids");
    my $accession_id_data = $t->transform($schema, $acc_t, \@accession_list);

    my $trial_t = $t->can_transform("trials", "trial_ids");
    my $trial_id_data = $t->transform($schema, $trial_t, \@trial_list);
    
    #my $trait_t = $t->can_transform("traits", "trait_ids");
    #my $trait_id_data = $t->transform($schema, $trait_t, \@trait_list);

    my $accession_sql = join ",", map { "\'$_\'" } @{$accession_id_data->{transform}};
    my $trial_sql = join ",", map { "\'$_\'" } @{$trial_id_data->{transform}};
    #my $trait_sql = join ",", map { "\'$_\'" } @{$trait_id_data->{transform}};

    #print STDERR "SQL-READY: $accession_sql | $trial_sql \n";

    my $data; 
    my $output = "";

    my ($tempfile, $uri) = $c->tempfile(TEMPLATE => "download_XXXXX", UNLINK=> 0);

        #$fh000 = File::Spec->catfile($c->config->{gbs_temp_data}, $fh000);
    open my $TEMP, '>', $tempfile or die "Cannot open output_test00.txt: $!";

    #$fh000 = File::Spec->catfile($c->config->{gbs_temp_data}, $fh000);
  #  $tempfile = File::Spec->catfile($c->config->{gbs_temp_data}, $tempfile);
    $tempfile = File::Spec->catfile($tempfile);


    if ($data_type eq "genotype") { 
		
        print "Download genotype data\n";

	$data = $bs->get_genotype_info($accession_sql, $trial_sql);        
	$output = "";

#	say "Your list has ", scalar(@$x), " elements" 

	#print STDERR "your list has ", scalar(@$data)," element \n";
      
       #my @myGBS = ();
       
     
       my @AoH = ();

     for (my $i=0; $i < scalar(@$data) ; $i++) 
#      for my $i ( 0 .. $#data )
     {
      my $decoded = decode_json($data->[$i][1]);
      push(@AoH, $decoded); 
      #print "$i\n";
     }
      # push(@myGBS, 'Moe'); 

	#print STDERR "your array has ", scalar(@AoH)," element \n";
	
#	my $fh000="out_test000.txt";

#	$fh000 = File::Spec->catfile($c->config->{gbs_temp_data}, $fh000);


#        print STDERR "Output file is ", $fh000,"\n";
	
   #     open my $fh00, '>', "output_test00.txt" or die "Cannot open output_test00.txt: $!";

#        open my $fh00, '>', $fh000 or die "Cannot open output_test00.txt: $!";


        my @k=();
	for my $i ( 0 .. $#AoH ){
	   @k = keys   %{ $AoH[$i] }
	}

#        open my $fh00, '>', "output_test00.txt" or die "Cannot open output_test00.txt: $!";

        for my $j (0 .. $#k){

	    print $TEMP "$k[$j]\t";
	    for my $i ( 0 .. $#AoH ) {
             
            if($i == $#AoH ){  
            print $TEMP "$AoH[$i]{$k[$j]}";
            }else{
	    print $TEMP "$AoH[$i]{$k[$j]}\t";
	    }
             
            }

            print $TEMP "\n";

	}
    }


    my ($tempfile_out, $uri_out) = $c->tempfile(TEMPLATE => "output_XXXXX", UNLINK=> 0);


    #system("R --slave --args output_test00.txt qc_output.txt < /home/aiminy/code/code_R/GBS_QC.R"); ok
    #system("R --slave --args output_test00.txt qc_output.txt < ./R/GBS_QC.R"); ok
     system("R --slave --args $tempfile $tempfile_out < R/GBS_QC.R");
    #system("R --slave --args output_test00.txt qc_output.txt < /R/GBS_QC.R"); path is not ok


    my $contents = $tempfile_out;

    $c->res->content_type("text/plain");

    $c->res->body($contents);

#   system("rm output_test*.txt");
#   system("rm qc_output.txt");

}

sub trial_download_log { 
    my $self = shift;
    my $c = shift;
    my $trial_id = shift;
    my $message = shift;

    if (! $c->user) { 
	return;
    }

    if ($c->config->{trial_download_logfile}) { 
	open (my $F, ">>", $c->config->{trial_download_logfile}) || die "Can't open ".$c->config->{trial_download_logfile};
	print $F $c->user->get_object->get_username()."\t".$trial_id."\t$message\n";
	close($F);
    }
    else { 
	print STDERR "Note: set config variable trial_download_logfile to obtain a log of downloaded trials.\n";
    }
}


sub download_sequencing_facility_spreadsheet : Path( '/breeders/genotyping/spreadsheet') Args(1) { 
    my $self = shift;
    my $c = shift;
    my $trial_id = shift;

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $t = CXGN::Trial->new( { bcs_schema => $schema, trial_id => $trial_id });
    
    #my $layout = $t->get_layout()->get_design();

    $c->tempfiles_subdir("data_export"); # make sure the dir exists
    my ($fh, $tempfile) = $c->tempfile(TEMPLATE=>"data_export/trial_".$trial_id."_XXXXX");

    my $file_path = $c->config->{basepath}."/".$tempfile.".xls";
    move($tempfile, $file_path);

    my $td = CXGN::Trial::Download->new( { 
	bcs_schema => $schema,
	trial_id => $trial_id,
	format => "IGDFacilitySpreadsheet",
        filename => $file_path,
	user_id => $c->user->get_object()->get_sp_person_id(),
	trial_download_logfile => $c->config->{trial_download_logfile},
    }
    );

    $td->download();


    # my $ss = Spreadsheet::WriteExcel->new($c->config->{basepath}."/".$file_path);
    # my $ws = $ss->add_worksheet();

    # # write primary headers
    # #
    # $ws->write(0, 0, "Project Details");
    # $ws->write(0, 2, "Sample Details");
    # $ws->write(0, 12, "Organism Details");
    # $ws->write(0, 21, "Origin Details");

    # # write secondary headers
    # #
    # my @headers = ( 
    # 	"Project Name",
    # 	"User ID",
    # 	"Plate Name",
    # 	"Well", 
    # 	"Sample Name", 
    # 	"Pedigree",
    # 	"Population",
    # 	"Stock Number",
    # 	"Sample DNA Concentration (ng/ul)",
    # 	"Sample Volume (ul)",
    # 	"Sample DNA Mass(ng)",
    # 	"Kingdom",
    # 	"Genus",
    # 	"Species",
    # 	"Common Name",
    # 	"Subspecies",
    # 	"Variety",
    # 	"Seed Lot"
    # 	);

    # for(my $i=0; $i<@headers; $i++) { 
    # 	$ws->write(1, $i, $headers[$i]);
    # }

    # # replace accession names with igd_synonyms
    # #
    # print STDERR "Converting accession names to igd_synonyms...\n";
    # foreach my $k (sort wellsort (keys %{$layout})) { 
    # 	my $q = "SELECT value FROM stock JOIN stockprop using(stock_id) JOIN cvterm ON (stockprop.type_id=cvterm.cvterm_id) WHERE cvterm.name='igd_synonym' AND stock.uniquename = ?";
    # 	my $h = $c->dbc->dbh()->prepare($q);
    # 	$h->execute($layout->{$k}->{accession_name});
    # 	my ($igd_synonym) = $h->fetchrow_array();
    # 	$layout->{$k}->{igd_synonym} = $igd_synonym;
    # 	if ($layout->{$k}->{accession_name}=~/BLANK/i) { 
    # 	    $layout->{$k}->{igd_synonym} = "BLANK";
    # 	}
    # }
    # # write plate info
    # #
    # my $line = 0;

    # foreach my $k (sort wellsort (keys %{$layout})) { 
    # 	$ws->write(2 + $line, 0, "NextGen Cassava");
    # 	my $breeding_program_data = $t->get_breeding_programs();
    # 	my $breeding_program_name = "";
    # 	if ($breeding_program_data->[0]) { 
    # 	    $breeding_program_name = $breeding_program_data->[0]->[1];
    # 	}
    # 	$ws->write(2 + $line, 0, $layout->{$k}->{genotyping_project_name});
    # 	$ws->write(2 + $line, 1, $layout->{$k}->{genotyping_user_id});
    # 	$ws->write(2 + $line, 2, $t->get_name());
    # 	$ws->write(2 + $line, 3, $k);
    # 	$ws->write(2 + $line, 4, $layout->{$k}->{igd_synonym});
    # 	$ws->write(2 + $line, 16, "Manihot");
    # 	$ws->write(2 + $line, 17, "esculenta");
    # 	$ws->write(2 + $line, 20, $t->get_location());
    # 	$line++;
    # }

    # $ss ->close();

    # prepare file for download
    #
    my $file_name = basename($file_path);    
    $c->res->content_type('Application/xls');    
    $c->res->header('Content-Disposition', qq[attachment; filename="$file_name"]);   

    

    my $output = read_file($file_path, binmode=>':raw');

    close($fh);
    $c->res->body($output);
}

sub wellsort { 
    my $row_a = substr($a, 0, 1);
    my $row_b = substr($b, 0, 1);

    my $col_a;
    my $col_b;
    if ($a =~ m/(\d+)/) { 
	$col_a = $1;
    }
    if ($b =~ m/(\d+)/) { 
	$col_b = $1;
    }

    if ($row_a ne $row_b) { 
	return $row_a cmp $row_b;
    }
    else { 
	return $col_a <=> $col_b;
    }
}

#=pod
1;
