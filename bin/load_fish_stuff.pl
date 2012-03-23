#!/usr/bin/perl

use strict;
use File::Slurp;
use Getopt::Std;
use File::Basename;
use CXGN::DB::InsertDBH;
use CXGN::Genomic::Clone;
use CXGN::Image;

our ($opt_D, $opt_H, $opt_t);

getopts('D:H:t');

our $dbh = CXGN::DB::InsertDBH->new(
    {
        dbname=>$opt_D,
        dbhost=>$opt_H,
        dbargs => {AutoCommit => 0,
                   RaiseError => 1}
    }) ;


my $master_file = shift;

my @files = read_file($master_file);

foreach my $file (@files) { 
    chomp $file;
    my $path = dirname($file);
    my ($date, $subdir2, $bac_subdir, $subdir4) = split /\//, $path;
    my $bac_subdir2 = '';

    print "This is the bac dir " . $bac_subdir . "\n";

    if ($bac_subdir =~ m/(BAC_SL_FOS0)(\d{3}\w\d{2})/){
       $bac_subdir2 = "F" . $2;
    }

    if ($bac_subdir =~ m/(BAC_SL_MboI0)(\d{3}\w\d{2})/){
       $bac_subdir2 = "M" . $2;
    }

    if ($bac_subdir =~ m/(BAC_)(\d{3}\w\d{2})/){
       $bac_subdir2 = $2;
    }

    if ($bac_subdir2 eq ''){
	die "BAC pathname not found.\n";
    }

    my @fishinfo = read_file($file);
    
    foreach my $fi (@fishinfo) { 
	
	my $lib = "LE_HBA";
	my ($bac_name, $experiment_name, $chr_nr, $chr_arm, $rel_dist) = split /\t/, $fi;

#	if ($bac_name != $bac_subdir2){ 
#	    print $bac_name . " does not match the pathname " . $bac_subdir2 . "\n";
#	}

	if ($bac_name == $bac_subdir2){   #Only read the line that matches the bac named in the path
	    print $bac_name . " matches the pathname " . $bac_subdir2 . "\n";

	    if ($bac_name =~ /^M/) { 
		$bac_name =~ s/^M(.*)/$1/;
		$lib = 'SL_MboI';
	    }

	    elsif ($bac_name =~ /^F/) { 
		$bac_name =~ s/^F(.*)/$1/;
		$lib = 'SL_FOS';
	    }
       
	    my $clone_id = CXGN::Genomic::Clone->retrieve_from_clone_name("$lib$bac_name");

	    if (!$clone_id) { 
		print STDERR "$lib$bac_name not found. Skipping!!!\n";
		next; 
	    }
	    
	    my @images = glob("$path/*.jpg");
	    
	    my $fish_result_id;
	    
	    $chr_arm =~ tr/sSlL/PPQQ/;
	    
	    print STDERR "Found clone_id $clone_id for experiment $experiment_name on $chr_nr $chr_arm, at $rel_dist".(join "\n",@images)."\n\n\n";
	    if ($opt_t) { next; }
	    
	    
	    eval { 
		if ($clone_id ne '' && $chr_nr ne '' && $chr_arm ne '' && $bac_name ne '' && $experiment_name ne '' && $rel_dist ne ''){ 
#this is the part that is crashing, the subroutine insert_fish_result?
		    $fish_result_id = insert_fish_result(
			{ 
			    dbh => $dbh,
			    chromo_num => $chr_nr,
			    chromo_arm => $chr_arm,
			    experiment_name => $experiment_name,
			    percent_from_centromere => $rel_dist,
			    fish_experimenter_name => 'fish_stack',  
			    clone_id => $clone_id,
			}
			);
		    print "this is fish result id " . $fish_result_id . "\n";
		}
		
		else {
		    die "Data not found.\n";
		}
		
		my $image_id;

		foreach my $image (@images) { 
		    my $i = CXGN::Image->new(dbh=>$dbh, image_dir=> '/data/prod/public/images/image_files_sandbox');
		    if ($i->process_image($image, "fish", $fish_result_id)) { 
			$i->set_description("FISH Localization of $bac_name on chromosome $chr_nr arm $chr_arm at $rel_dist");
			$i->set_sp_person_id(233);
			$i->set_obsolete('f');
			$i->store();
			$image_id = $i->get_image_id();

			insert_fish_result_image($fish_result_id, $image_id);
		    }
		    else { 
			print "Could not store image $image. Skipping!!!\n";
		    }
		}

	    };
	    if ($@) { 
		$dbh->rollback();
		print STDERR "Saving of $bac_name, chr $chr_nr arm $chr_arm at dist $rel_dist failed due to $@";
	    }
	    else { 
		print STDERR "Committing info for $chr_nr.\n";
		$dbh->commit();
	    }
	}
    }
}

sub insert_fish_result { 
    my $fd = shift;
    my $result_insert_query =        #fish_result is table name
	"INSERT INTO sgn.fish_result         
          (chromo_num, chromo_arm,
           experiment_name, percent_from_centromere,
           clone_id, fish_experimenter_id, map_id)
          SELECT ?, ?, ?, ?, ?, 
                 (SELECT fish_experimenter_id 
                    FROM sgn.fish_experimenter 
                   WHERE fish_experimenter_name = ?),
                 (SELECT map_id
                    FROM sgn.map
                   WHERE short_name = 'Tomato FISH map')";
    my $dbh = $fd->{dbh};
    my $sth = $dbh->prepare($result_insert_query);

    print STDERR "name=" . $fd->{experiment_name} . "\n";    
    $sth->execute( 
	$fd->{chromo_num},
	$fd->{chromo_arm},
	$fd->{experiment_name},
	$fd->{percent_from_centromere},
	$fd->{clone_id},
	$fd->{fish_experimenter_name},
	);
    
    my $frh = $dbh->prepare("select currval('fish_result_fish_result_id_seq')");
    $frh->execute();
    my ($fish_result_id) = $frh->fetchrow_array();

    return $fish_result_id;
}


sub insert_fish_result_image { 
    my $fish_result_id = shift;
    my $image_id = shift;
    print STDERR "This is the image id " .  $image_id . "\n";

    my $q = "INSERT INTO fish_result_image (fish_result_id, image_id) VALUES (?,?)";
    my $frih = $dbh->prepare($q);
    $frih->execute($fish_result_id, $image_id);
    
}


