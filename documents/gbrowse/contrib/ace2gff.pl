#!/usr/bin/perl -w

=head1 NAME 

ace2gff.pl - convert a phrap produced, ace file into a gff formatted file

=head1 SYNOPSIS

  ./ace2gff.pl options ace_file

    -g|--gff=gff_version   gff version output (default:3)
    -h|--help              Print usage
    -t|--type=Source_type  specify the source type (default:phrap)


=head1 OPTIONS

  -g|--gff=gff_version   gff version output (default:3)
  -h|--help              Print usage
  -t|--type=Source_type  specify the source type (default:phrap)

=head1 DESCRIPTION

convert a phrap produced, ace file into a gff formatted file

This program has only been tested for ace files generated at 
Washington University in St. Louis.



=cut

# ----------------------------------------------------
use strict;
use Pod::Usage;
use Getopt::Long;
use Bio::Assembly::IO;
use Bio::Tools::GFF;

my $map_name;
my $map_start;
my $map_stop;
my $map_strand;
my $feature_name;
my $feature_start;
my $feature_stop;
my $feature_actual_start;
my $feature_strand;
my $gff_version=3;
my $source_type="phrap";
my $feature;
my $tags;

my ( $help, $test, $skip );
GetOptions( 
    'h|help'   => \$help,
    't|type=s'   => \$source_type,
    'g|gff=i'   => \$gff_version,
);
pod2usage if ($help or !@ARGV) ;


die "Version $gff_version of GFF is not supported\n"
    if ($gff_version<2 or $gff_version>3);

my $file_in = $ARGV[$#ARGV];

my $in  = Bio::Assembly::IO->new(-file => $file_in , '-format' => 'ace'); 
my $gffio = Bio::Tools::GFF->new( -gff_version => $gff_version);


while(my $assembly=$in->next_assembly()){
    my @contig_ids=$assembly->get_contig_ids;
    my @singlet_ids=$assembly->get_singlet_ids;
    last unless(@contig_ids or @singlet_ids);
    foreach my $contig_id (@contig_ids){
	###Set data for reference contig
	my $contig         = $assembly->get_contig_by_id($contig_id);
	$map_name          = "Contig".$contig_id;
	$map_strand        = $contig->{'_strand'};
	$map_start         = 1;
        $map_stop          = $contig->get_consensus_length();
	($map_start,$map_stop)=($map_stop,$map_start) if ($map_start > $map_stop);
	###Create a SeqFeature with the info for the reference line
	if ($gff_version==3){
	    $tags = {
		ID      => $map_name,
		Name    => $map_name,
	    } ;
	}
	elsif($gff_version==2){
	    $tags = {
		Contig => $map_name,
	    }; 
	}
	$feature = new Bio::SeqFeature::Generic
	    ( -start => $map_start, -end => $map_stop,
	      -strand => $map_strand, -primary => 'contig',
	      -source_tag   => $source_type,
	      -seq_id => $map_name,
	      -display_name => $map_name,
	      -tag    => $tags, 
	      );
    
	###Convert to gff and print
	print $gffio->write_feature($feature);

	###For each read in the contig, 
	###convert info into a SeqFeature,
	###and output as GFF
	my @seqs           = $contig->each_seq;
	die "ERROR: no reads in contig $contig_id\n" unless (@seqs);
	foreach my $seq (@seqs){ 
	    $feature_name  = $seq->id();
            $feature_start = $contig->get_seq_coord($seq)->start();
            $feature_stop  = $contig->get_seq_coord($seq)->end();
	    ($feature_start,$feature_stop)=($feature_stop,$feature_start) if ($feature_start > $feature_stop);
	    $feature_actual_start= $feature_start;
	    $feature_start=1 if ($feature_start<=0);
	    $feature_strand=($seq->strand()<0) ? -1: 1;

	    	
	    if ($gff_version==3){
		$tags = {
		    Parent  => $map_name,
		    ID      => $feature_name,
		    Name    => $feature_name,
		    };
		
	    }
	    elsif($gff_version==2){
		$tags = {
		    read  => $feature_name,
		}; 
	    }
	    if ($feature_actual_start!=$feature_start){
		$tags->{'actual_start'} = $feature_actual_start;
	    }
	    $feature = new Bio::SeqFeature::Generic
		( -start => $feature_start, -end => $feature_stop,
		  -strand => $feature_strand, -primary => 'read',
		  -source_tag   => $source_type,
		  -seq_id => $map_name,
		  -display_name => $feature_name,
		  -tag    => $tags,
		      );
	
	   
	    print $gffio->write_feature($feature);	    
	}
    }

    foreach my $singlet_id (@singlet_ids){
	###UNTESTED until I get an ace file with a singlet
	###Set data for singlet
	my $singlet         = $assembly->get_singlet_by_id($singlet_id);
	$map_name          = $singlet->id();
	$map_strand        = 1;
	$map_start         = 1;
        $map_stop          = $singlet->length();
	($map_start,$map_stop)=($map_stop,$map_start) if ($map_start > $map_stop);
	###Create a SeqFeature with the info for the reference line
	if ($gff_version==3){
	    $feature = new Bio::SeqFeature::Generic
		( -start => $map_start, -end => $map_stop,
		  -strand => $map_strand, -primary => 'read',
		  -source_tag   => $source_type,
		  -seq_id => $map_name,
		  -display_name => $map_name,
		  -tag    => {
		      ID      => $map_name,
		      Name    => $map_name,
		  } 
		  );
	}
	elsif($gff_version==2){
	    $feature = new Bio::SeqFeature::Generic
		( -start => $map_start, -end => $map_stop,
		  -strand => $map_strand, -primary => 'read',
		  -source_tag   => $source_type,
		  -seq_id => $map_name,
		  -display_name => $map_name,
		  -tag    => {
		      Contig => $map_name,
		  } 
		  );
	}
	###Convert to gff and print
	print $gffio->write_feature($feature);	
    }
}
