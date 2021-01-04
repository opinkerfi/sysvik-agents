#    Copyright (C) 2008 Tryggvi Farestveit
#
#   This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License , or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License along
#    with this program; if not , write to the Free Software Foundation , Inc.,
#    51 Franklin Street , Fifth Floor , Boston , MA 02110-1301 USA.
##############################################################################

package SVcore;

use strict;
use IO::Socket;
use FileHandle;
use POSIX;

my $VERSION = "0.2.4";

sub new {
	my($class , %args) = @_;
	my $self = bless({} , $class);
	if(!$args{logfile}){
		$args{logfile} = "";
	}

	if(!$args{debug}){
		$args{debug} = 0;
	}

	if(!$args{noconnect}){
		$args{noconnect} = "";
	}

	$self->{logfile} = $args{logfile};
	$self->{debug} = $args{debug};
	$self->{noconnect} = $args{noconnect};
	$self->{local_db} = $args{local_db};

	return $self;
}

sub SetDebug($$){
	my($self , $debug) = @_;
	if($debug eq 1){
		$self->{debug} = 1;
	} else {
		$self->{debug} = 0;
	}
}

sub ValidateLocalDB($){
	my($self) = @_;

	if(!$self->{local_db}){
		printlog($self , "Unable to start , missing local db path");
		print "Local DB path missing\n";
		exit;
	}
}

# seekstr
#	Searches local database
#	Input: 
#		var = Variable name
#		file = Full path filename of the db (ex: /var/lib/sysvik/local.db)
sub seekstr($$){
	my($self , $var) = @_;

	$self->ValidateLocalDB();

	my $file = $self->{local_db};

	if(!-e $file){
		$self->printlog("Unable to open $file");
	} else {
		my $ret = "";
		open(DATA , $file);
			while(<DATA>){
				chomp($_);
				my @arr = split(";;" , $_ , 2);

				if($arr[0] eq $var){
					$ret = return $arr[1];
				}
			}
		close(DATA);
		return $ret;
	}
}

# delstr 
#	Deletes string in local database	
sub delstr($$){
	my($self , $var) = @_;

	$self->ValidateLocalDB();

	my $file = $self->{local_db};

	my $used=0;
	my $i;
	my @data;
	my @new_data;
	if(-e $file){
		open(DATA , $file);
		@data = <DATA>;
		close(DATA);

		my @data_row;
		my $x=0;
		for($i=0; $i < scalar(@data); $i++){
			chomp($data[$i]);
			@data_row = split(";;" , $data[$i] , 2);
			if($data_row[0] ne $var){
				$new_data[$x] = $data[$i];
				$x++;
			}
		}
	} 

	# Write to the file
	open(DATA , ">$file");
		for(my $i=0; $i < scalar(@new_data); $i++){
			print DATA "$new_data[$i]\n";
		}
	close(DATA);
}
# putstr
#	Updates/Inserts to local database
sub putstr($$$){
	my($self , $var , $val) = @_;

	my $file = $self->{local_db};

	my $used=0;
	my $i;
	my @data;
	if(-e $file){
		open(DATA , $file);
		@data = <DATA>;
		close(DATA);

		my @data_row;
		for($i=0; $i < scalar(@data); $i++){
			chomp($data[$i]);
			@data_row = split(";;" , $data[$i] , 2);
			if($data_row[0] eq $var){
				# Replace the data
				$data[$i] = "$var;;$val";
				$used=1;
			}
		}
	} else {
		$i=0;
	}

	if($used eq 0){
		# The data was not found , insert it
		$data[$i] = "$var;;$val";
		$i++;
	}

	# Write to the file
	open(DATA , ">$file");
		for(my $i=0; $i < scalar(@data); $i++){
			print DATA "$data[$i]\n";
		}
	close(DATA);

	if($used eq 0){
		chmod 0600 , $file;
	}
}

