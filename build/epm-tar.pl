#!/usr/bin/perl
# Pakkar sysvik í .tar.gz
use strict;

my @files = (
	"apwatch",
	"install.sh",
	"LICENSE",
	"sysvik",
	"sysvik-data",
	"sysvik.cron",
	"INSTALL",
	"init.d/sysvikd",
	"lib/SVcore.pm",
	"sysvik-check.sh"
);

my $pwd = pwd();
my @pwd_arr = split("/", $pwd);
my $pwd_count = scalar(@pwd_arr);
my $version = $pwd_arr[$pwd_count-1];

my $filestr;
for(my $i=0; $i < scalar(@files); $i++){
	if($filestr){
		$filestr = "$filestr $version/$files[$i]";
	} else {
		$filestr = "$version/$files[$i]";
	}
}

print "My version: $version\n";
my $cmd = "cd ..; tar -cvzf $version.tar.gz $filestr ; cd $version";
print "$cmd\n";

sub pwd(){
	my $pwd;
	open(P, "/bin/pwd|");
	$pwd = <P>;
	chomp($pwd);
	close(P);
	return $pwd;
}

