
###NOTE: This is deprecated and has been moved to CXGN::Trial::Download.

package SGN::Controller::BreedersToolbox::Download;

use Moose;

BEGIN { extends 'Catalyst::Controller'; }

use strict;
use warnings;
use JSON::XS;
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
use POSIX qw(strftime);
use Sort::Maker;
use DateTime;

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

#Deprecated. Look t0 SGN::Controller::BreedersToolbox::Trial->trial_download
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

#Deprecated by deprecation of download_trial_layout_action
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

#Deprecated by deprecation of download_trial_layout_action
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



#sub download_datacollector_excel {
#    my $self = shift;
#    my $c = shift;
#    my $trial_id = shift;

#    $c->tempfiles_subdir("downloads"); # make sure the dir exists
#    my ($fh, $tempfile) = $c->tempfile(TEMPLATE=>"downloads/DataCollector_".$trial_id."_XXXXX");

#    close($fh);

#    my $file_path = $c->config->{basepath}."/".$tempfile.".xls"; # need xls extension to avoid trouble

#    move($tempfile, $file_path);

#    my $td = CXGN::Trial::Download->new(
#	{
#	    bcs_schema => $c->dbic_schema("Bio::Chado::Schema"),
#	    trial_id => $trial_id,
#	    filename => $file_path,
#	    format => "DataCollectorExcel",
#	},
#	);

#    $td->download();
#      my $file_name = basename($file_path);
#     $c->res->content_type('Application/xls');
#     $c->res->header('Content-Disposition', qq[attachment; filename="$file_name"]);

#    my $output = read_file($file_path);

#    $c->res->body($output);

#}

sub _parse_list_from_json {
    my $list_json = shift;
    print STDERR Dumper $list_json;
    my $json = new JSON;
    if ($list_json) {
        my $decoded_list = $json->allow_nonref->utf8->relaxed->escape_slash->loose->allow_singlequote->allow_barekey->decode($list_json);
        #my $decoded_list = decode_json($list_json);
        my @array_of_list_items = @{$decoded_list};
        return \@array_of_list_items;
    } else {
        return;
    }
}

sub download_multiple_trials_action : Path('/breeders/trials/phenotype/download') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    my $user = $c->user();
    if (!$user) {
        $c->res->redirect( uri( path => '/solpeople/login.pl', query => { goto_url => $c->req->uri->path_query } ) );
        return;
    }

    my $format = $c->req->param("format") || "xls";
    my $data_level = $c->req->param("dataLevel") || "plot";
    my $timestamp_option = $c->req->param("timestamp") || 0;
    my $trait_list = $c->req->param("trait_list");
    my $year_list = $c->req->param("year_list");
    my $location_list = $c->req->param("location_list");
    my $trial_list = $c->req->param("trial_list");
    my $accession_list = $c->req->param("accession_list");
    my $plot_list = $c->req->param("plot_list");
    my $plant_list = $c->req->param("plant_list");
    my $trait_contains = $c->req->param("trait_contains");
    my $phenotype_min_value = $c->req->param("phenotype_min_value") || "";
    my $phenotype_max_value = $c->req->param("phenotype_max_value") || "";

    if ($data_level eq 'plants') {
        my $trial = $c->stash->{trial};
        if (!$trial->has_plant_entries()) {
            $c->stash->{template} = 'generic_message.mas';
            $c->stash->{message} = "The requested trial (".$trial->get_name().") does not have plant entries. Please create the plant entries first.";
            return;
        }
    }

    my @trait_list;
    if ($trait_list && $trait_list ne 'null') { @trait_list = @{_parse_list_from_json($trait_list)}; }
    my @trait_contains_list;
    if ($trait_contains && $trait_contains ne 'null') { @trait_contains_list = @{_parse_list_from_json($trait_contains)}; }
    my @year_list;
    if ($year_list && $year_list ne 'null') { @year_list = @{_parse_list_from_json($year_list)}; }
    my @location_list;
    if ($location_list && $location_list ne 'null') { @location_list = @{_parse_list_from_json($location_list)}; }
    my @trial_list;
    if ($trial_list && $trial_list ne 'null') { @trial_list = @{_parse_list_from_json($trial_list)}; }
    my @accession_list;
    if ($accession_list && $accession_list ne 'null') { @accession_list = @{_parse_list_from_json($accession_list)}; }
    my @plot_list;
    if ($plot_list && $plot_list ne 'null') { @plot_list = @{_parse_list_from_json($plot_list)}; }
    my @plant_list;
    if ($plant_list && $plant_list ne 'null') { @plant_list = @{_parse_list_from_json($plant_list)}; }

    #Input list arguments can be arrays of integer ids or strings; however, when fed to CXGN::Trial::Download, they must be arrayrefs of integer ids
    my @trait_list_int;
    foreach (@trait_list) {
        if ($_ =~ m/^\d+$/) {
            push @trait_list_int, $_;
        } else {
            my $cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, $_)->cvterm_id();
            push @trait_list_int, $cvterm_id;
        }
    }

    my $plugin = "";
    if ($format eq "xls") {
        $plugin = "TrialPhenotypeExcel";
    }
    if ($format eq "csv") {
        $plugin = "TrialPhenotypeCSV";
    }

    my $dir = $c->tempfiles_subdir('download');
    my $temp_file_name = "phenotype" . "XXXX";
    my $rel_file = $c->tempfile( TEMPLATE => "download/$temp_file_name");
    $rel_file = $rel_file . ".$format";
    my $tempfile = $c->config->{basepath}."/".$rel_file;

    print STDERR "TEMPFILE : $tempfile\n";

    #List arguments should be arrayrefs of integer ids
    my $download = CXGN::Trial::Download->new({
        bcs_schema => $schema,
        trait_list => \@trait_list_int,
        year_list => \@year_list,
        location_list => \@location_list,
        trial_list => \@trial_list,
        accession_list => \@accession_list,
        plot_list => \@plot_list,
        plant_list => \@plant_list,
        filename => $tempfile,
        format => $plugin,
        data_level => $data_level,
        include_timestamp => $timestamp_option,
        trait_contains => \@trait_contains_list,
        phenotype_min_value => $phenotype_min_value,
        phenotype_max_value => $phenotype_max_value,
    });

    my $error = $download->download();

    my $file_name = "phenotype.$format";
    $c->res->content_type('Application/'.$format);
    $c->res->header('Content-Disposition', qq[attachment; filename="$file_name"]);

    my $output = read_file($tempfile);

    $c->res->body($output);
}