# node_login()
#	Login the node
sub node_login($$$$$$){
	my($self , $basekey , $hostkey1 , $hostkey2 , $agent , $agent_version , $proto_version) = @_;

	$hostkey1 = tkenc($self , $hostkey1 , $basekey);
	$hostkey2 = tkenc($self , $hostkey2 , $basekey);

	my $resp = socket_send($self , "node_login $hostkey1;;$hostkey2;;$agent;;$agent_version;;$proto_version");
	my $xcode=0;
	if($resp =~ "330"){
		# Successful login
		$xcode=1;
	} elsif ($resp =~ "530"){
		printlog($self,"Error: Node login failed");
		sysvik_disconnect($self);
                lock_off($self);
		exit;
	} elsif ($resp =~ "531"){
		printlog($self,"Error: Protocol error");
		sysvik_disconnect($self);
                lock_off($self);
	} else {
		printlog($self,"Error: Unable to login node");
		sysvik_disconnect($self);
                lock_off($self);
		exit;
	}
}

# sysvik_disconnect()
#	Disconnecting from sysvik network
sub sysvik_disconnect($){
	my $self = shift;
	my $resp = socket_send($self , "quit");
	my $socket = $self->{socket};

	my $noconnect = $self->{noconnect};

	if(!$noconnect){
		close($socket);
	}
}

# sysvik_connect()
#	Connecting to the sysvik network
sub sysvik_connect($$$$){
	my($self , $servername , $port , $proto_version) = @_;


	my $socket = IO::Socket::INET->new(
		Proto    => "tcp",
		PeerAddr => $servername,
		PeerPort => $port,
	) or die "Unable to connect to $servername:$port\n";
	printlog($self,"Connected to $servername:$port");

	$socket->autoflush(1);
	
	my $resp = <$socket>;

	# Decode the initial welcoming msg.
	($resp=$resp)=~tr/Q-ZA-Pq-za-p/A-Za-z/;
	$resp = unpack 'u' , $resp;
	chomp($resp);

	my $basekey;
	if($resp =~ 101){
		my @wlch = split(" " , $resp);
		$basekey = $wlch[1];
		
		# Send proto version information
		print $socket "proto $proto_version\r\n";
		my $resp2 = <$socket>;
	} else {
	        printlog($self,"Connection not ok");
	        lock_off();
	        exit;
	}
	$self->{socket} = $socket;
	return ($socket , $basekey);
}

# tkdec()
#       Key based decryption (serial 2008050101)
sub tkdec($$$){
        my($self , $basekey , $input) = @_;

        # de-scramble the input
        my $dec1;
        ($dec1=$input)=~tr/Q-ZA-Pq-za-p/A-Za-z/;
        my $dec2 = unpack 'u' , $dec1;

        my $strl = length($dec2);
        my $keyl = length($basekey);

        my $x;
        my @chunk_arr;
        my $i=0;
        while($strl > 0){
                $chunk_arr[$i] = substr($dec2 , $x , $keyl);
                $x = $x+$keyl;
                $strl= $strl - $keyl;
                $i++;
        }

        my $output = "";
        for(my $i=0; $i < scalar(@chunk_arr); $i++){
                my $line = $chunk_arr[$i];
                my @arr;
                for(my $z=0; $z < length($basekey); $z++){
                        my $s = substr($basekey , $z , 1);
                        my $t = substr($line , $z , 1);
                        $arr[$s] = $t;
                }

                my $chunk = "";
                for(my $v=0; $v < scalar(@arr); $v++){
                        my $aout = $arr[$v];
                        if($aout eq " "){
                                $aout = "";
                        }
                        $chunk = "$chunk$aout";
                }
                $output = "$output$chunk";
        }
        $output =~ s/;TkF;/ /g; # Replace ;TkF; with whitespace
        return $output;
}

