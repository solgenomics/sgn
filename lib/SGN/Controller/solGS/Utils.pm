package SGN::Controller::solGS::Utils;

use Moose;
use namespace::autoclean;
use File::Slurp qw /write_file read_file/;


sub convert_arrayref_to_hashref {
    my ($self, $array_ref) = @_;
  
    my %hash_var = ();

    foreach my $dt (@$array_ref)
    {
	print STDERR "\ndt: @$dt\n";
        $hash_var{$dt->[0]} = $dt->[1];
    }
    return \%hash_var;
}


sub count_cores {
    my $self= shift;

    my $data = qx/lscpu | grep -e '^CPU(s)'/;   
    my ($name, $cores) = split(':', $data);
    $cores =~ s/\s+//g;

    return $cores;
    
}


sub read_file_data {
    my ($self, $file) = @_;
 
    my @lines = read_file($file);
    shift(@lines); 
  
    my @data;
    push @data, map{ [split(/\t/)] } @lines;
   
    return \@data;

}


sub top_10 {
    my ($self, $file) = @_;
      
    my $lines = $self->read_file_data($file);
    my @top_10;
    
    if (scalar(@$lines) > 10) 
    {
	@top_10 = @$lines[0..9];
    }
    else 
    {
	@top_10 = @$lines;
    }

    return \@top_10;
}


sub abbreviate_term {
    my ($self, $term) = @_;
 
    my @words = split(/\s/, $term);
    
    my $acronym;
	
    if (scalar(@words) == 1) 
    {
	$acronym = shift(@words);
    }  
    else 
    {
	foreach my $word (@words) 
        {
	    if ($word =~ /^[A-Za-z]/)
            {
		my $l = substr($word,0,1,q{});
		
		$acronym .= $l;
	    }
	    elsif ($word =~/^[0-9]/)
	    {
		my $str_wrd = $word;
		my @str = $str_wrd =~ /[\d+-\d+]/g;
		my $str = join("", @str);
		my @wrd = $word =~ /[A-Za-z]/g;
		my $wrd = join("", @wrd);
	
		my $l = substr($wrd,0,1,q{});
		
		$acronym .= $str . uc($l);
	
	    } 
            else 
            {
                $acronym .= $word;
            }

	    $acronym = uc($acronym);
	}	   
    }
  
    return $acronym;

}


sub acronymize_traits {
    my ($self, $traits) = @_;
  
    my $acronym_table = {};  
    my $cnt = 0;
    my $acronymized_traits;
    
    no warnings 'uninitialized';
    foreach my $trait_name (@$traits)
    {
	$cnt++;

        my $abbr = $self->abbreviate_term($trait_name);

	$abbr = $abbr . '.2' if $cnt > 1 && $acronym_table->{$abbr};  

        $acronymized_traits .= $abbr;
	$acronymized_traits .= "\t" unless $cnt == scalar(@$traits);
	
        $acronym_table->{$abbr} = $trait_name if $abbr;
	my $tr_h = $acronym_table->{$abbr};
    }
 
    my $acronym_data = {
	'acronymized_traits' => $acronymized_traits,
	'acronym_table'      => $acronym_table
    };

    return $acronym_data;
}


####
1;
####