#Deprecated. Look to SGN::Controller::BreedersToolbox::Trial->trial_download
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



sub download_action : Path('/breeders/download_action') Args(0) {
    my $self = shift;
    my $c = shift;

    my $accession_list_id = $c->req->param("accession_list_list_select");
    my $trial_list_id     = $c->req->param("trial_list_list_select");
    my $trait_list_id     = $c->req->param("trait_list_list_select");
    my $data_type         = $c->req->param("data_type")|| "phenotype";
    my $format            = $c->req->param("format");
    my $timestamp_included = $c->req->param("timestamp") || 0;
    my $cookie_value      = $c->req->param("download_token_value");

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

    my $result;
    my $output = "";

    if ($data_type eq "phenotype") {
        my @data = $bs->get_extended_phenotype_info_matrix($accession_sql, $trial_sql, $trait_sql, $timestamp_included);

        if ($format eq "html") { #dump html in browser
            $output = "";
            my @header = split /\t/, $data[0];
            my $num_col = scalar(@header);
            for (my $line =0; $line< @data; $line++) {
                my @columns = split /\t/, $data[$line];
                my $step = 1;
                for(my $i=0; $i<$num_col; $i++) {
                    if ($columns[$i]) {
                        $output .= "\"$columns[$i]\"";
                    } else {
                        $output .= "\"\"";
                    }
                    if ($step < $num_col) {
                        $output .= ",";
                    }
                    $step++;
                }
                $output .= "\n";
            }
            $c->res->content_type("text/plain");
            $c->res->body($output);

        } else {
            # if xls or csv, create tempfile name and place to save it
            my $what = "phenotype_download";
            my $time_stamp = strftime "%Y-%m-%dT%H%M%S", localtime();
            my $dir = $c->tempfiles_subdir('download');
            my $temp_file_name = $time_stamp . "$what" . "XXXX";
            my $rel_file = $c->tempfile( TEMPLATE => "download/$temp_file_name");
            my $tempfile = $c->config->{basepath}."/".$rel_file;

            if ($format eq ".csv") {

                #build csv with column names
                open(CSV, ">", $tempfile) || die "Can't open file $tempfile\n";
                    my @header = split /\t/, $data[0];
                    my $num_col = scalar(@header);
                    for (my $line =0; $line< @data; $line++) {
                        my @columns = split /\t/, $data[$line];
                        my $step = 1;
                        for(my $i=0; $i<$num_col; $i++) {
                            if ($columns[$i]) {
                                print CSV "\"$columns[$i]\"";
                            } else {
                                print CSV "\"\"";
                            }
                            if ($step < $num_col) {
                                print CSV ",";
                            }
                            $step++;
                        }
                        print CSV "\n";
                    }
                close CSV;

            } else {
                my $ss = Spreadsheet::WriteExcel->new($tempfile);
                my $ws = $ss->add_worksheet();

                for (my $line =0; $line< @data; $line++) {
                    my @columns = split /\t/, $data[$line];
                    for(my $col = 0; $col<@columns; $col++) {
                        $ws->write($line, $col, $columns[$col]);
                    }
                }
                #$ws->write(0, 0, "$program_name, $location ($year)");
                $ss ->close();

                $format = ".xls";
            }

            #Using tempfile and new filename,send file to client
            my $file_name = $time_stamp . "$what" . "$format";
            $c->res->content_type('Application/'.$format);
            $c->res->cookies->{fileDownloadToken} = { value => $cookie_value};
            $c->res->header('Content-Disposition', qq[attachment; filename="$file_name"]);
            $output = read_file($tempfile);
            $c->res->body($output);
        }
    }

    if ($data_type eq "genotype") {
        $result = $bs->get_genotype_info($accession_sql, $trial_sql);
        my @data = @$result;

        my $output = "";
        foreach my $d (@data) {
            $output .= join "\t", @$d;
            $output .= "\n";
        }
        $c->res->content_type("text/plain");
        $c->res->body($output);
    }
}


