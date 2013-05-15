#    Copyright (C) 2008 Tryggvi Farestveit
#
#   This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License along
#    with this program; if not, write to the Free Software Foundation, Inc.,
#    51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
##############################################################################

package SVcore;

use strict;
use IO::Socket;
use FileHandle;
use POSIX;

my $VERSION = "0.2.4";

sub new {
	my($class, %args) = @_;
	my $self = bless({}, $class);
	if(!$args{logfile}){
		$args{logfile} = "";
	}

	if(!$args{debug}){
		$args{debug} = 0;
	}

	if(!$args{noconnect}){
		$args{noconnect} = "";
	}

	if(!$args{local_db}){
		printlog($self, "Unable to start, missing local db path");
		print "Local DB path missing\n";
		exit;
	}

	$self->{logfile} = $args{logfile};
	$self->{debug} = $args{debug};
	$self->{noconnect} = $args{noconnect};
	$self->{local_db} = $args{local_db};

	return $self;
}

# seekstr
#	Searches local database
#	Input: 
#		var = Variable name
#		file = Full path filename of the db (ex: /var/lib/sysvik/local.db)
sub seekstr($$){
	my($self, $var) = @_;

	my $file = $self->{local_db};

	if(!-e $file){
		$self->printlog("Unable to open $file");
	} else {
		my $ret = "";
		open(DATA, $file);
			while(<DATA>){
				chomp($_);
				my @arr = split(";;", $_, 2);

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
	my($self, $var) = @_;
	my $file = $self->{local_db};

	my $used=0;
	my $i;
	my @data;
	my @new_data;
	if(-e $file){
		open(DATA, $file);
		@data = <DATA>;
		close(DATA);

		my @data_row;
		my $x=0;
		for($i=0; $i < scalar(@data); $i++){
			chomp($data[$i]);
			@data_row = split(";;", $data[$i], 2);
			if($data_row[0] ne $var){
				$new_data[$x] = $data[$i];
				$x++;
			}
		}
	} 

	# Write to the file
	open(DATA, ">$file");
		for(my $i=0; $i < scalar(@new_data); $i++){
			print DATA "$new_data[$i]\n";
		}
	close(DATA);
}
# putstr
#	Updates/Inserts to local database
sub putstr($$$){
	my($self, $var, $val) = @_;

	my $file = $self->{local_db};

	my $used=0;
	my $i;
	my @data;
	if(-e $file){
		open(DATA, $file);
		@data = <DATA>;
		close(DATA);

		my @data_row;
		for($i=0; $i < scalar(@data); $i++){
			chomp($data[$i]);
			@data_row = split(";;", $data[$i], 2);
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
		# The data was not found, insert it
		$data[$i] = "$var;;$val";
		$i++;
	}

	# Write to the file
	open(DATA, ">$file");
		for(my $i=0; $i < scalar(@data); $i++){
			print DATA "$data[$i]\n";
		}
	close(DATA);

	if($used eq 0){
		chmod 0600, $file;
	}
}

# node_login()
#	Login the node
sub node_login($$$$$$){
	my($self, $basekey, $hostkey1, $hostkey2, $agent, $agent_version, $proto_version) = @_;

	$hostkey1 = tkenc($self, $hostkey1, $basekey);
	$hostkey2 = tkenc($self, $hostkey2, $basekey);

	my $resp = socket_send($self, "node_login $hostkey1;;$hostkey2;;$agent;;$agent_version;;$proto_version");
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
	my $resp = socket_send($self, "quit");
	my $socket = $self->{socket};

	my $noconnect = $self->{noconnect};

	if(!$noconnect){
		close($socket);
	}
}

# sysvik_connect()
#	Connecting to the sysvik network
sub sysvik_connect($$$$){
	my($self, $servername, $port, $proto_version) = @_;


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
	$resp = unpack 'u', $resp;
	chomp($resp);

	my $basekey;
	if($resp =~ 101){
		my @wlch = split(" ", $resp);
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
	return ($socket, $basekey);
}

# tkdec()
#       Key based decryption (serial 2008050101)
sub tkdec($$$){
        my($self, $basekey, $input) = @_;

        # de-scramble the input
        my $dec1;
        ($dec1=$input)=~tr/Q-ZA-Pq-za-p/A-Za-z/;
        my $dec2 = unpack 'u', $dec1;

        my $strl = length($dec2);
        my $keyl = length($basekey);

        my $x;
        my @chunk_arr;
        my $i=0;
        while($strl > 0){
                $chunk_arr[$i] = substr($dec2, $x, $keyl);
                $x = $x+$keyl;
                $strl= $strl - $keyl;
                $i++;
        }

        my $output = "";
        for(my $i=0; $i < scalar(@chunk_arr); $i++){
                my $line = $chunk_arr[$i];
                my @arr;
                for(my $z=0; $z < length($basekey); $z++){
                        my $s = substr($basekey, $z, 1);
                        my $t = substr($line, $z, 1);
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
        my($self, $input, $basekey) = @_;
	my $strl = length($input);

	my $keyl = length($basekey);
	if($keyl ne 10){
	        printlog($self, "Unable to encrypt $basekey ($keyl - $input)");
		exit;
	}

	$input =~ s/[ ]/;TkF;/g; # Replace space with ;TkF;

        my $i=0;
        my $x=0;
        my @chunk_arr;
        while($strl > 0){
                $chunk_arr[$i] = substr($input, $x, $keyl);
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
                        my $s = substr($basekey, $z, 1);
                        my $t = substr($line, $s, 1);

                        if($t eq ""){
                                $t = " ";
                        }
                        $chunk = "$chunk$t";
                }
                $output = "$output$chunk";
        }

	# scramble the output
        my $ec1 = pack 'u', $output;
        my $ec2;
        ($ec2=$ec1)=~tr/A-Za-z/Q-ZA-Pq-za-p/;

	chomp($ec2);
        return $ec2;
}

# get_hostkey()
#	Returns hostkey if available
sub get_hostkey($$){
	my($self, $nodefile) = @_;
	open(NODEFILE, $nodefile);
	my $i=0;

	my ($hostkey1, $hostkey2);
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
        $hostkey1 = unpack 'u', $hostkey1;
        $hostkey2 = unpack 'u', $hostkey2;

	return ($hostkey1, $hostkey2);
}

# lock_on
#	Lock management: Lock on
sub lock_on($$) {
	my ($self, $lock) = @_;

	if (-e $lock){
		printlog($self, "Lock exist ($lock): Validating");
	        open(LOCK, $lock);
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
			printlog($self,"Lock exist ($lock): Old lock, removing");
			unlink($lock) || die "Unable to remove $lock";
		} else {
			# Lets look into the running process
			open(CMD, "/proc/$oldPID/cmdline");
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
					printlog($self, "Killing process $oldPID. ($cmdline). Age: $mod_diff secs");
					kill 9, $oldPID;
				} else {
					# Process is under 1 hour old
					exit;
				}
			} else {
				# This is probably not our process. Remove lock and continue running
				printlog($self, "Runnning process $oldPID ($cmdline) not ours. Removing lock");
				unlink($lock) || die "Unable to remove $lock";
			}
		}
	}

	my $pid = $$; # Get current pid
	# Let's create a lock
	open(LOCK, ">$lock") || die "Unable to create $lock";
	        print LOCK "$pid\n";
	close(LOCK);
}

# lock_off
#	Lock management: Lock off
sub lock_off($$){
	my ($self, $lock) = @_;
        # Let's remove the lock
	if(-e $lock){
	        unlink($lock) || die "Unable to remove $lock";
	}
}

# printlog()
#       prints out to a logfile or screen if in debug mode
#tkf
sub printlog($$){
        my ($self, $text) = @_;

	my @months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
	my @weekDays = qw(Sun Mon Tue Wed Thu Fri Sat Sun);
	my ($sec, $min, $hour, $day, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();

	my $year = 1900 + $yearOffset;
#        my $now = time();
	my $debug = $self->{debug};
	my $logfile = $self->{logfile};
        if($debug){
                print "$text\n";
        } elsif ($logfile){
                open (LOG, ">>$logfile");
		printf LOG "%4d-%02d-%02d %02d:%02d:%02d %s\n", $year,$month+1,$day,$hour,$min,$sec, $text;
#                print LOG "$now $text\n";
                close(LOG);
        }

}

# socket_send()
#       Communications with the server
sub socket_send($$){
        my ($self, $input) = @_;
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

	open(U, "$uname|");
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
