package SGN::Controller::motifs_finder;

use Moose;
use namespace::autoclean;
use File::Temp qw | tempfile |;
use File::Basename;
use Data::Dumper;


BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

motifs_finder::Controller::motifs_finder - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

=cut

sub index :Path('/tools/motifs_finder/') :Args(0) {
   my ( $self, $c ) = @_;

   $c->stash->{template} = '/tools/motifs_finder/index.mas';
}

sub name_var :Path('/test/') :Args(0) {
    my ($self, $c) = @_;

     # get variables from catalyst object
    my $params = $c->req->body_params();
    my $sequence = $c->req->param("sequence");
    my $widths_of_motifs = $c->req->param("widths_of_motifs");
    my $numbers_of_sites = $c->req->param("numbers_of_sites");
    my $seq_file = $c->req->param("sequence_file");
    my $no_of_seeds = $c->req->param("number_of_seeds");
    my $fragmentation = $c->req->param("fragmentation");
    my $rev_complement = $c->req->param("rev_complement");
    my $weblogo_output = $c->config->{tmp_weblogo_path};
    my $basePath = $c->config->{tempfiles_base_motifs_finder};
    my $cluster_shared_bindir = $c->config->{cluster_motifs_finder};

  # validate the Nucleic Acid in sequence. To ensure the return of line is not seen as a space.
	my @seq;
	my @errors;

    # to generate temporary file name for the analysis
    my ($fh, $filename) =tempfile("XXXXX", DIR => "$basePath/motifs_finder/");
    #my ($fh, $filename) =tempfile("XXXXX", DIR => "$basePath/motifs_finder/");
    
    print STDERR Dumper($filename);
	if ($sequence !~ /^>/ && $seq_file eq '')  {
		push ( @errors , "Please, paste sequences or attach sequence file.<br/>Ensure your sequence conform with 'usage help' description.\n");
	}

	# To send error file to index.mas
	if (scalar (@errors) > 0){
		my $user_errors = join("<br />", @errors);
		$c->stash->{error_msg} = join("<br/>", @errors);
		$c->stash->{template} = '/tools/motifs_finder/index.mas';
		return;
	}
	else {
    	   # If no error prepare the sequence file for sampling
    	   if ($sequence =~ /^>/) {
        		$sequence =~ s/[ \,\-\.\#\(\)\%\'\"\[\]\{\}\:\;\=\+\\\/]/_/gi;
        		@seq = split(/\s/,$sequence);

                #to open and write and print the input file
                open (my $out_fh, ">", $filename."_input.txt") || die ("\nERROR: the file ".$filename."_input.txt could not be found\n");
                print $out_fh join("\n",@seq);

                # to run Gibbs motifs sampler
                my $err = system("$cluster_shared_bindir/Gibbs.linux ".$filename."_input.txt $widths_of_motifs $numbers_of_sites -W 0.8 -w 0.1 -p 50 -j 5 -i 500 $fragmentation $rev_complement -Z -S $no_of_seeds -C 0.5 -y -nopt -o ".$filename."_output -n");
                print STDOUT "print $err\n";
    	    }
    	    elsif ($seq_file) {
                my $err = system("$cluster_shared_bindir/Gibbs.linux $seq_file $widths_of_motifs $numbers_of_sites -W 0.8 -w 0.1 -p 50 -j 5 -i 500 $fragmentation $rev_complement -Z -S $no_of_seeds -C 0.5 -y -nopt -o ".$filename."_output -n");
                print STDOUT "print $err\n";
    	    }

    	    open (my $output_fh, "<", $filename."_output") || die ("\nERROR: the file ".$filename."_output could not be found\n"); # open sampler output file and write into a FH

            # Creating motifs fasta file for weblogo use and other files that are made into tables in the output.mas

        	my $switch = 0;
        	my $motif = 0;
        	my $switch_logo = 0;
        	my $logo = 0;
        	my @string_result;
        	my $logo_file;
        	my $wl_out_fh;
        	my @motif_element;
        	my @logo_image;
        	my @logofile_id;
        	my $lf_id;
        	my @motif_width;
        	my @aa;
        	my @motif_table_file;
        	my $motif_tab_fh;
        	my $motif_tab;
        	my $freq_tab_switch = 0;
        	my $freq_tab_fh;
        	my $freq_tab = 0;
        	my $freq_tab_file;
        	my @freq_tab;
        	my $prob_tab_switch = 0;
        	my $prob_tab_fh;
        	my $prob_tab = 0;
        	my $prob_tab_file;
        	my @prob_tab;
        	my $BGPM_tab_switch = 0;
        	my $BGPM_tab_fh;
        	my $BGPM_tab = 0;
        	my $BGPM_tab_file;
        	my @BGPM_tab;
        	my $sum_indv_tab_switch = 0;
        	my $sum_indv_tab_fh;
        	my $sum_indv_tab = 0;
        	my $sum_indv_tab_file;
        	my @sum_indv_tab;
        	my $sum = 0;
        	my $switch_sum = 0;
        	my @sum;

            while (my $line = <$output_fh>) {
            	chomp $line;
            	push @string_result, $line;
            	if ($line =~ m/^Log\sBackground\sportion\sof\sMap\s\=\s/){
            			$sum = 1;
            	}
            	if ($sum == 1) {
            		$switch_sum++;
            		push @sum, $line;
            		if ($line =~ m/^Elapsed\stime:\s+/) {
            			$sum = 0;
            		}
            	}
            	if ($motif == 1){
            		$switch++;
            			if ($logo == 1 && $line !~ m/^\s+\*+/ ) {
            				$switch_logo++;
            				my @a = split(/\s+/,$line);
            				print  $wl_out_fh ">seq_$switch_logo\n$a[5]\n";
            				@aa = split(/\s+/,$line);
            				print $motif_tab_fh "$line\n";
            			}
            		    if ($line =~ m/^Num\sMotifs/ ) {
            			    $logo = 1;
            			    open ($wl_out_fh, ">", $logo_file) || die ("\nERROR: the file $logo_file could not be found\n");
            			    push @motif_element, $logo_file;
            			    push @logofile_id, $lf_id;
            			    @motif_width = split (/,/,$widths_of_motifs);
            			    print "logo file ID: @logofile_id\n";
            			    print "motif lenght: @motif_width\n";
            			    open ($motif_tab_fh, ">", $motif_tab) || die ("\nERROR: the file $motif_tab could not be found\n");
            			    push @motif_table_file, $motif_tab;
            			}
            		    elsif ($line =~ m/^\s+\*+/ ) {
            				$logo = 0;
					my ($fh, $filename) =tempfile("XXXXX", DIR => "$basePath/motifs_finder/");
					#my ($fh, $filename) =tempfile("XXXXX", DIR => "$basePath/motifs_finder/");
            			}
            			if ($freq_tab == 1) {
            				$freq_tab_switch++;
            				print $freq_tab_fh "$line\n";
            			}
            			if ($line =~ m/^Motif\smodel/ ) {
            				$freq_tab = 1;
            				open ($freq_tab_fh, ">", $freq_tab_file) || die ("\nERROR: the file $freq_tab could not be found\n");
            				push @freq_tab, $freq_tab_file;
            				print "FREQ TABLE: $freq_tab[0]\n";
            			}
            			elsif ($line =~ m/^site\s+/ ) {
            				$freq_tab = 0;
            				my ($fh, $filename) =tempfile("XXXXX", DIR => "$basePath/motifs_finder/");
					#my ($fh, $filename) =tempfile("XXXXX", DIR => "$basePath/motifs_finder/");
            			}
            			if ($prob_tab == 1 && $line !~ m/^Background\sprobability\smodel/) {
            				$prob_tab_switch++;
            				print $prob_tab_fh "$line\n";
            			}
            			if ($line =~ m/^Motif\sprobability\smodel/ ) {
            				$prob_tab = 1;
            				open ($prob_tab_fh, ">", $prob_tab_file) || die ("\nERROR: the file $prob_tab_file could not be found\n");
            				push @prob_tab, $prob_tab_file;
            			}
            			elsif ($line =~ m/^Background\sprobability\smodel/ ) {
				        $prob_tab = 0;
					#my ($fh, $filename) =tempfile("XXXXX", DIR => "$basePath/motifs_finder/");
            				my ($fh, $filename) =tempfile("XXXXX", DIR => "$basePath/motifs_finder/");
            			}
            			if ($BGPM_tab == 1) {
            				$BGPM_tab_switch++;
            				print $BGPM_tab_fh "$line\n";
            			}
            			if ($line =~ m/^Background\sprobability\smodel/ ) {
            				$BGPM_tab = 1;
            				open ($BGPM_tab_fh, ">", $BGPM_tab_file) || die ("\nERROR: the file $BGPM_tab_file could not be found\n");
            				push @BGPM_tab, $BGPM_tab_file;
            			}
            			elsif ($line =~ m/^\s+\d\.\d+\s\d\.\d+\s/ ) {
            				$BGPM_tab = 0;
            				my ($fh, $filename) =tempfile("XXXXX", DIR => "$basePath/motifs_finder/");
					#my ($fh, $filename) =tempfile("XXXXX", DIR => "$basePath/motifs_finder/");
            			}
            			if ($sum_indv_tab == 1 ) {
            				$sum_indv_tab_switch++;
            				print $sum_indv_tab_fh "$line\n";
            				print "FREQ LINES: $line\n";
            			}
            			if ($line =~ m/^Column\s\d\s:\s+Sequence\sDescription\sfrom\s/ ) {
            				$sum_indv_tab = 1;
            				open ($sum_indv_tab_fh, ">", $sum_indv_tab_file) || die ("\nERROR: the file $sum_indv_tab_file could not be found\n");
            				push @sum_indv_tab, $sum_indv_tab_file;
            			}
            			elsif ($line =~ m/^Log\sFragmentation\sportion\sof\sMAP\sfor\smotif\s/ ) {
            				$sum_indv_tab = 0;
            				my ($fh, $filename) =tempfile("XXXXX", DIR => "$basePath/motifs_finder/");
					#my ($fh, $filename) =tempfile("XXXXX", DIR => "$basePath/motifs_finder/");
            			}
            	}
            	if ($line =~ m/^\s+MOTIF\s+([a-z])/){
            		$motif = 1;
            		$logo_file = $filename."_".$1."_wl_input.fasta";
            		$lf_id = $1;
            		$motif_tab = $filename."_".$1;
            		$freq_tab_file = $filename."_freq_".$1;
            		$prob_tab_file = $filename."_prob_".$1;
            		$BGPM_tab_file = $filename."_BGPM_".$1;
            		$sum_indv_tab_file = $filename."_sum_indv_".$1;
            	}
            	elsif ($line =~ m/^Log\s+Fragmentation\s+portion\s+/ ) {
            			$motif = 0;
            			close $wl_out_fh;
            			close $motif_tab_fh;
            			close $freq_tab_fh;
            			close $prob_tab_fh;
            			close $BGPM_tab_fh;
            			close $sum_indv_tab_fh;
            	}
          }

          my @values_motif;
          my $motif_table_value;
          foreach $filename (@motif_table_file){
        	$motif_table_value = get_result_table($filename);
        	push @values_motif, $motif_table_value;
          }
          my $freq_tab_value;
          my @value_freq_tab;
          foreach $filename (@freq_tab) {
        	$freq_tab_value = get_freq_table($filename);
        	push @value_freq_tab, $freq_tab_value;
          }
          my $prob_tab_value;
          my @value_prob_tab;

          foreach $filename (@prob_tab) {
        	$prob_tab_value = get_prob_table($filename);
        	push @value_prob_tab, $prob_tab_value;
          }
          my $BGPM_tab_value;
          my @value_BGPM_tab;
          foreach $filename (@BGPM_tab) {
            $BGPM_tab_value = get_BGPM_table($filename);
        	push @value_BGPM_tab, $BGPM_tab_value;
          }
          my $sum_indv_tab_value;
          my @value_sum_indv_tab;
          foreach $filename (@sum_indv_tab) {
        	$sum_indv_tab_value = get_sum_indv_table($filename);
        	push @value_sum_indv_tab, $sum_indv_tab_value;
          }

        # To run weblogo
        my $cmd;
        foreach $filename (@motif_element){
        	$cmd = "$cluster_shared_bindir/weblogo/seqlogo -F PNG -d 0.5 -T 1 -b -e -B 2 -h 5 -w 18 -y bits -a -M -n -Y -c -f $filename -o ".$filename."_weblogo";
        	push (@logo_image, basename($filename."_weblogo.png"));
        	my $error = system($cmd);
        }

        print STDERR Dumper(\@logo_image);
        $c->stash->{sum} = join("<br/>", @sum);
        $c->stash->{sum_indv_tab} = \@value_sum_indv_tab;
        $c->stash->{BGPM_tab} = \@value_BGPM_tab;
        $c->stash->{prob_tab} = \@value_prob_tab;
        $c->stash->{freq_tab} = \@value_freq_tab;
        $c->stash->{motif_tab} = \@values_motif;
        $c->stash->{tfile} = join("\n", @string_result);
        $c->stash->{res} = join("<br/>", @string_result);
        $c->stash->{outfile} = $filename."_output";
        $c->stash->{parameters} = "$sequence $widths_of_motifs $numbers_of_sites @string_result";
        $c->stash->{logo} = \@logo_image;
        $c->stash->{logoID} = \@logofile_id;
        $c->stash->{logowidth} = \@motif_width;

        $c->stash->{template} = 'tools/motifs_finder/motif_output.mas';
    }


    sub download_file :Path('/result/') :Args(0) {
        my ($self, $c) = @_;
    	my $params = $c->req->body_params();
    	my $filename = $c->req->param("file_name");
    	my $result_file = $c->req->param("output_file");

    	if ($result_file) {
    		$result_file =~ s/<br\/>/\n/gi;
    	}

        #----------------------------------- send file
    	$c->res->content_type('text/plain');
    	$c->res->header('Content-Disposition', qq[attachment; filename="$filename"]);
    	$c->res->body($result_file);
        #$c->stash->{template} = '/output.mas';
    }

    sub get_result_table {
    	my $motif_table_file = shift;
    	my $motif_table_path = $motif_table_file;

    	#print "MOTIF TAB1 PATH: $motif_table_path\n";
    	open (my $tab_fh, "<", $motif_table_path) || die ("\nERROR: the file $motif_table_path could not be found\n");
    	my $html_table .= "<div class='container'>\n";
        $html_table .=  "<table>\n";
    	$html_table .= "<table class='table table-bordered' border=1 cellpadding=0>";
        $html_table .=  "<tr>\n";
        $html_table .= "<th>Seq Num</th>\t";
    	$html_table .=  "<th>Site Num</th>\t";
        $html_table .=  "<th>Left Loc</th>\t";
    	# $html_table .=  "<th></th>\t";
        $html_table .=  "<th>Motifs</th>\t";
    	# $html_table .=  "<th></th>\t";
        $html_table .=  "<th>Right Loc</th>\t";
    	$html_table .=  "<th>Motif Prob</th>\t";
    	$html_table .=  "<th>F/R Motif</th>\t";
    	$html_table .=  "    <th>Seq Desc</th>\t";
        $html_table .=  "  </tr>\n";

        while (my $inpbuf = <$tab_fh>){
            chomp $inpbuf;
    		$inpbuf =~ s/,//g;
    		my ($kk,$seq_num,$site_num,$left_loc,$emty1,$motif,$emty2,$right_loc,$prob,$f_motif,$seq_desc) = split(/\s+/,$inpbuf);
            $html_table .=  "<tr>\n";
            $html_table .=  "<td>$seq_num</td>\t";
            $html_table .=  "<td>$site_num</td>\t";
            $html_table .=  "<td>$left_loc</td>\t";
            # $html_table .=  "<td>$emty1</td>\t";
    		$html_table .=  "<td>$motif</td>\t";
            # $html_table .=  "<td>$emty2</td>\t";
            $html_table .=  "<td>$right_loc</td>\t";
            $html_table .=  "<td>$prob</td>\t";
    		$html_table .=  "<td>$f_motif</td>\t";
            $html_table .=  "    <td>$seq_desc</td>\t";
            $html_table .=  "  </tr>\n";
        }

        close $tab_fh;
    	$html_table .=  "</table>\n";
    	$html_table .= "</div>";
    }

    sub get_freq_table {
        my $freq_tab = shift;
        my $freq_table_path = $freq_tab;
        open (my $tab_fh, "<", $freq_table_path) || die ("\nERROR: the file $freq_table_path could not be found\n");
        my $html_freq_table .= "<div class='container'>\n";
        $html_freq_table .=  "<table>\n";
        $html_freq_table .= "<table class='table table-bordered' border=1 cellpadding=0>";
        #$html_freq_table .= "<div id=prob>";
        #$html_freq_table .= "<table style=float:left>";
        $html_freq_table .=  "<tr>\n";
        $html_freq_table .= "<th>Position #</th>\t";
        $html_freq_table .= "<th>A</th>\t";
        $html_freq_table .= "<th>T</th>\t";
        $html_freq_table .= "<th>C</th>\t";
        $html_freq_table .= "<th>G</th>\t";
        $html_freq_table .= "<th>Info</th>\t";
        $html_freq_table .=  "</tr>\n";

    	while (my $inpbuf = <$tab_fh>){
            chomp $inpbuf;
    		$inpbuf =~ s/_//g;
    		$inpbuf =~ s/\|//g;
    		$inpbuf =~ s/^\s+//g;
    		if ($inpbuf =~ m/^\S+/ && $inpbuf !~ m/^Pos.\s+/){
        		my ($pos_num,$A,$T,$C,$G,$info,) = split(/\s+/,$inpbuf);
        		$html_freq_table .=  "<tr>\n";
        		$html_freq_table .= " <td>$pos_num</td>\t";
        		$html_freq_table .= " <td>$A</td>\t";
        		$html_freq_table .= " <td>$T</td>\t";
        		$html_freq_table .= " <td>$C</td>\t";
        		$html_freq_table .= " <td>$G</td>\t";
        		$html_freq_table .= " <td>$info</td>\t";
        		$html_freq_table .=  "  <tr>\n";
    		}
    	}

    	close $tab_fh;
    	$html_freq_table .=  "</table>\n";
    	$html_freq_table .=  "</div>\n";
    }

    sub get_prob_table {
    	my $prob_tab = shift;
    	my $prob_table_path = $prob_tab;
    	open (my $tab_fh, "<", $prob_table_path) || die ("\nERROR: the file $prob_table_path could not be found\n");
    	my $html_prob_table .= "<div class='container'>\n";
        $html_prob_table .=  "<table>\n";
        $html_prob_table .= "<table class='table table-bordered' border=1 cellpadding=0>";
        $html_prob_table .= "<div id=prob>";
        $html_prob_table .=  "<tr>\n";
        $html_prob_table .= "<th>Position #</th>\t";
        $html_prob_table .= "<th>A</th>\t";
        $html_prob_table .= "<th>T</th>\t";
        $html_prob_table .= "<th>C</th>\t";
        $html_prob_table .= "<th>G</th>\t";
        $html_prob_table .=  "</tr>\n";

    	while (my $inpbuf = <$tab_fh>){
            chomp $inpbuf;
    		$inpbuf =~ s/_//g;
    		$inpbuf =~ s/\|//g;
    		$inpbuf =~ s/^\s+//g;
    		if ($inpbuf =~ m/^\S+/ && $inpbuf !~ m/^Pos.\s+/){
    			#if ($inpbuf =~ m/^Background\sprobability\smodel/){
    				#$inpbuf =~ s/\s//g;
    				#$inpbuf =~ s/Backgroundprobabilitymodel/BP-Model/g;
    			#}
        		my ($pos_num,$A,$T,$C,$G) = split(/\s+/,$inpbuf);
        		$html_prob_table .=  "  <tr>\n";
        		$html_prob_table .= " <td>$pos_num</td>\t";
        		$html_prob_table .= " <td>$A</td>\t";
        		$html_prob_table .= " <td>$T</td>\t";
        		$html_prob_table .= " <td>$C</td>\t";
        		$html_prob_table .= " <td>$G</td>\t";
        		$html_prob_table .=  "  <tr>\n";
    		}
    	}

    	close $tab_fh;
    	$html_prob_table .=  "</table>\n";
    	$html_prob_table .=  "</div>\n";
    }


    sub get_BGPM_table {
       my $BGPM_tab = shift;
       my $BGPM_table_path = $BGPM_tab;
       open (my $tab_fh, "<", $BGPM_table_path) || die ("\nERROR: the file $BGPM_table_path could not be found\n");
       my $html_BGPM_table .= "<div class='container'>\n";
       $html_BGPM_table .=  "<table style='width:100%'>\n";
       $html_BGPM_table .= "<table class='table table-bordered' border=1 cellpadding=0>";
       $html_BGPM_table .= "<thead>";
       $html_BGPM_table .=  " <tr>\n";
       $html_BGPM_table .= "<th style='width:10%'>A</th>\t";
       $html_BGPM_table .= " <th style='width:10%'>T</th>\t";
       $html_BGPM_table .= " <th style='width:10%'>C</th>\t";
       $html_BGPM_table .= " <th style='width:10%'>G</th>\t";
       $html_BGPM_table .=  " </tr>\n";
       $html_BGPM_table .=  " </thead>\n";

    	while (my $inpbuf = <$tab_fh>){
            chomp $inpbuf;
    		$inpbuf =~ s/^\s+//g;
    		my ($A,$T,$C,$G) = split(/\s+/,$inpbuf);
    		$html_BGPM_table .=  "<tbody>\n";
    		$html_BGPM_table .=  "<tr>\n";
    		$html_BGPM_table .= "<td>$A</td>\t";
    		$html_BGPM_table .= "<td>$T</td>\t";
    		$html_BGPM_table .= "<td>$C</td>\t";
    		$html_BGPM_table .= "<td>$G</td>\t";
    		$html_BGPM_table .=  "<tr>\n";
    		$html_BGPM_table .=  "</tbody>\n";
    	}

    	close $tab_fh;
    	$html_BGPM_table .=  "</table>\n";
    	$html_BGPM_table .= "</div>";
    }

    sub get_sum_indv_table {
    	my $sum_indv_tab = shift;
    	my $sum_indv_table_path = $sum_indv_tab;
    	open (my $tab_fh, "<", $sum_indv_table_path) || die ("\nERROR: the file $sum_indv_table_path could not be found\n");
    	my $html_sum_indv_table;
    	while ( my $inpbuf = <$tab_fh>){
            chomp $inpbuf;
    		if ($inpbuf =~ m/^\S+/ ){
    			my $html_inpbuf = join("<br/>", $inpbuf);
    			$html_sum_indv_table .= "$html_inpbuf<br/>\n";
    		}
    	}

    	close $tab_fh;
    	$html_sum_indv_table;
    }

}

=encoding utf8

=head1 AUTHOR

Alex Ogbonna (aco46@cornell.edu)

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