# pedigree download -- begin

sub download_pedigree_action : Path('/breeders/download_pedigree_action') {
my $self = shift;
my $c = shift;
my ($accession_list_id, $accession_data, @accession_list, @accession_ids, $pedigree_stock_id, $accession_name, $female_parent, $male_parent);

    $accession_list_id = $c->req->param("pedigree_accession_list_list_select");
    $accession_data = SGN::Controller::AJAX::List->retrieve_list($c, $accession_list_id);
    @accession_list = map { $_->[1] } @$accession_data;


    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
    my $t = CXGN::List::Transform->new();
    my $acc_t = $t->can_transform("accessions", "accession_ids");
    my $accession_id_hash = $t->transform($schema, $acc_t, \@accession_list);

    @accession_ids = @{$accession_id_hash->{transform}};

    my ($tempfile, $uri) = $c->tempfile(TEMPLATE => "pedigree_download_XXXXX", UNLINK=> 0);

    open my $TEMP, '>', $tempfile or die "Cannot open tempfile $tempfile: $!";

	print $TEMP "Accession\tFemale_Parent\tMale_Parent";
 	print $TEMP "\n";
       my $check_pedigree = "FALSE";
       my $len;


	for (my $i=0 ; $i<scalar(@accession_ids); $i++)
	{

	$accession_name = $accession_list[$i];
	my $pedigree_stock_id = $accession_ids[$i];
	my @pedigree_parents = CXGN::Chado::Stock->new ($schema, $pedigree_stock_id)->get_direct_parents();
	$len = scalar(@pedigree_parents);
	if($len > 0)
	{
      		$check_pedigree = "TRUE";
	}



	    $female_parent = $pedigree_parents[0][1] || '';
	    $male_parent = $pedigree_parents[1][1] || '';
	  print $TEMP "$accession_name \t  $female_parent \t $male_parent\n";

  	}

if ($check_pedigree eq "FALSE")
{
print $TEMP "\n";
print $TEMP "No pedigrees found in the Database for the accessions searched. \n";
}

 close $TEMP;

 my $filename = "pedigree.txt";

 $c->res->content_type("application/text");
 $c->res->header('Content-Disposition', qq[attachment; filename="$filename"]);
  my $output = read_file($tempfile);

  $c->res->body($output);

}


# pedigree download -- end

