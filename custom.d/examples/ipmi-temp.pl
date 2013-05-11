#!/usr/bin/perl
# IPMI 2 Sysvik custom graph
#
# To use with Sysvik
#	1. Install Sysvik (www.sysvik.com)
#	2. Copy this file to /etc/sysvik.d
#	3. Ensure its executable

use strict;

my $graph_name = "temperature";
my $graph_vertical_label = "Celcius";
my $graph_title = "System temperature";

my $debug=0;
my $ipmitool = "/usr/bin/ipmitool";

##
if(!-e $ipmitool){
	print "Unable to locate ipmitool at $ipmitool";
	exit 1;
}

my $cmd = "$ipmitool sdr | /bin/grep Temp";

print "Running: $cmd\n" if $debug;
my $i=1;
my $graph_ds;
open(I, "$cmd|");
while(<I>){
	chomp($_);
	my ($name, $value_raw, $status) = split("[|]", $_);
	my $key = $name;
	$key = strip($key);

	# Change whitespace to _ and convert to lower case
	$key =~ s/ /_/g;
	$key = lc($key);

	$value_raw = strip($value_raw);
	$status = strip($status);

	my($number, $null, $unit) = split(" ", $value_raw);
	if($number ne "disabled"){
		print "gauge $key=$number $name\n";

		if($graph_ds){
			$graph_ds .= ",$key";
		} else {
			$graph_ds = $key;
		}
	}
	$i++;
}
close(I);

my $graph = "graph $graph_name $graph_ds $graph_title;;$graph_vertical_label";

print "$graph\n";

sub strip($){
	my ($input) = @_;

	$input =~ s/\s+$//;
	$input =~ s/^\s+//;

	return $input;	
}