# tkenc()
#	Simple key based encryption (serial 2008050101)
sub tkenc($$$){
        my($self , $input , $basekey) = @_;
	my $strl = length($input);

	my $keyl = length($basekey);
	if($keyl ne 10){
	        printlog($self , "Unable to encrypt $basekey ($keyl - $input)");
		exit;
	}

	$input =~ s/[ ]/;TkF;/g; # Replace space with ;TkF;

        my $i=0;
        my $x=0;
        my @chunk_arr;
        while($strl > 0){
                $chunk_arr[$i] = substr($input , $x , $keyl);
                $x = $x+$keyl;
                $strl= $strl - $keyl;
                $i++;
        }

        my $final = "";
        my $output;
        for(my $i=0; $i < scalar(@chunk_arr); $i++){
                my $line = $chunk_arr[$i];
                my $chunk = "";
                for(my $z=0; $z < length($basekey); $z++){
                        my $s = substr($basekey , $z , 1);
                        my $t = substr($line , $s , 1);

                        if($t eq ""){
                                $t = " ";
                        }
                        $chunk = "$chunk$t";
                }
                $output = "$output$chunk";
        }

	# scramble the output
        my $ec1 = pack 'u' , $output;
        my $ec2;
        ($ec2=$ec1)=~tr/A-Za-z/Q-ZA-Pq-za-p/;

	chomp($ec2);
        return $ec2;
}

# get_hostkey()
#	Returns hostkey if available
sub get_hostkey($$){
	my($self , $nodefile) = @_;
	open(NODEFILE , $nodefile);
	my $i=0;

	my ($hostkey1 , $hostkey2);
	while(<NODEFILE>){
		chomp($_);
		if($i eq 0){
			$hostkey1 = $_;
		} elsif($i eq 1){
			$hostkey2 = $_;
			last;
		}
		$i++;
	}
	close(NODEFILE);
	($hostkey1=$hostkey1)=~tr/Q-ZA-Pq-za-p/A-Za-z/;
	($hostkey2=$hostkey2)=~tr/Q-ZA-Pq-za-p/A-Za-z/;
        $hostkey1 = unpack 'u' , $hostkey1;
        $hostkey2 = unpack 'u' , $hostkey2;

	return ($hostkey1 , $hostkey2);
}

# lock_on
#	Lock management: Lock on
sub lock_on($$) {
	my ($self , $lock) = @_;

	if (-e $lock){
		printlog($self , "Lock exist ($lock): Validating");
	        open(LOCK , $lock);
	                my $i = 0;
	                my $oldPID;
	                while(<LOCK>){
	                        chomp($_);
	                        if($_){
	                                $oldPID = $_;
	                        }
	                }
	        close(LOCK);

		if(!-d "/proc/$oldPID" || $oldPID eq ""){
			printlog($self,"Lock exist ($lock): Old lock , removing");
			unlink($lock) || die "Unable to remove $lock";
		} else {
			# Lets look into the running process
			open(CMD , "/proc/$oldPID/cmdline");
			my $cmdline;
			while(<CMD>){
				chomp($_);
				$cmdline = $_;
				last;
			}
			close(CMD);
			if($cmdline =~ "perl"){
				# This is proably our process
				my @farr = stat("/proc/$oldPID/cmdline"); # get file information
				my $mod_time = $farr[9]; # Last modify time
				my $mod_diff = time() - $mod_time;
	
				if($mod_diff > 3600){
					# The process is older than 1 hour. We will kill it
					printlog($self , "Killing process $oldPID. ($cmdline). Age: $mod_diff secs");
					kill 9 , $oldPID;
				} else {
					# Process is under 1 hour old
					exit;
				}
			} else {
				# This is probably not our process. Remove lock and continue running
				printlog($self , "Runnning process $oldPID ($cmdline) not ours. Removing lock");
				unlink($lock) || die "Unable to remove $lock";
			}
		}
	}

	my $pid = $$; # Get current pid
	# Let's create a lock
	open(LOCK , ">$lock") || die "Unable to create $lock";
	        print LOCK "$pid\n";
	close(LOCK);
}

# lock_off
#	Lock management: Lock off
sub lock_off($$){
	my ($self , $lock) = @_;
        # Let's remove the lock
	if(-e $lock){
	        unlink($lock) || die "Unable to remove $lock";
	}
}

