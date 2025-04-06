#!/usr/bin/perl

# echo "R' F' R U2 R U2 R' F R U2 R' F'" | z:\algo_filter.pl -F1-=3 -debug -R2+=0

use Data::Dumper;

my $debug = 0;
my $verbose = 0;
my $collapse = 0;
my $show_no_move_lines = 0;
my $case_sensitive = 0;
my $show_ewes = 0;
my $info_lines = "These";	# pipe separated match
my $or_logic = 0;
my $and_logic = 1;
my %letter_limits = ();
my $letter_limits_ignore_xyz = 0;

parse_cli();
get_data();
print_stuff();
exit;

################################################################################
sub print_stuff {
	my $line;
	my @tmp;
	my %tmp;
	
	print Dumper(\%criteria) if ($debug);

	foreach $line (@input) {
		$line =~ s/\"//g;
		$line =~ s/\s+U[\'\d]*\s*$// if (!$show_ewes);
		$line_tmp = $line;
		print "------------------------------------\nLine: $line\n" if ($debug);

		$line_tmp =~ s/\'|2//g if ($collapse);

		$line_tmp =~ s/^\s+//;
		$line_tmp =~ s/\s+$//;
		$line_tmp =~ s/\s\s+/ /g;
		$line_tmp =~ s/\'/1/g;

		next if (letter_limit_chk($line_tmp) == 0);		# 1 = show, 0 = skip
		if ($line =~ /$info_lines/) {
			print "$line\n";
			next;
		}

		@tmp = split(/\s+/, $line_tmp);
		%tmp = ();
		foreach (@tmp) {
			$tmp{$_}++;
		}
		
		$show = 1;
		$show = 0 if ($or_logic);
		foreach $crit (sort keys %criteria) {
			last if (!$show && $and_logic);

			# if the line doesn't have any of the moves, but the user wants to see those, show them.
			if ($show_no_move_lines) {
				if (!defined($tmp{$crit})) {
					next;
				}
			}
			
			$result = check_move($crit, \%tmp);
			if ($or_logic && $result) {
				$show = 1;
				last;
			} elsif ($and_logic && !$result) {
				$show = 0;
				last;
			}
		}

		if ($show) {
			if ($verbose) {
				print "\n";
				foreach (sort keys %tmp) {
					$x = $_;
					$x =~ s/1/\'/g;
					printf("%-3s %2d\n", $x, $tmp{$_});
				}
			}

			print "$line\n";
		}
	}
}

################################################################################
sub get_data {
	while (<STDIN>) {
		chomp;
		push(@input, $_);
	}
}

################################################################################
sub check_move {
	my $move = $_[0];
	my $tmp  = $_[1];
	my $show = 1;

	print Dumper($tmp) if ($debug);

	# handle the move criteria
	foreach $opt (sort keys %{$criteria{$move}}) {
		print "Working on $move $opt\n" if ($debug);
		if ($opt eq "=") {
			if ($criteria{$move}{$opt} == 0 && !defined($$tmp{$move})) {
			} elsif (!defined($$tmp{$move}) || $$tmp{$move} != $criteria{$move}{$opt}) {
				$show = 0;
			}
		} elsif ($opt eq "+=") {
			if ($criteria{$move}{$opt} == 0 && !defined($$tmp{$move})) {
			} elsif (!defined($$tmp{$move}) || $$tmp{$move} < $criteria{$move}{$opt}) {
				$show = 0;
			}
		} elsif ($opt eq "+") {
			if ($criteria{$move}{$opt} == 0 && !defined($$tmp{$move})) {
				$show = 0;
			} elsif (!defined($$tmp{$move}) || $$tmp{$move} <= $criteria{$move}{$opt}) {
				$show = 0;
			}
		} elsif ($opt eq "-=") {
			if (!defined($$tmp{$move})) {
			} elsif (!defined($$tmp{$move}) || $$tmp{$move} > $criteria{$move}{$opt}) {
				$show = 0;
			}
		} elsif ($opt eq "-") {
			if (!defined($$tmp{$move})) {
			} elsif (!defined($$tmp{$move}) || $$tmp{$move} >= $criteria{$move}{$opt}) {
				$show = 0;
			}
		} else {
			die "ERROR: Unknown option $crit $opt\n";
		}
		
		last if ($show == 0);
	}

	print "Move $move, show $show\n" if ($debug);
	return($show);
}

################################################################################
# Return 1 if show, 0 to skip it
sub letter_limit_chk {
	return(1) if (!scalar(keys %letter_limits));

	my $line = $_[0];
	my @tmp = split(/\s+/, $line);
	my %tmp = ();

	foreach (@tmp) {
		s/[12]//g;					# collapse primes/2's down to the primary letter
		s/([a-z])/uc($1)/gei if (!$case_sensitive);		# make all uppercase
		s/(?: [xyz])+$//i if ($letter_limits_ignore_xyz);		# ignore x,y,z at the end of the line if they want to ignore those

		$tmp{$_}++;
	}

	return( match_chk(scalar(keys %tmp), \%letter_limits) );
}

################################################################################
sub match_chk {
	my $count = $_[0];
	my $hash  = $_[1];
	my $show = 1;

	print "Working on a math operation check, for count: $count\n" if ($debug);
	print Dumper($hash) if ($debug);

	foreach $opt (sort keys %$hash) {
		print "Working on math operation comparison: $opt\n" if ($debug);
		if ($opt eq "=") {
			if ($count != $$hash{$opt}) {
				$show = 0;
			}
		} elsif ($opt eq "+=") {
			if ($count < $$hash{$opt}) {
				$show = 0;
			}
		} elsif ($opt eq "+") {
			if ($count <= $$hash{$opt}) {
				$show = 0;
			}
		} elsif ($opt eq "-=") {
			if ($count > $$hash{$opt}) {
				$show = 0;
			}
		} elsif ($opt eq "-") {
			if ($count >= $$hash{$opt}) {
				$show = 0;
			}
		} else {
			die "ERROR: Unknown math operation comparison option $opt\n";
		}

		last if ($show == 0);
	}

	print "Math operation comparison: show $show\n" if ($debug);
	return($show);
}

################################################################################
sub parse_cli {
	my $i = 0;
	while ($i < scalar(@ARGV)) {
		if ($ARGV[$i] =~ /^-+m([+=-]+)(\d+)$/) {		# -m=3 (show algs with 3 letters)
			$letter_limits{$1} = $2;
		} elsif ($ARGV[$i] =~ /^-+([\w,]+)([+=-]+)(\d+)$/) {		# -F1=2 (two F' moves, 1=')
			my $keys = $1;
			my $oper = $2;
			my $val  = $3;
			foreach $key (split(/,/, $keys)) {
				$criteria{$key}{$oper} = $val;
			}
		} elsif ($ARGV[$i] =~ /^-+p$/) {
			$collapse = 1;
		} elsif ($ARGV[$i] =~ /^-+s$/) {
			$show_no_move_lines = 1;
		} elsif ($ARGV[$i] =~ /^-+g$/) {
			$case_sensitive = 1;
		} elsif ($ARGV[$i] =~ /^-+u$/) {
			$show_ewes = 1;
		} elsif ($ARGV[$i] =~ /^-+mx$/) {
			$letter_limits_ignore_xyz = 1;
		} elsif ($ARGV[$i] =~ /^-+o$/) {
			$or_logic = 1;
			$and_logic = 0;
		} elsif ($ARGV[$i] =~ /^-+v$/) {
			$verbose = 1;
		} elsif ($ARGV[$i] =~ /^-+(h|help)$/) {
			show_help();
		} elsif ($ARGV[$i] =~ /^-+debug$/) {
			$debug++;
		} else {
			print "Unrecognized option: $ARGV[$i]\n";
		}
		$i++;
	}
}


################################################################################
sub show_help {
	print <<HELP;
$0: Nathans cool tool.

Options:
  -F=#		Specify how many moves.  Supported math operations: = -= += - +
  -F1=#		Specify how many prime moves.
  -g		For -F=, -s, -u, -m=, default is to make move case insensitive. This makes it case sensitive.
  -p		Collapse all moves, prime moves, and double moves into their single move type.
  -s		Show lines that dont have any moves from the move criteria.
  -o		Convert the criteria logic to 'or' logic instead of 'and' logic.
  -u		Show U moves at the end of the line (rather than removing them)
  -m=#		Show algs with # letters in it. Supported math operations: = -= += - +
  -mx		Ignore X, Y, and Z when doing the -m filtering.

Examples:
  cmd | $0 -F=3 -R1=2
HELP
	exit;
}
__END__



What i want to find: 1 F and 1 F’ move in the line and it doesn't matter which order

R' F' R U2 R U2 R' F R U2 R'
F R' F' R U R U' R'
R' F R2 U R' U' R U R' U' F'

-------------------------------

What i want to find: Only 2 Y moves max but they can be a y,y’,y2

F y2 r' U r y
F' y2 r' U' r y

-------------------------------

What i want to find: exclude not just 1 move but all of the options of that move

Example: to exclude a move in grep you would do |grep -v F2 but I would like a way to say exclude the all F move powers which are F,F’,F2

-------------------------------

What i want to find: say I want to only include algs with 2 F move powers but to also include algs that do not have an F in them

R' F' R U2 R U2 R' F R U2 R'
R U R' U R U2 R'
U' R' U2 R U R' U R
R U R' U R U2 R' U
R' F R2 U R' U' R U R' U' F'
R U R' U R U2 R' U2
R' F R2 U R' F2 U' R U R' F’

-------------------------------

'or' sets
What i want to find: 1 F and 1 F’ move in the line and it does not matter which order but also to include other moves like 1 L and 1 L’ in the list but not in the same alg

R' F' R U2 R U2 R' F R U2 R'
F R' F' R U R U' R'
R' F R2 U R' U' R U R' U' F'
R U R' U R U2 R'
R U' L' U R' U' L
U' R' U2 R U R' U R
R U R' U R U2 R'
U2 L U' R' U L' U' R




===========================================

which generates these kinds of algs that have 5 powers in them (R,U,F,L,D)
L F D R F D' L' F' U' F'
L D F R F D' F' L' U' F'
L F D U' R' U R D' F' L'
L R F' R D R' D' F L' R'

What I want is to have a switch to say "use only 3 of those powers in any single line" which would show this.
-m=3  (to say only show me algs with at most 3

F R2 U2 R F R' F' U2 R2 F'
F R F' R U F' U' F U' R'
R U2 F R F' R' U' R U' R'

U R D R2 U' R U R2 D' R2
R2 D R' U' R D' U R U' R2
R U R' D R2 U' R U R2 D'

R' U2 L' U2 R U2 R' U2 L R
R' U' L' U R U' L R' U R

