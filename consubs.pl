$version_key = "HTTPi/1.7/$DEF_CONF_TYPE";
$my_version_key = 0;
$ACTUAL_VERSION = "1.7 (C)1998-2010 Cameron Kaiser/Contributors";

print STDOUT "HTTPi/$ACTUAL_VERSION\n";
print STDOUT "Pre-flight check in progress ...\n\n";

#require "./Mpp.pm"; # use fails -T
#$parser = new Mpp;

# detaint our path. this is slightly risky, but we assume you know what
# you're doing.
$nupath = &detaint($ENV{'PATH'});
if ($nupath =~ /(^|:)\./) {
	1 while ($nupath =~ s#(^|:)[^/][^:]*##);
	1 while ($nupath =~ s#:[^/][^:]+$##);
	&prompt(<<"EOF", "");
*** WARNING: Portions of your PATH have relative paths in them ***
This is considered potentially unsafe by the installer, and these paths have
been removed temporarily during this run of the configure script.

Your path WAS:
	$ENV{'PATH'}

Your path now TEMPORARILY IS:
	$nupath

If you require these paths to find tools, press CONTROL-C now and fix your
PATH, then re-run this configure script.

Otherwise, press RETURN or ENTER to continue.
EOF
}	
$ENV{'PATH'} = $nupath;

sub detaint { # sigh
	my ($w) = (@_);
	($w =~ m#([^\\|><]+)#) && (return $1);
}

sub yncheck {
	local ($prompt, $evals, $fatal) = (@_);
	local $setv;

	print STDOUT "$prompt ... ";
	eval $evals;
	if (!$@) {
		print "yes\n"; $setv = 1;
	} else {
		chomp($q = $@);
		print "no ($q)\n"; $setv = 0;
		(print($fatal), exit) if ($fatal);
	}
	return $setv;
}

sub wherecheck {
	local ($prompt, $filename, $fatal) = (@_);
	local(@paths) = split(/\:/, $ENV{'PATH'});
	unshift(@paths, '/usr/bin'); # the usual place
	@paths = ('') if ($filename =~ m#^/#); # for absolute paths
	local $setv = 0;

	print STDOUT "$prompt ... ";
	foreach(@paths) {
		$setv = "$_/$filename";
		1 while $setv =~ s#//#/#;
		if (-r $setv) {
			print "$setv\n";
			last;
		}
	}
	if (!$setv) {
		print "not found.\n";
		(print($fatal),exit) if ($fatal);
	}
	return $setv;
}

sub preproc {
	local ($mf) = (@_);
	local $kvbuf, $ifl;

	$ifl = 0;
	while(<$mf>) {
		chomp;
		if (/^~$/ || /^~\s*#/) { # ignore trailing comments
			next if (!$ifl);
			$ifl = abs($ifl);
			$ifl--;
			next;
		}
		next if ($ifl > 0);
		if (/^~(if|check)/) {
			(/^~(if|check) (.+)$/) && ($def = $2);
			@ldefs = split(/,\s*/, $def);
			$j=0;
			foreach $def (@ldefs) {
				eval "\$j += \$DEF_$def;";
			}
			if ($j == scalar(@ldefs)) {
				$ifl = -2;
			} else {
				$ifl = 1;
			}
			next;
		}
		if (/^~insert/) {
			(/^~insert (.+)$/) && ($def = $1);
			open(Q, $def) || (print(STDOUT <<"EOF"), exit);

COMPILATION FAILURE: Could not include file $def.
($@ $!)

EOF
			$kvbuf .= &preproc(\*Q);
			close(Q);
			next;
		}
		while((/(DEF_[A-Z_]+)/) && ($def = $1)) {
			eval "s/DEF_[A-Z_]+/\$$def/";
		}
		$kvbuf .= "$_\n";
	}
	return $kvbuf;
}

sub prompt {
	local($prompt, $default, $dontcare) = (@_);
	local $entry;

	if (!$DEFAULT) {
		chomp $prompt;
		print STDOUT "$prompt [$default]: ";
		chomp($entry = <STDIN>);
		$entry = (length($entry) ? $entry : $default);
	} else {
		return if (!$dontcare);
		$entry = $default if ($DEFAULT == 1);
		$entry = shift(@answers) if ($DEFAULT == 2);
	}
	print <<"EOF" unless ($entry eq '');

$entry selected.

EOF
	printf(L "%s\n", $entry) if ($dontcare && !$DEFAULT);
	return $entry;
}			

sub inter_homedir {
	# based on an idea by Mark Olesen
	my $w = &detaint(shift);
	my $x = $w;
	$x =~ s#^~/#\$ENV{'HOME'}/#; # so that interpolation occurs
	my $w = '';
	eval qq{ \$w = "$x"; };
	return ($w, $@);
}

sub interprompt {
	my($prompt, $default, $dontcare, $interpolator) = (@_);

	while(1) {
		my $k = &prompt($prompt, $default, $dontcare);
		my ($l, $err) = &$interpolator($k);
		if (length($l)) {
			print "(expanded to $l)\n\n" if ($l ne $k);
			return $l;
		} else {
			print "Your expression made no sense: $@";
			print "Try again, with feeling.\n\n";
		}
	}
	die("not reached\n");
}

if ($ARGV[0] =~ /^--?d/) {
	print <<"EOF";
** DEFAULT MODE ENABLED ** -- $0 will autoconfigure everything!
(Installation questions relevant to config files will not be asked, if any.)
HIT CTRL-C NOW IF THIS IS NOT WHAT YOU WANT!

EOF
	sleep 2;
	$DEFAULT = 1;
	if (length($ARGV[1]) && -e $ARGV[1]) {
		open(P, "$ARGV[1]");
		while(<P>) {
			chomp;
			if (!$my_version_key) {
				$my_version_key = $_;
				if ($my_version_key ne $version_key) {
					$my_version_key =
						"0.99 or earlier"
						if ($my_version_key !~
							/^HTTPi/);
					print <<"EOF";
Whoops, screeching halt time, bud.

This is a transcript file from an incompatible or earlier HTTPi configure
sequence (looks like version $my_version_key).

Since the question sequence and possible choices have changed, the responses
you gave in this transcript file are no longer valid. Please start over and
run $0 from scratch. Sorry!

EOF
					exit;
				}
				next;
			}
			push(@answers, $_);
		}
		close(P);
		print "Loaded responses from $ARGV[1].\n\n";
		$DEFAULT = 2;
	} elsif (length($ARGV[1])) {
		print <<"EOF";
Can't load transcript file $ARGV[1]! ("$!")
Check your permissions or your typing.
EOF
		exit;
	}
}

unless ($DEFAULT) {
	($0 =~ m#/?([^/]+)$#) && ($f = $1);
	$p=0; while(-e "transcript.$p.$f") { $p++; }
	open(L, ">transcript.$p.$f") || (print(<<"EOF"), exit);

Can't open transcript file transcript.$p.$f for write.
(Error was $!)
Check your permissions on that file or directory.

EOF
	select(L); $|++; select(STDOUT);
	print L "$version_key\n";
}

sub firstchecks {
	$DEF_UNAME = &wherecheck("Finding uname", "uname");
	if ($DEF_UNAME) {
		chomp($DEF_ARCH = `$DEF_UNAME -s`);
		print "Smells like $DEF_ARCH.\n";
	} else {
		print
	"Hmm. This might not be a Unix box, but we'll keep trying.\n";
		$DEF_ARCH = "???";
	}
	$HOSTNAME = &wherecheck('Finding hostname', 'hostname');

	$didnt_work = 1;
	PERLCHEK: while($didnt_work) {
		$DEF_PERL = &wherecheck("Finding your perl", "perl", <<"EOF");

Good grief, you've managed to run this with Perl not in your path. Where
the heck is it, anyway? Put Perl in your path and rerun.

EOF
		$DEF_PERL = &prompt(<<"EOF", $DEF_PERL, 1);
If you want to use this Perl to execute HTTPi, just hit RETURN/ENTER. However,
if you have another Perl executable you want to use instead, then enter it
here; it will be probed and then put in HTTPi's #! line.
... 
EOF
		print "Checking out your Perl ...\n";
		$DEF_PERL = &detaint($DEF_PERL);
		$test_script = 'print"$] ";eval"use POSIX ()";print"$@"';
		if(!open(Q, "$DEF_PERL -e '$test_script'|")) {
			print "Failed to execute $DEF_PERL ... $!\n";
			print "Let's try that again.\n\n";
			next PERLCHEK;
		}
		chomp($x = scalar(<Q>));
		close(Q);
		if (!length($x)) {
			print <<"EOF";
I didn't get any response at all. Are you sure you specified the right file?
Try again.

EOF
			next PERLCHEK;
		}
		($PERL_VERSION, $pox) = split(/\s+/, $x, 2);
		$HAS_POSIX = (length($pox) < 1);
		("$PERL_VERSION" =~ /^(\d+)\.(\d\d\d)(\d+)/) &&
			(($major, $minor, $patch) = ($1, $2, $3));
		$PERL_VERSION += 0;
		if ($PERL_VERSION < 4) {
			print <<"EOF";
The version response that program gives me doesn't make sense, or you're using
a really wacky (ancient?) Perl. Try again.

EOF
			next PERLCHEK;
		}
		if ($PERL_VERSION < 5) {
			print <<"EOF";
Hmm, $PERL_VERSION.
An oldie but not necessarily goodie -- you may need to build a new Perl
to run HTTPi. Still, let's see how far we get, yes?
EOF
		} else {
			$major += 0;
			$minor += 0;
			$PERL_MVERSION = ($major < 6 && $minor < 6) ?
				"${major}.00${minor}" : "${major}.${minor}";
			$patch += 0;
			$PERL_MVERSION .= ($major < 6 && $minor < 6) ?
				(($patch < 10) ? "0${patch}" : "${patch}") :
				".${patch}";
			print "$PERL_MVERSION ... ";
			if ($PERL_VERSION < 5.005) {
				print
"by now, this vintage is vinegar!\n" .
"WARNING: Jokes aside, the oldest Perl I still officially support is 5.005.\n";
			} elsif ($PERL_VERSION < 5.006) {
				print "that was a good year.\n";
			} elsif ($PERL_VERSION < 5.010) {
				print "has this wine been corked?\n";
			} else {
			print
		"obviously not a connoisseur, this wine's barely aged.\n"
			}
		}
		if ($HAS_POSIX) {
			print "Your Perl does have a POSIX.pm.\n";
			print "It is, however, the older unsuitable one.\n"
				if ($PERL_VERSION < 5.008);
		} else {
			print <<"EOF";
Just a warning; I can't use POSIX.pm with this Perl ($pox).
We'll use \$SIG-based signaling instead, though this may be less reliable.
EOF
		}
		$didnt_work = 0;
	}
}

print STDOUT "\nOk, starting the configure system.\n\n";

1;