# printlog()
#       prints out to a logfile or screen if in debug mode
sub printlog($$){
        my ($self , $text) = @_;

	my @months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
	my @weekDays = qw(Sun Mon Tue Wed Thu Fri Sat Sun);
	my ($sec , $min , $hour , $day , $month , $yearOffset , $dayOfWeek , $dayOfYear , $daylightSavings) = localtime();

	my $year = 1900 + $yearOffset;
#        my $now = time();
	my $debug = $self->{debug};
	my $logfile = $self->{logfile};
        if($debug){
                print "$text\n";
        } elsif ($logfile){
                open (LOG , ">>$logfile");
		printf LOG "%4d-%02d-%02d %02d:%02d:%02d %s\n" , $year,$month+1,$day,$hour,$min,$sec , $text;
#                print LOG "$now $text\n";
                close(LOG);
        }

}

# socket_send()
#       Communications with the server
sub socket_send($$){
        my ($self , $input) = @_;
        chomp($input);
	my $timeout = 20; # 20 sec

	my $resp = "";
	eval {
		my $debug = $self->{debug};
		my $socket = $self->{socket};
		my $noconnect = $self->{noconnect};

	        print "SOCKET SEND: $input\r\n" if $debug;
	        if(!$noconnect){
			# Timeout - wait for input for X secs
			local $SIG{ALRM} = sub { die "alarm\n" }; # NB: \n required
			alarm $timeout;
			# Timeout

        	        print $socket "$input\r\n";
                	$resp = <$socket>;
	                chomp($resp);
        	        print "SOCKET RESPOND: $resp\r\n" if $debug;
			alarm 0; # Reset alarm / timeout
	        }
	};

	if ($@) {
		die unless $@ eq "alarm\n";
		return "timeout";
	} else {
		return $resp;
        }
}

sub DetectOS($){
        my ($self) = @_;

	my $uname;
	# Location of uname
	if (-e "/usr/bin/uname"){
		$uname = "/usr/bin/uname";
	} else {
		$uname = "/bin/uname";
	}

	open(U , "$uname|");
	my $os_type_i = <U>;
	chomp($os_type_i);
	$os_type_i = lc($os_type_i);
	close(U);

	my $os_type;
	if($os_type_i eq "aix"){
		$os_type = "aix";
	} else {
		$os_type = "linux";
	}
	return $os_type;
}

sub GetOsInformation(){
	my($self) = @_;
	my $os_type = $self->DetectOS();

	# Define defaults
	my $name = "na";
	my $version = 0;
	my $version_minor = "na";
	my $pretty_name = "Unknown OS";
	my $id = "";
	my $id_like = "";
	my $version_id = "";
	my $platform_id = "";

	# Get OS manual OS facts (osl)
	if(my ($osl_name, $osl_version, $osl_pretty_name, $osl_version_minor, $osl_id)  = $self->GetOsFactsLocal()){
		# Useful data
		$name = $osl_name;
		$version = $osl_version;
		$version_minor = $osl_version_minor;
		$pretty_name = $osl_pretty_name;
		$id = $osl_id;

#		print "OSR information: name: $osl_name | version: $osl_version | version_minor: $osl_version_minor | pretty_name: $osl_pretty_name\n";	
	} 

	
	# Get OS facts from os-release (osr)
	if(my ($osr_name, $osr_version, $osr_id, $osr_id_like, $osr_version_id, $osr_platform_id, $osr_pretty_name) = $self->GetOsFactsRelease()){
		# This information is more prefered
		$name = $osr_name;
		$version = $osr_version;
		$pretty_name = $osr_pretty_name;
		$id = $osr_id;
		$id_like = $osr_id_like;
		$version_id = $osr_version_id;
		$platform_id = $osr_platform_id;

#		print "OSR information: name: $osr_name | version: $osr_version | id: $osr_id | id_like: $osr_id_like | version_id: $osr_version_id | platform_id: $osr_platform_id | pretty_name: $osr_pretty_name\n";	
	}

#	print "$os_type, $name, $version, $version_minor, $id, $id_like, $version_id, $platform_id, $pretty_name\n";
	return ($os_type, $name, $version, $version_minor, $id, $id_like, $version_id, $platform_id, $pretty_name);
}

