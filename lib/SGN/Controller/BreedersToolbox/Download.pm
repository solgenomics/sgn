
package SGN::Controller::BreedersToolbox::Download;

use Moose;

BEGIN { extends 'Catalyst::Controller'; }

use strict;
use warnings;
use JSON qw( decode_json );
use Data::Dumper;
use CGI;
use CXGN::Trial::TrialLayout;
use File::Slurp qw | read_file |;
use File::Temp 'tempfile';
use File::Basename; 
use URI::FromHash 'uri';
use CXGN::List::Transform;
use Spreadsheet::WriteExcel;

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

    my $trial = CXGN::Trial::TrialLayout -> new({ schema => $c->dbic_schema("Bio::Chado::Schema"), trial_id => $trial_id });

    my $design = $trial->get_design();

    $c->tempfiles_subdir("data_export"); # make sure the dir exists
    my ($fh, $tempfile) = $c->tempfile(TEMPLATE=>"data_export/trial_layout_".$trial_id."_XXXXX");

    my $ss = Spreadsheet::WriteExcel->new($fh);
    
    my $ws = $ss->add_worksheet();

    $ws->write(0,0,"plot_name");
    $ws->write(0,1,"accession_name");
    $ws->write(0,2,"plot_number");
    $ws->write(0,3,"block_number");
    $ws->write(0,4,"is_a_control");
    $ws->write(0,5,"rep_number");
    
    my $line = 1;
    foreach my $n (keys(%$design)) { 
     	print STDERR "plot name ".$ws->write($line, 0, $design->{$n}->{plot_name});
	print STDERR " accession name ".$ws->write($line, 1, $design->{$n}->{accession_name});
     	print STDERR " plot number ".$ws->write($line, 2, $design->{$n}->{plot_number});
     	print STDERR " block number ".$ws->write($line, 3, $design->{$n}->{block_number});
     	print STDERR " is a control ".$ws->write($line, 4, $design->{$n}->{is_a_control});
     	print STDERR " rep number ".$ws->write($line, 5, $design->{$n}->{rep_number});
     	$line++;
    }    
    $ss->close();
    
    my $file_name = basename($tempfile);    
    $c->res->content_type('Application/xls');    
    $c->res->header('Content-Disposition', qq[attachment; filename="$file_name"]);   

    my $path = $c->config->{basepath}."/".$tempfile;
    my $output = read_file($path, binmode=>':raw');

    $c->res->body($output);
}

sub download_trial_phenotype_action : Path('/breeders/trial/phenotype/download') Args(1) { 
    my $self = shift;
    my $c = shift;
    my $trial_id = shift;
    
    my $trial_sql = "\'$trial_id\'";
    my $bs = CXGN::BreederSearch->new( { dbh=>$c->dbc->dbh() });
    my @data = $bs->get_phenotype_info_matrix(undef,$trial_sql, undef);
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $rs = $schema->resultset("Project::Project")->search( { 'me.project_id' => $trial_id })->search_related('nd_experiment_projects')->search_related('nd_experiment')->search_related('nd_geolocation');

    my $location = $rs->first()->get_column('description');
    
    my $bprs = $schema->resultset("Project::Project")->search( { 'me.project_id' => $trial_id})->search_related('project_relationship_subject_projects');
    my $pbr = $schema->resultset("Project::Project")->search( { 'me.project_id'=> $bprs->object_id() } );
    my $program_name = $pbr->first()->name();
    my $year = "";

    #print STDERR "PHENOTYPE DATA MATRIX: ".Dumper(\@data);
    $c->tempfiles_subdir("data_export"); # make sure the dir exists
    my ($fh, $tempfile) = $c->tempfile(TEMPLATE=>"data_export/trial_".$program_name."_phenotypes_".$location."_".$trial_id."_XXXXX");
    my $ss = Spreadsheet::WriteExcel->new($fh);
    my $ws = $ss->add_worksheet();

    for (my $line =0; $line< @data; $line++) { 
	my @columns = split /\t/, $data[$line];
	for(my $col = 0; $col<@columns; $col++) { 
	    $ws->write($line, $col, $columns[$col]);
	}
    }
    $ss->write(0, 0, "$program_name, $location ($year)");
    $ss ->close();

    my $file_name = basename($tempfile);    
    $c->res->content_type('Application/xls');    
    $c->res->header('Content-Disposition', qq[attachment; filename="$file_name"]);   

    my $path = $c->config->{basepath}."/".$tempfile;

    my $output = read_file($path, binmode=>':raw');

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
    
    my $bs = CXGN::BreederSearch->new( { dbh=>$c->dbc->dbh() });

    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
    my $t = CXGN::List::Transform->new();
    
    my $acc_t = $t->can_transform("accessions", "accession_ids");
    my $accession_id_data = $t->transform($schema, $acc_t, $unique_list);

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

    print STDERR "IDS: $accession_list_id, $trial_list_id \n";

    my $accession_data = SGN::Controller::AJAX::List->retrieve_list($c, $accession_list_id);
    my $trial_data = SGN::Controller::AJAX::List->retrieve_list($c, $trial_list_id);
   # my $trait_data = SGN::Controller::AJAX::List->retrieve_list($c, $trait_list_id);

    my @accession_list = map { $_->[1] } @$accession_data;
    my @trial_list = map { $_->[1] } @$trial_data;
   # my @trait_list = map { $_->[1] } @$trait_data;

    my $bs = CXGN::BreederSearch->new( { dbh=>$c->dbc->dbh() });

    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
    my $t = CXGN::List::Transform->new();
    
     print STDERR Data::Dumper::Dumper(\@accession_list);
     print STDERR Data::Dumper::Dumper(\@trial_list);
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

    print STDERR "SQL-READY: $accession_sql | $trial_sql \n";

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

       print STDERR "your list has ", scalar(@$data)," element \n"; 
       my @AoH = ();

     for (my $i=0; $i < scalar(@$data) ; $i++) 
     {
      my $decoded = decode_json($data->[$i][1]);
      push(@AoH, $decoded); 
     } 
	print STDERR "your array has ", scalar(@AoH)," element \n";
	
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

     print STDERR "download file is", $tempfile,"\n";


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


    print STDERR "IDS: $accession_list_id, $trial_list_id \n";

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

    print STDERR "SQL-READY: $accession_sql | $trial_sql \n";

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

       print STDERR "your list has ", scalar(@$data)," element \n";
      
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

	print STDERR "your array has ", scalar(@AoH)," element \n";
	
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
#=pod
1;