#=pod
sub download_gbs_action : Path('/breeders/download_gbs_action') {
  my ($self, $c) = @_;

  print STDERR "Collecting download parameters ...  ".localtime()."\n";
  my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
  my $format = $c->req->param("format") || "list_id";
  my $dl_token = $c->req->param("token") || "no_token";
  my $dl_cookie = "download".$dl_token;
  my $snp_genotype_row = $schema->resultset("Cv::Cvterm")->find({ name => 'snp genotyping' });
  my $snp_genotype_id = $snp_genotype_row->cvterm_id();

  my $bs = CXGN::BreederSearch->new( { dbh=>$c->dbc->dbh() });
  my (@accession_ids, @accession_list, @accession_genotypes, @unsorted_markers, $accession_data, $id_string, $protocol_id);

  if ($format eq 'accession_ids') {       #use protocol id and accession ids supplied directly
    $id_string = $c->req->param("ids");
    @accession_ids = split(',',$id_string);
    $protocol_id = $c->req->param("protocol_id");
  }
  elsif ($format eq 'list_id') {        #get accession names from list and tranform them to ids


    my $accession_list_id = $c->req->param("genotype_accession_list_list_select");
    $protocol_id = $c->req->param("genotyping_protocol_select");
    #$protocol_id = 2;

    if ($accession_list_id) {
	    $accession_data = SGN::Controller::AJAX::List->retrieve_list($c, $accession_list_id);
    }

    @accession_list = map { $_->[1] } @$accession_data;

    my $t = CXGN::List::Transform->new();

    my $acc_t = $t->can_transform("accessions", "accession_ids");
    my $accession_id_hash = $t->transform($schema, $acc_t, \@accession_list);
    @accession_ids = @{$accession_id_hash->{transform}};
  }

  my ($tempfile, $uri) = $c->tempfile(TEMPLATE => "gt_download_XXXXX", UNLINK=> 0);  #create download file
  open my $TEMP, '>', $tempfile or die "Cannot open tempfile $tempfile: $!";

  print STDERR "Downloading genotype data ... ".localtime()."\n";

  print STDERR "Accession ids= @accession_ids \n";
  print STDERR "Protocol id= $protocol_id \n";
  print STDERR "Snp genotype id= $snp_genotype_id \n";

  my $resultset = $bs->get_genotype_info(\@accession_ids, $protocol_id, $snp_genotype_id); #retrieve genotype resultset
  my $genotypes = $resultset->{genotypes};

  if (scalar(@$genotypes) == 0) {
    my $error = "No genotype data was found for @accession_list, and protocol with id $protocol_id. You can determine which accessions have been genotyped with a given protocol by using the search wizard.";
    $c->res->content_type("application/text");
    $c->res->header('Content-Disposition', qq[attachment; filename="Download error details"]);
    $c->res->body($error);
    return;
  }

  print $TEMP "# Downloaded from ".$c->config->{project_name}.": ".localtime()."\n"; # print header info
  print $TEMP "# Protocol: id=$protocol_id, name=".$resultset->{protocol_name}."\n";
  print $TEMP "Marker\t";

  print STDERR "Decoding genotype data ...".localtime()."\n";
  my $json = JSON::XS->new->allow_nonref;

  for (my $i=0; $i < scalar(@$genotypes) ; $i++) {       # loop through resultset, printing accession uniquenames as column headers and storing decoded gt strings in array of hashes
    print $TEMP $genotypes->[$i][0] . "\t";
    my $genotype_hash = $json->decode($genotypes->[$i][1]);
    push(@accession_genotypes, $genotype_hash);
  }
  @unsorted_markers = keys   %{ $accession_genotypes[0] };
  print $TEMP "\n";

  #print STDERR "building custom optimiized sort ... ".localtime()."\n";
  my $marker_sort = make_sorter(
    qw( GRT ),
    number => {
      # primary subkeys (chrom number) comparison
      # ascending numeric comparison
      code => '/(\d+)/',
      ascending => 1,
      unsigned => 1,
    },
    number => {
      # if chrom number is equal
      # return secondary subkey (chrom position) comparison
      # ascending numeric comparison
      code => '/(\d+)$/',
      ascending => 1,
      unsigned => 1,
    },
  );
  die "make_sorter: $@" unless $marker_sort;

  print STDERR "Sorting markers... ".localtime()."\n";
  my @markers = $marker_sort->( @unsorted_markers );

  print STDERR "Printing sorted markers and scores ... ".localtime()."\n";
  for my $j (0 .. $#markers) {
    print $TEMP "$markers[$j]\t";

    for my $i ( 0 .. $#accession_genotypes ) {
      if($i == $#accession_genotypes ) {                              # print last accession genotype value and move onto new line
        print $TEMP "$accession_genotypes[$i]{$markers[$j]}\n";
      }
      elsif (exists($accession_genotypes[$i]{$markers[$j]})) {        # print genotype and tab
        print $TEMP "$accession_genotypes[$i]{$markers[$j]}\t";
      }
    }
  }

  close $TEMP;
  print STDERR "Downloading file ... ".localtime()."\n";

  my $filename;
  if (scalar(@$genotypes) > 1) { #name file with number of acessions and protocol id
    $filename = scalar(@$genotypes) . "genotypes-p" . $protocol_id . ".txt";
  }
  else { #name file with acesssion name and protocol id if there's just one
    $filename = $genotypes->[0][0] . "genotype-p" . $protocol_id . ".txt";
  }

  $c->res->content_type("application/text");
  $c->res->cookies->{$dl_cookie} = {
    value => $dl_token,
    expires => '+1m',
  };
  $c->res->header('Content-Disposition', qq[attachment; filename="$filename"]);
  my $output = read_file($tempfile);
  $c->res->body($output);
}