# GetOS()
# Returns information about OS version etc.
sub GetOsFactsRelease(){
        my ($self) = @_;

	my ($name , $version , $id , $id_like , $version_id , $platform_id , $pretty_name);
	if(-e "/etc/os-release"){
		# Using os-release information
#		$self->printlog("Detecting OS");
		open(F , "/etc/os-release");
		my %fact;
		while(<F>){
			chomp($_);
			my ($key , $val) = split("=" , $_);
			if($key && $val){
				$val =~ s/^"//i; # Remove " from begin
				$val =~ s/"$//i; # Remove " from end
				$fact{"$key"} = $val;
			}
		}
		close(F);
	
		# Get useful facts
		$name = $fact{"NAME"};
		$version = $fact{"VERSION"};
		$id = $fact{"ID"};
		$id_like = $fact{"ID_LIKE"};
		$version_id = $fact{"VERSION_ID"};
		$platform_id = $fact{"PLATFORM_ID"};
		$pretty_name = $fact{"PRETTY_NAME"};
	
		return ($name, $version, $id, $id_like, $version_id, $platform_id, $pretty_name);
	} else {
		return 0;
	}
}

sub GetOsFactsLocal(){
	my ($self) = @_;

	## Operating system information
	my $os_type = $self->DetectOS();

	## Operating system information
	my $os;
	my $kernel_version;
	if($os_type eq "aix"){
		if(-e "/usr/bin/oslevel"){
			open(U, "/usr/bin/oslevel|");
			$os = <U>;
			chomp($os);
			$kernel_version = $os;
			$os = "AIX ".lc($os);
			close(U);
		}
	} elsif ($os_type eq "linux"){
		# Kernel version
		if(-e "/proc/sys/kernel/osrelease"){
			open(KV, "/proc/sys/kernel/osrelease");
			$kernel_version = <KV>;
       		        chomp($kernel_version);
	               	close(KV);
		}

		# Red Hat
		if(-e "/etc/redhat-release"){
			# Red Hat Linux/Enterprise/Fedora
			open(TMP, "/etc/redhat-release");
				$os = <TMP>;
				chomp($os);
			close(TMP);
		} elsif (-e "/etc/SuSE-release"){
			# SuSE
			open(TMP, "/etc/SuSE-release");
			my ($osl, $osv, $osp);
			my $t=0;
			while(<TMP>){
				chomp($_);
				if($t eq 0){
					$osl = $_;
				}
				my $null;
				if($_ =~ "VERSION"){
					($null, $osv) = split("= ", $_);
				} elsif ($_ =~ "PATCHLEVEL"){
					($null, $osp) = split("= ", $_);
				}
				$t++;
			}
			close(TMP);
			# Remove whitespace
			$osl =~ s/\s+$//;
			$osl =~ s/^\s+//;
			if($osp){
				$os = "$osl Patchlevel: $osp";
			} else {
				$os = $osl;
			}
	        } elsif (-e "/etc/issue"){
			# Ubuntu / Debian
			open(TMP, "/etc/issue");
				$os = <TMP>;
				chomp($os);
				$os =~ s/\\n/ /g;
				$os =~ s/\\l/ /g;
				$os =~ s/\s+$//;
			close(TMP);
		}
	}

	my ($name, $version, $id, $id_like, $version_id, $platform_id, $pretty_name, $version_minor);
	($name, $version, $pretty_name, $version_minor) = $self->TranslateOS($os);
	return ($name, $version, $pretty_name, $version_minor);
}

