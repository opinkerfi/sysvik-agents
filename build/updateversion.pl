#!/usr/bin/perl
use strict;

my $new_version = shift;
chomp($new_version);

if(!$new_version){
	print "Version missing\n";
	exit;
}

my @files = (
	"apwatch",
	"sysvik",
	"sysvik-data"
);

foreach(@files){
	if(!-e $_){
		print "Unable to open $_\n";
	} else {
		my $file = $_;
		my $file_tmp = "$file.tmp";
		open(F, $file);
		open(O, ">$file_tmp");
		print "Inspecting $file\n";
		while(<F>){
			chomp($_);
			if($_ =~ 'my \$version'){
				print "Updating version to $new_version\n";
				print O "my \$version = \"$new_version\";\n";
			} elsif($_ =~ 'my \$agent_version'){
				print O "my \$agent_version = \"$new_version\";\n";
			} else {
				print O "$_\n";
			}
		}
		close(F);
			close(O);
		print "Renaming $file_tmp to $file\n";
		rename($file_tmp, $file);
	}
}