#=pod

#=cut

sub gbs_qc_action : Path('/breeders/gbs_qc_action') Args(0) {
    my $self = shift;
    my $c = shift;

    my $accession_list_id = $c->req->param("genotype_accession_list_list_select");
    my $trial_list_id     = $c->req->param("genotype_trial_list_list_select");
    my $data_type         = $c->req->param("data_type") || "genotype";
    my $format            = $c->req->param("format");

    my $accession_data = SGN::Controller::AJAX::List->retrieve_list($c, $accession_list_id);
    my $trial_data = SGN::Controller::AJAX::List->retrieve_list($c, $trial_list_id);

    my @accession_list = map { $_->[1] } @$accession_data;
    my @trial_list = map { $_->[1] } @$trial_data;

    my $bs = CXGN::BreederSearch->new( { dbh=>$c->dbc->dbh() });

    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
    my $t = CXGN::List::Transform->new();


    my $acc_t = $t->can_transform("accessions", "accession_ids");
    my $accession_id_data = $t->transform($schema, $acc_t, \@accession_list);

    my $trial_t = $t->can_transform("trials", "trial_ids");
    my $trial_id_data = $t->transform($schema, $trial_t, \@trial_list);


    my $accession_sql = join ",", map { "\'$_\'" } @{$accession_id_data->{transform}};
    my $trial_sql = join ",", map { "\'$_\'" } @{$trial_id_data->{transform}};

    my $data;
    my $output = "";

    my ($tempfile, $uri) = $c->tempfile(TEMPLATE => "download_XXXXX", UNLINK=> 0);


    open my $TEMP, '>', $tempfile or die "Cannot open output_test00.txt: $!";


    $tempfile = File::Spec->catfile($tempfile);


    if ($data_type eq "genotype") {

        print "Download genotype data\n";

	$data = $bs->get_genotype_info($accession_sql, $trial_sql);
	$output = "";



       my @AoH = ();

     for (my $i=0; $i < scalar(@$data) ; $i++)
     {
      my $decoded = decode_json($data->[$i][1]);
      push(@AoH, $decoded);
     }


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


    my ($tempfile_out, $uri_out) = $c->tempfile(TEMPLATE => "output_XXXXX", UNLINK=> 0);


     system("R --slave --args $tempfile $tempfile_out < R/GBS_QC.R");


    my $contents = $tempfile_out;

    $c->res->content_type("text/plain");

    $c->res->body($contents);


}

sub trial_download_log {
    my $self = shift;
    my $c = shift;
    my $trial_id = shift;
    my $message = shift;
    my $now = DateTime->now();

    if (! $c->user) {
      return;
      print STDERR "Can't find user id, skipping download logging\n";
    }
    if ($c->config->{trial_download_logfile}) {
      my $logfile = $c->config->{trial_download_logfile};
      open (my $F, ">>", $logfile) || die "Can't open logfile $logfile\n";
      print $F join("\t", (
            $c->user->get_object->get_username(),
            $trial_id,
            $message,
            $now->year()."-".$now->month()."-".$now->day()." ".$now->hour().":".$now->minute()));
      print $F "\n";
      close($F);
      print STDERR "Download logged in $logfile\n";
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