# TranslateOS()
# Translate OS collected to key/vals needed
sub TranslateOS($$){
	my ($self, $input) = @_;

	my $name; # Name of OS - ex. "CentOS Linux"
	my $version; # OS version ex. 8
	my $version_minor = ""; # Minor version of OS 
	my $pretty_name; # Full name of OS
	my $id;

	$input =~ s/\(R\)//gi; # remove (R)
	my @name_arr = split(" ", $input);

	if($input =~ "Red Hat Enterprise Linux"){
		# Red Hat Enterprise Linux < 8
		$name = "Red Hat Enterprise Linux";
		$pretty_name = $input;
		$id = "rhel";

		if($name_arr[4] eq "WS" || $name_arr[4] eq "ES" || $name_arr[4] eq "AS"){
			$name = "$name $name_arr[4]";
			$version = $name_arr[6];
			$version_minor = $name_arr[9];
			$version_minor =~ s/\)//i;
		} elsif ($name_arr[4] eq "Server"){
			# RHEL 5+ 
			$name = "$name $name_arr[6]";
			if($name_arr[6] ne ""){
				$version = $name_arr[6];
				my @x = split("[.]", $version);
				$version_minor = $x[@x-1]; # Last element
			}
		} else {
			# RHEL 8+
			$name = "$name $name_arr[6]";
			$version = $name_arr[5];
			$version_minor = $version =~ /(\d+)$/;
		}
	} elsif ($input =~"Fedora"){
		# Fedora Core release 1 (Yarrow)
		# Fedora release 7 (Moonshine)
		# Fedora release 8 (Werewolf)
		# Fedora release 9 (Sulphur)
		$name = "Fedora";
		$pretty_name = $input;
		$id = "fedora";

		my $codename;
		for(my $i=0; $i < scalar(@name_arr); $i++){
			if($name_arr[$i] eq "release"){
				$version = $name_arr[$i+1];
				next;
			} elsif ($name_arr[$i] =~ "[\(]"){
				$codename = $name_arr[$i];
				next;
			}
		}
	} elsif ($input =~ "Slackware"){
		$name = "Slackware";
		$pretty_name = $input;
		$version = $name_arr[1];
		$id = "slackware";
	} elsif ($input =~ "Ubuntu"){
		$name = "Ubuntu";
		$pretty_name = $input;
		$id = "ubuntu";

		if($name_arr[1] ne ""){
			$version = $name_arr[1];
		}
		my @x = split("[.]", $version);
		if(@x > 2){
			$version_minor = $x[@x-1]; # Last element
		}
	} elsif ($input =~ "CentOS Linux release"){
		$name = "CentOS Linux";
		$pretty_name = $input;

		if($name_arr[2]){
			$version = $name_arr[3];
		}
	} elsif ($input =~ "CentOS"){
		$name = "CentOS Linux";
		$pretty_name = $input;
		$id = "centos";

		if($name_arr[2]){
			$version = $name_arr[2];
		}
	} elsif ($input =~ "Debian"){
		$name = "Debian";
		$id = "debian";
		$pretty_name = $input;
		$version = $name_arr[2];
	} elsif ($input =~ "SuSE Linux"){
		$name = "SuSE Linux";
		$id = "suse";
		$pretty_name = $input;

		$version = $name_arr[2];
	} elsif ($input =~ "SuSE SLES"){
		$id = "sles";
		$name = "SUSE Linux Enterprise Server";
		$pretty_name = $input;

		my @pv = split("-", $name_arr[1]);
		$version = $pv[1];
	} elsif ($input =~ "AIX"){
		$id = "aix";
		$name = "AIX";
		$pretty_name = $input;
		$version = $name_arr[1];
	} elsif ($input =~ "SUSE Linux Enterprise"){
		$id = "suse";
		my ($pl_null, $pl) = split("Patchlevel: ", $input);

		$name = "SUSE Linux Enterprise Server";
		$pretty_name = $input;

		if($pl){
			$name = "$name $name_arr[4].$pl";
		} else {
			$name = "$name $name_arr[4]";
		}
		if($pl){
			$version = "$name_arr[4].$pl";
		} else {
			$version = $name_arr[4];
		}
		my @x = split("[.]", $version);
		$version_minor = $x[@x-1]; # Last element
	} elsif ($input =~ "openSUSE"){
		$id = "opensuse";
		$name = "openSuSE";
		$pretty_name = $input;
		$version = $name_arr[1];
	} elsif($input =~ "Linux Mint"){
		$id = "mint";
		$name = "Linux Mint";
		$pretty_name = $input;
		$version = $name_arr[2];
	} else {
		$id = "unknown";
		$name = "Unknown";
		$pretty_name = $input;
		$version = "na";
	}

	return ($name, $version, $pretty_name, $version_minor, $id);
}

