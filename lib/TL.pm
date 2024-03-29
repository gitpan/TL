# -----------------------------------------------------------------------------
# TL - Tripletailメインクラス
# -----------------------------------------------------------------------------
package TL;
use strict;
use warnings;
use UNIVERSAL qw(isa);

our $VERSION = '0.10_07';

our $TL = TL->__new;
our @specialization = ();
our $LOG_SERIAL = 0;

require Unicode::Japanese;

if($ENV{TL_COVER_TEST_MODE}) {
	require Devel::Cover;
	Devel::Cover->import(qw(-silent on -summary off -db ./cover_db -coverage statement branch condition path subroutine time +ignore ^/));
}

1;

# -----------------------------------------------------------------------------
# ロード時初期化
# -----------------------------------------------------------------------------
sub import {
	my $package = shift;
	my $callpkg1 = (caller(0))[0];
	local($SIG{__WARN__}) = sub { warn "warn-import: $_[0]\n" };
	no strict qw(refs);
	*{"$callpkg1\::TL"} = *{"TL\::TL"};

	if(!$TL->{INI}) {
		my $inifile = shift;
		if(!defined($inifile)) {
			_inside_pod_coverage()
				or die "use TL, ARG[1]: not defined. Usage: \"use TL qw(config.ini);\"\n";
			$inifile = '/dev/null';
		}
		$TL->{INI} = $TL->newIni($inifile);
		$TL->{INI}->const;
		
		if(defined($_[0])) {
			@specialization = @_;
		}

		my $trap = $TL->{INI}->get(TL => 'trap', 'die');
		if($trap ne 'none' && $trap ne 'die' && $trap ne 'diewithprint') {
			die __PACKAGE__."#startCgi, invalid trap option [$trap].\n";
		}


		$TL->{trap} = $trap;

		if($trap eq 'die') {
			$SIG{__DIE__} = sub {
				# スタックトレースを付け加えて再度dieする。
				# それ以外の事はしない。
				my $msg = shift;

				die isa($msg, 'TL::Error') ? $msg : $TL->newError(error => $msg);
			};
		} elsif($trap eq 'diewithprint') {
			$SIG{__DIE__} = sub {
				# エラーをヘッダと共に表示して再度dieする。
				my $msg = shift;

				if (isa($msg, 'TL::Error')) {
					die $msg;
				}
				
				my $err = $TL->newError(error => $msg);
				
				print "Content-Type: text/plain\n\n$err";
				
				die $err;
			};
		}
		*{"$callpkg1\::CGI"} = _gensym(); # dummy to avoid strict.
	} else {
		if(defined($_[0])) {
			die "use TL, ARG[1]: ini file already loaded.";
		}
	}
}

# -----------------------------------------------------------------------------
# Pod::Coverage内からロードされているかの判定.
#  (Test::Pod::Cover用)
# -----------------------------------------------------------------------------
sub _inside_pod_coverage
{
	$INC{"Pod/Coverage.pm"} or return; # false.
	my $i = 0;
	my $in_pod_coverage = 0;
	while(my $pkg = caller(++$i))
	{
		$pkg eq 'Pod::Coverage' and return 1;
	}
	return; # false.
}

# -----------------------------------------------------------------------------
# 生成
# -----------------------------------------------------------------------------
sub __new {
	my $pkg = shift;
	my $this = bless {} => $pkg;

	$this->{INI} = undef; # TL::Ini
	$this->{CGI} = undef; # TL::Form。preRequest直前に生成され、postRequest後に消される。
	$this->{CGIORIG} = undef; # TL::Form。preRequest直前に生成され、postRequest後に消される。

	$this->{trap} = 'die'; # 'none' | 'die' | 'diewithprint'

	$this->{filter} = {}; # 優先順位 => TL::Filter
	$this->{filterlist} = []; # [TL::Filter, ...] 優先順位でソート済み

	$this->{saved_filter} = {}; # $this->{filter} のコピー

	$this->{inputfilter} = {}; # 優先順位 => TL::InputFilter
	$this->{inputfilterlist} = []; # [TL::InputFilter, ...] 優先順位でソート済み

	$this->{hook} = {
		init        => {}, # 優先順位 => CODE
		term        => {},
		preRequest  => {},
		postRequest => {},
	};
	$this->{hooklist} = {
		init        => [], # [CODE, ...] 優先順位でソート済み
		term        => [],
		preRequest  => [],
		postRequest => [],
	};

	$this->{encode_is_available} = undef; # undef: 不明  0: Encode利用不可  1: Encode利用可

	$this;
}

sub DESTROY {
	my $this = shift;
	$SIG{__DIE__} = 'DEFAULT';
	if(exists($this->{cacheLogFh})) {
		close($this->{cacheLogFh});
	}
}

sub CGI {
	my $this = shift;
	$this->{CGI};
}

sub INI {
	my $this = shift;
	$this->{INI};
}

sub escapeTag {
	my $this = shift;
	my $str = shift;

	if(!defined($str)) {
		die "TL#escapeTag, ARG[1]: got undef.\n";
	}

	$str =~ s/\&/\&amp;/g;
	$str =~ s/</\&lt;/g;
	$str =~ s/>/\&gt;/g;
	$str =~ s/\"/\&quot;/g;
	$str =~ s/\'/\&#39;/g;

	$str;
}

sub unescapeTag {
	my $this = shift;
	my $str = shift;

	if(!defined($str)) {
		die "TL#unescapeTag, ARG[1]: got undef.\n";
	}

	$str =~ s/\&lt;/</g;
	$str =~ s/\&gt;/>/g;
	$str =~ s/\&quot;/\"/g;
	$str =~ s/\&apos;/\'/g;
	$str =~ s!(\&(?:(amp)|#(\d+)|#x([0-9a-fA-F]+));)!
		if( $2 ) {
			'&';
		} elsif ( defined($3) && $3 ne '' ) {
			$3>=0x20 && $3<=0x7e ? pack("C",$3) : $1;
		} else { 
			hex($4)>=0x20 && hex($4)<=0x7e ? pack("C",hex($4)) : $1;
		}!ge;

	$str;
}

sub escapeJs {
	my $this = shift;
	my $str = shift;

	if(!defined($str)) {
		die "TL#escapeJs, ARG[1]: got undef.\n";
	}

	$str =~ s/(['"\\])/\\$1/g;
	$str =~ s/\r/\\r/g;
	$str =~ s/\n/\\n/g;

	$str;
}

sub unescapeJs {
	my $this = shift;
	my $str = shift;

	if(!defined($str)) {
		die "TL#unescapeJs, ARG[1]: got undef.\n";
	}

	$str =~ s/\\(['"\\])/$1/g;

	$str;
}

sub encodeURL {
	my $this = shift;
	my $str = shift;

	if(!defined($str)) {
		die "TL#encodeURL, ARG[1]: got undef.\n";
	}

	$str =~ s/([^a-zA-Z0-9\-\_\.\!\~\*\'\(\)])/
	'%' . sprintf('%02x', unpack("C", $1))/eg;

	$str;
}

sub decodeURL {
	my $this = shift;
	my $str = shift;

	if(!defined($str)) {
		die "TL#decodeURL, ARG[1]: got undef.\n";
	}

	$str =~ s/\%([a-zA-Z0-9]{2})/pack("C", hex($1))/eg;

	$str;
}

sub escapeSqlLike {
	my $this = shift;
	my $str = shift;

	if(!defined($str)) {
		die "TL#escapeSqlLike, ARG[1]: got undef.\n";
	}

	$str =~ s/\\/\\\\/g;
	$str =~ s/\%/\\\%/g;
	$str =~ s/\_/\\\_/g;

	$str;
}

sub unescapeSqlLike {
	my $this = shift;
	my $str = shift;

	if(!defined($str)) {
		die "TL#unescapeSqlLike, ARG[1]: got undef.\n";
	}

	$str =~ s/\\\%/\%/g;
	$str =~ s/\\\_/\_/g;
	$str =~ s/\\\\/\\/g;

	$str;
}

sub startCgi {
	my $this = shift;
	my $param = { @_ };
	
	$this->{outputbuffering} = $this->INI->get(TL => 'outputbuffering', 0);

	eval {
		# trap = diewithprint の場合はエラーハンドラを付け替える
		# そうしないと Content-Type: text/plain が出力されてしまう。
		if($this->{trap} eq 'diewithprint') {
			$SIG{__DIE__} = sub {
				# スタックトレースを付け加えて再度dieする。
				# それ以外の事はしない。
				my $msg = shift;

				die isa($msg, 'TL::Error') ? $msg : $TL->newError(error => $msg);
			};
		}

		# ここで各種フック類がインストールされる。
		$this->getDebug;

		if(defined(my $group = $param->{-DB})) {
			require TL::DB;

			if(!ref($group)) {
				TL::DB->_connect([$group]);
			} elsif (ref($group) eq 'ARRAY') {
				TL::DB->_connect($group);
			}
		}

		if(defined(my $groups = $param->{-Session})) {
			require TL::Session;

			TL::Session->_init($groups);
		}

		if(!defined($param->{'-main'})) {
			die __PACKAGE__."#startCgi, -main handler was undef.\n";
		}

		# ここでフィルタ類のデフォルトを設定
		if(!$this->getContentFilter) {
			$this->setContentFilter('TL::Filter::HTML');
		}
		if(!$this->getInputFilter) {
			$this->setInputFilter('TL::InputFilter::HTML');
		}

		if($this->_getRunMode eq 'FCGI') {
			# FCGIモードならメモリ監視フックとファイル監視フックをインストール
			$this->getMemorySentinel->__install;
			$this->getFileSentinel->__install;
		}

		$this->__executeHook('init');

		if($this->_getRunMode eq 'FCGI') {
			# FCGIモード

			my $maxrequestcount = $this->INI->get(TL => 'maxrequestcount', 0);
			$this->log(FCGI => 'Starting FCGI Loop... maxrequestcount: ' . $maxrequestcount);
			my $requestcount = 0;

			do {
				local $SIG{__DIE__} = 'DEFAULT';
				eval 'use FCGI';
			};
			if($@) {
				die __PACKAGE__."#startCgi, failed to load FCGI.pm [$@]\n";
			}

			my $exit_requested;
			my $handling_request;
			local $SIG{USR1} = sub {
				$exit_requested = 1;
				die "SIGUSR1 received\n";
			};
			local $SIG{TERM} = sub {
				$exit_requested = 1;
				die "SIGTERM received\n";
			};
			local $SIG{PIPE} = 'IGNORE';

			my $request = FCGI::Request(
				\*STDIN, \*STDOUT, \*STDERR, \%ENV,
				0, FCGI::FAIL_ACCEPT_ON_INTR());

			while(1) {
				my $accepted = eval {
					$request->Accept() >= 0;
				};
				if($@) {
					if($exit_requested) {
						$this->log(FCGI => "FCGI_request->Accept() interrupted : $@");
						last;
					}else {
						$this->log(FCGI => "FCGI_request->Accept() failed : $@");
						exit 1;
					}
				}

				if(!$accepted) {
					last;
				}

				$this->__executeCgi($param->{-main});

				$request->Flush;

				$requestcount++;

				if($exit_requested || ($maxrequestcount && ($requestcount >= $maxrequestcount))) {
					last;
				}
			}
			$request->Finish;

			$this->log(FCGI => 'FCGI Loop terminated.');
		} else {
			# CGIモード
			$this->log(TL => 'CGI mode');

			$this->__executeCgi($param->{-main});
		}

		$this->__executeHook('term');
	};
	if(my $err = $@) {
		if ($this->{trap} eq 'none') {
			die $err;
		}

		if (isa($err, 'TL::Error') and $err->type eq 'error') {
			$err->message(
				"Died outside the `-main':\n" . $err->message);
		}

		$this->_sendErrorIfNeeded($err);

		# このevalでキャッチされたという事は、-mainの外で例外が起きた。
		$this->log(startCgi => "$err");

		# また、FCGIモードでなければエラーをstdoutにprintする意味がある。
		if ($this->_getRunMode ne 'FCGI') {
			$this->__dispError($err);
		}
	}

	$this;
}

sub errorTrap {
	my $this = shift;
	my $param = { @_ };

	eval {
		# trap = diewithprint の場合はエラーハンドラを付け替える
		# そうしないと Content-Type: text/plain が出力されてしまう
		local($SIG{__DIE__});
		if ($this->{trap} eq 'diewithprint'){
			$SIG{__DIE__} = sub {
				# スタックトレースを付け加えて再度dieする。
				# それ以外の事はしない。
				my $msg = shift;

				die isa($msg, 'TL::Error') ? $msg : $TL->newError(error => $msg);
			};
		}
		# TL::Debugをロード。debug機能が有効になっていれば、
		# ここで各種フック類がインストールされる。
		$this->getDebug;

		if(defined(my $group = $param->{-DB})) {
			require TL::DB;

			if(!ref($group)) {
				TL::DB->_connect([$group]);
			} elsif(ref($group) eq 'ARRAY') {
				TL::DB->_connect($group);
			}
		}

		if(!defined($param->{'-main'})) {
			die __PACKAGE__."#errorTrap, -main handler was undef.\n";
		}

		$this->__executeHook('init');
		$this->__executeHook('preRequest');
		$this->_saveContentFilter;

		eval {
			$param->{'-main'}();
		};
		if(my $err = $@) {
			if($this->{trap} eq 'none') {
				die $err;
			}

			$this->_sendErrorIfNeeded($err);
			print STDERR $err;
			
			my $errorlog = $this->INI->get(TL => 'errorlog', 1);
			if($errorlog > 0) {
				$this->log(__PACKAGE__, "$err");
			}
		}

		$this->_restoreContentFilter;
		$this->__executeHook('postRequest');
		$this->__executeHook('term');
	};
	if(my $err = $@) {
		if ($this->{trap} eq 'none'){
			die $err;
		}

		# このevalでキャッチされたという事は、-mainの外で例外が起きた。
		$this->log(errorTrap => "Died outside the `-main': $err");
		print STDERR "Died outside the `-main': $err\n";
	}

	$this;
}

sub dispatch {
	my $this = shift;
	my $name = shift;
	my $param = { @_ };

	if(!defined($name)) {
		if(!defined($param->{'default'})) {
			die __PACKAGE__."#dispatch, ARG[1] was undef and default was not set.\n";
		} elsif(ref($param->{'default'})) {
			die __PACKAGE__."#dispatch, ARG[1] was undef and default was a Ref [$param->{'default'}].\n";
		} else {
			$name = $param->{'default'};
		}
	} elsif(ref($name)) {
		die __PACKAGE__."#dispatch, ARG[1] was a Ref. [$name]\n";
	}

	# 呼ばれる関数のあるパッケージはcallerから得る。
	my $pkg = caller;
	my $func = $pkg->can("Do$name");

	if($func && defined(&$func)) {
		$func->();
		1;
	} else {
		if(!defined($param->{'onerror'})) {
			undef;
		} else {
			eval {
				$param->{'onerror'}();
			};
			if($@) {
				die __PACKAGE__."#dispatch, onerror handler. [$@]\n";
			}
		}
	}
}

sub log {
	my $this = shift;
	my $group = shift;
	my $log = shift;

	if(!defined($group)) {
		die "TL#log, ARG[1]: got undef.\n";
	}
	if(!defined($log)) {
		die "TL#log, ARG[2]: got undef.\n";
	}

	$this->getDebug->_tlLog(
		group => $group,
		log   => $log,
	);

	$this->_log($group, $log);
}

sub _log {
	my $this = shift;
	my $group = shift;
	my $log = shift;

	if(!defined($group)) {
		die "TL#_log, ARG[1]: got undef.\n";
	}
	if(!defined($log)) {
		die "TL#_log, ARG[2]: got undef.\n";
	}

	my $time = time;
	my @localtime = localtime($time);
	$localtime[4]++;
	$localtime[5] += 1900;

	$log = sprintf('== %02d:%02d:%02d(%08x) %04x %04x [%s]',
		@localtime[2,1,0], $time, $$, ($LOG_SERIAL % 0x10000), $group)
		. "\n" . $log . "\n";

	if(!exists($this->{logdir})) {
		$this->{logdir} = $this->INI->get(TL => 'logdir');
	}
	if(!defined($this->{logdir})) {
		return $this;
	}

	my $dirpath = $this->{logdir} . '/'
		. sprintf('%04d%02d', @localtime[5,4]);
	my @dirstat = stat($dirpath);

	my $path = $this->{logdir} . '/'
		. sprintf('%04d%02d/%02d-%02d.log', @localtime[5,4,3,2]);

	if(!exists($this->{cacheLogPath}) || !defined($dirstat[1]) || $path ne $this->{cacheLogPath}) {

		delete $this->{cacheLogFh};
		my $umask = umask(0);
		local($@);
		CORE::eval {
			use File::Path;
			my $dir = $path;
			$dir =~ s,/[^/]*$,,;
			mkpath($dir);
		};
		if ($@){
			print "Content-Type: text/plain\n\n";
			print "Can't create directory [$path]\n";
			warn "Can't create directory [$path]";
			$this->sendError(
				title => "TL LogError",
				error => "Failed to create a directory [$path]($!)",
				nologging => 1,
			);
			exit;
		}
		$this->{cacheLogPath} = $path;
		umask($umask);
	}

	my @stat = stat($path);
	if(!defined($this->{cacheLogFh}) || !defined($stat[1]) || ($this->{cacheLogInode} != $stat[1])) {

		my $fh = $this->_gensym;
		if(!open($fh, ">>$path")) {
			print "Content-Type: text/plain\n\n";
			print "Can't open [$path]\n";
			warn "Can't open [$path]";
			$this->sendError(
				title => "TL LogError",
				error => "Failed to open a log [$path]($!)",
				nologging => 1,
			);
			exit;
		}
		binmode($fh);
		my @newstat = stat($path);
		$this->{cacheLogFh} = $fh;
		$this->{cacheLogInode} = $newstat[1];
	}

	my $fh = $this->{cacheLogFh};
	flock($fh, 2);
	seek($fh, 0, 2);
	syswrite($fh, $log);
	flock($fh, 8);

	$this;
}

sub getLogHeader {
	my $this = shift;
	
	my $time = time;
	my @localtime = localtime($time);
	$localtime[4]++;
	$localtime[5] += 1900;

	sprintf('%02d:%02d:%02d(%08x) %04x %04x',
		@localtime[2,1,0], $time, $$, ($LOG_SERIAL % 0x10000));
}

sub setHook {
	my $this = shift;
	my $type = shift;
	my $priority = shift;
	my $code = shift;

	if(!defined($type)) {
		die __PACKAGE__."#setHook, ARG[1] was Undef.\n";
	}
	if(ref($type)) {
		die __PACKAGE__."#setHook, ARG[1] was Ref.\n";
	}
	if(!exists($this->{hook}{$type})) {
		die __PACKAGE__."#setHook, hook type [$type] is not allowed.\n";
	}
	if(!defined($priority)) {
		die __PACKAGE__."#setHook, ARG[2] was not defined.\n";
	}
	if(ref($priority)) {
		die __PACKAGE__."#setHook, ARG[2] was Ref.\n";
	}
	if($priority !~ m/^-?\d+$/) {
		die __PACKAGE__."#setHook, invalid priority. [$priority]\n";
	}
	if(ref($code) ne 'CODE') {
		die __PACKAGE__."#setHook, ARG[3] was not CODE Ref.\n";
	}

	$this->{hook}{$type}{$priority} = $code;

	@{$this->{hooklist}{$type}} = map {
			$this->{hook}{$type}{$_};
		} sort {
			$a <=> $b;
		} keys %{$this->{hook}{$type}};

	$this;
}

sub removeHook {
	my $this = shift;
	my $type = shift;
	my $priority = shift;

	if(!defined($type)) {
		die __PACKAGE__."#removeHook, ARG[1] was Undef.\n";
	}
	if(ref($type)) {
		die __PACKAGE__."#removeHook, ARG[1] was Ref.\n";
	}
	if(!exists($this->{hook}{$type})) {
		die __PACKAGE__."#removeHook, hook type [$type] is not allowed.\n";
	}
	if(!defined($priority)) {
		die __PACKAGE__."#setHook, ARG[2] was not defined.\n";
	}
	if(ref($priority)) {
		die __PACKAGE__."#setHook, ARG[2] was Ref.\n";
	}

	delete $this->{hook}{$type}{$priority};

	@{$this->{hooklist}{$type}} = map {
			$this->{hook}{$type}{$_};
		} sort {
			$a <=> $b;
		} keys %{$this->{hook}{$type}};

	$this;
}

sub setContentFilter {
	my $this = shift;
	my $classname = shift;
	my $priority = 1000;
	my %option = @_;

	if(!defined($classname)) {
		die __PACKAGE__."#setContentFilter, ARG[1] was undef.\n";
	} elsif(ref($classname) eq 'ARRAY') {
		($classname, $priority) = @$classname;
		if(!defined($classname)) {
			die __PACKAGE__."#setContentFilter, ARG[1][0] was undef.\n";
		} elsif(ref($classname)) {
			die __PACKAGE__."#setContentFilter, ARG[1][0] was Ref.\n";
		}

		if (!defined($priority)) {
			die __PACKAGE__."#setContentFilter, ARG[1][1] was undef.\n";
		} elsif(ref($priority)) {
			die __PACKAGE__."#setContentFilter, ARG[1][1] was Ref.\n";
		} elsif($priority !~ m/^\d+$/) {
			die __PACKAGE__."#setContentFilter, invalid priority. [$priority]\n";
		}
	} elsif(ref($classname)) {
		die __PACKAGE__."#setContentFilter, ARG[1] was not scalar nor ARRAY ref.\n";
	}

	do {
		local $SIG{__DIE__} = 'DEFAULT';
		eval "require $classname";
	};
	if($@) {
		die $@;
	}

	do {
		no strict;
		*{"${classname}\::TL"} = *TL::TL;
	};

	$this->{filter}{$priority} = $classname->_new(%option);
	$this->_updateFilterList('filter');

	$this;
}

sub removeContentFilter {
	my $this = shift;
	my $priority = @_ ? shift : 1000;

	delete $this->{filter}{$priority};
	$this->_updateFilterList('filter');

	$this;
}

sub getContentFilter {
	my $this = shift;
	my $priority = @_ ? shift : 1000;

	$this->{filter}{$priority};
}

sub setInputFilter {
	my $this = shift;
	my $classname = shift;
	my $priority = 1000;
	my %option = @_;

	if (!defined($classname)) {
		die __PACKAGE__."#setInputFilter, ARG[1] was undef.\n";
	} elsif(ref($classname) eq 'ARRAY') {
		($classname, $priority) = @$classname;
		if(!defined($classname)) {
			die __PACKAGE__."#setInputFilter, ARG[1][0] was undef.\n";
		} elsif(ref($classname)) {
			die __PACKAGE__."#setInputFilter, ARG[1][0] was Ref.\n";
		}

		if(!defined($priority)) {
			die __PACKAGE__."#setInputFilter, ARG[1][1] was undef.\n";
		} elsif(ref($priority)) {
			die __PACKAGE__."#setInputFilter, ARG[1][1] was Ref.\n";
		} elsif($priority !~ m/^\d+$/) {
			die __PACKAGE__."#setInputFilter, invalid priority. [$priority]\n";
		}
	} elsif(ref($classname)) {
		die __PACKAGE__."#setInputFilter, ARG[1] was not scalar nor ARRAY ref.\n";
	}

	do {
		local $SIG{__DIE__} = 'DEFAULT';
		eval "require $classname";
	};
	if($@) {
		die $@;
	}

	do {
		no strict;
		*{"${classname}\::TL"} = *TL::TL;
	};

	$this->{inputfilter}{$priority} = $classname->_new(%option);
	$this->_updateFilterList('inputfilter');

	$this;
}

sub removeInputFilter {
	my $this = shift;
	my $priority = @_ ? shift : 1000;

	delete $this->{inputfilter}{$priority};
	$this->_updateFilterList('inputfilter');

	$this;
}

sub getInputFilter {
	my $this = shift;
	my $priority = @_ ? shift : 1000;

	$this->{inputfilter}{$priority};
}

sub _sendErrorIfNeeded {
	my $this = shift;
	my $err = shift;
	
	isa($err, 'TL::Error') or
	  $err = $TL->newError('error' => $err);

	my $emtype = $this->INI->get(TL => 'errormailtype', 'error memory-leak');
	my $types = {map { $_ => 1 } split /\s+/, $emtype};

	if ($types->{$err->type}) {
		$this->sendError(
			title => 'Tripletail: ' . $err->title,
			error => ($err->type eq 'error' ? "$err" : $err->message),
		   );
	}
}

sub sendError {
	my $this = shift;
	my $opts = { @_ };

	my $email;
	my ($rcpt, $group);
	if($email = $this->INI->get(TL => 'errormail')) {
		if($email =~ m/^(.+?)%(.+)$/) {
			$rcpt = $1;
			$group = $2;
		} else {
			$rcpt = $email;
			$group = 'Sendmail';
		}
	} else {
		return;
	}

	local($@);

	if(!defined($opts->{title})) {
		$opts->{title} = "Untitled";
	}
	if(!defined($opts->{error})) {
		$opts->{title} = "Unknown Error";
	}

	my @lines;
	push @lines, "TITLE: $opts->{title}";
	push @lines, "ERROR: $opts->{error}";
	push @lines, '';
	push @lines, '----';

	my $host = '';
	eval { $host = `hostname -f` };
	if(!$host) {
		eval { $host = `hostname` };
	}
	if($host) {
		chomp $host;
		unshift @lines, "HOST: $host";
	}

	my $locinfo = '@' . $host;
	if(defined $0) {
		$locinfo = $0 . $locinfo;

		unshift @lines, "SCRIPT: $0";
	}

	if($this->{CGIORIG}) {
		foreach my $key ($this->{CGIORIG}->getKeys) {
			foreach my $data ($this->{CGIORIG}->getValues($key)) {
				push @lines, "[CGI:$key] $data";
			}
		}
	}

	foreach my $key (keys %ENV) {
		push @lines, "[ENV:$key] $ENV{$key}";
	}

	eval {
		my $mail = $this->newMail->setHeader(
				From    => $rcpt,
				To      => $rcpt,
				Subject => "$opts->{title} $locinfo",
		)->setBody(join "\n", @lines)->toStr;

		$this->newSendmail($group)->_setLogging(0)->connect->send(
			from => $rcpt,
			rcpt => $rcpt,
			data => $mail,
		)->disconnect;
	};
	if(my $err = $@) {
		if(! $opts->{nologging}) {
			$this->log(__PACKAGE__, "Failed to send an error mail: $err");
		}
	}
}

sub print {
	my $this = shift;
	my $data = shift;

	local $| = 1;

	if(!defined($data)) {
		die __PACKAGE__."#print, ARG[1] was undef.\n";
	}

	if(@{$this->{filterlist}} == 0) {
		# フィルタが一つも無い時はprintできない。
		die __PACKAGE__."#print, we have no content-filters. Set at least one filter.\n";
	}

	$this->{printflag} = 1;

	foreach my $filter (@{$this->{filterlist}}) {
		$data = $filter->print($data);
	}

	if($this->{outputbuffering}) {
		$this->{outputbuff} .= $data;
	} else {
		print $data;
	}

	$this;
}

sub location {
	my $this = shift;
	my $url = shift;

	if(exists($this->{printflag})) {
		die __PACKAGE__."#location, location called after print.\n";
	}

	# 以前のContentFilterがFilter::HTMLまたはFilter::MobileHTMLだった場合は
	# SaveFormも引き継がなくてはならない。
	my $old = $this->getContentFilter;
	my $save;
	if ($old) {
		if ($old->can('getSaveForm')) {
			$save = $old->getSaveForm;
		}
	}

	$this->setContentFilter(
		'TL::Filter::Redirect',
		location => $url,
	);

	if($save) {
		$this->getContentFilter->getSaveForm->addForm($save);
	}

	$this;
}

sub parsePeriod {
	# 時刻指定 (sec, min等) をパースし、秒数に変換する。
	my $this = shift;
	my $str = shift;

	if(!defined($str)) {
		die __PACKAGE__."#parsePeriod, ARG[1] was undef.\n";
	}

	$str = lc($str);

	my $result = 0;

	my $lastnum = undef;
	local *commit = sub {
			my $unit = shift;

		if(!defined($lastnum)) {
			die __PACKAGE__."#parsePeriod, invalid time string [$str]:".
			" It has an isolated unit that does not follow any digits.\n";
		}

		$result += $lastnum * $unit;
		$lastnum = undef;
	};

	local($_) = $str;
	while(1) {
		length or last;

		s/^\s+//;

		if(s/^sec(?:onds?)?//) {
			commit(1);
		} elsif(s/^min(?:utes?)?//) {
			commit(60);
		} elsif(s/^hours?//) {
			commit(60 * 60);
		} elsif(s/^days?//) {
			commit(60 * 60 * 24);
		} elsif(s/^mon(?:ths?)?//) {
			commit(60 * 60 * 24 * 30);
		} elsif(s/^(\d+)//) {
			if(defined($lastnum)) {
				die __PACKAGE__."#parsePeriod, invalid time string [$str]:".
				" It has digits followed by another digits instead of unit.\n";
			}

			$lastnum = $1;
		} else {
			die __PACKAGE__."#parsePeriod, invalid format: [$_]\n";
		}
	}

	if(defined($lastnum)) {
		commit(1);
	}

	$result;
}

sub parseQuantity {
	# 量指定 (k, m等) をパースし、そのままの数に変換する。
	my $this = shift;
	my $str = shift;

	if(!defined($str)) {
		die __PACKAGE__."#parseQuantity, ARG[1] was undef.\n";
	}

	$str = lc($str);

	my $result = 0;

	my $lastnum = undef;
	local *commit = sub {
		my $unit = shift;

		if(!defined($lastnum)) {
			die __PACKAGE__."#parsePeriod, invalid quantity string [$str]:".
			" It has an isolated unit that does not follow any digits.\n";
		}

		$result += $lastnum * $unit;
		$lastnum = undef;
	};

	local($_) = $str;
	while(1) {
		length or last;

		s/^\s+//;

		if(s/^ki//) {
			commit(1024);
		} elsif(s/^mi//) {
			commit(1024 * 1024);
		} elsif(s/^gi//) {
			commit(1024 * 1024 * 1024);
		} elsif(s/^ti//) {
			commit(1024 * 1024 * 1024 * 1024);
		} elsif(s/^pi//) {
			commit(1024 * 1024 * 1024 * 1024 * 1024);
		} elsif(s/^ei//) {
			commit(1024 * 1024 * 1024 * 1024 * 1024 * 1024);
		} elsif(s/^k//) {
			commit(1000);
		} elsif(s/^m//) {
			commit(1000 * 1000);
		} elsif(s/^g//) {
			commit(1000 * 1000 * 1000);
		} elsif(s/^t//) {
			commit(1000 * 1000 * 1000 * 1000);
		} elsif(s/^p//) {
			commit(1000 * 1000 * 1000 * 1000 * 1000);
		} elsif(s/^e//) {
			commit(1000 * 1000 * 1000 * 1000 * 1000 * 1000);
		} elsif(s/^(\d+)//) {
			if(defined($lastnum)) {
				die __PACKAGE__."#parseQuantity, invalid quantity string [$str]:".
				" It has digits followed by another digits instead of unit.\n";
			}

			$lastnum = $1;
		} else {
			die __PACKAGE__."#parsePeriod, invalid format: [$_]\n";
		}
	}

	if(defined($lastnum)) {
		commit(1);
	}

	$result;
}


sub getCookie {
	my $this = shift;

	require TL::Cookie;

	TL::Cookie->_getInstance(@_);
}

sub newDateTime {
	my $this = shift;

	require TL::DateTime;

	TL::DateTime->_new(@_);
}

sub getDB {
	my $this = shift;

	require TL::DB;

	TL::DB->_getInstance(@_);
}

sub newDB {
	my $this = shift;

	require TL::DB;

	TL::DB->_new(@_);
}

sub getDebug {
	my $this = shift;

	require TL::Debug;

	TL::Debug->_getInstance(@_);
}

sub getCsv {
	my $this = shift;

	require TL::CSV;

	TL::CSV->_getInstance(@_);
}

sub newForm {
	my $this = shift;

	require TL::Form;

	*TL::Form::TL = *TL::TL;

	TL::Form->_new(@_);
}

sub newHtmlFilter {
	my $this = shift;

	require TL::HtmlFilter;

	TL::HtmlFilter->_new(@_);
}

sub newHtmlMail {
	my $this = shift;

	require TL::HtmlMail;

	TL::HtmlMail->_new(@_);
}

sub newIni {
	my $this = shift;

	require TL::Ini;

	*TL::Ini::TL = *TL::TL;

	TL::Ini->_new(@_);
}

sub newMail {
	my $this = shift;

	require TL::Mail;

	TL::Mail->_new(@_);
}

sub newPager {
	my $this = shift;

	require TL::Pager;

	TL::Pager->_new(@_);
}

sub getRawCookie {
	my $this = shift;

	require TL::RawCookie;

	TL::RawCookie->_getInstance(@_);
}

sub newSendmail {
	my $this = shift;

	require TL::Sendmail;

	TL::Sendmail->_new(@_);
}

sub newSMIME {
	my $this = shift;

	require TL::SMIME;

	TL::SMIME->new(@_);
}

sub newTagCheck {
	my $this = shift;

	require TL::TagCheck;

	TL::TagCheck->_new(@_);
}

sub newTemplate {
	my $this = shift;

	require TL::Template;

	TL::Template->_new(@_);
}

sub getSession {
	my $this = shift;

	require TL::Session;

	TL::Session->_getInstance(@_);
}

sub newValue {
	my $this = shift;

	require TL::Value;

	TL::Value->_new(@_);
}

sub newValidator {
	my $this = shift;
	
	require TL::Validator;
	
	TL::Validator->_new(@_);
}

sub newError {
	my $this = shift;

	# TL::Error のロード失敗は特別に扱わなければならない。
	# die ハンドラがこれを利用する為である。
	eval {
		require TL::Error;
	};
	if ($@) {
		print STDERR $@;
		exit 1;
	}

	TL::Error->_new(@_);
}

sub getMemorySentinel {
	my $this = shift;

	require TL::MemorySentinel;

	TL::MemorySentinel->_getInstance(@_);
}

sub getFileSentinel {
	my $this = shift;

	require TL::FileSentinel;

	TL::FileSentinel->_getInstance(@_);
}

sub newMemCached {
	my $this = shift;

	require TL::MemCached;

	TL::MemCached->_new();
}

sub charconv {
	my $this = shift;

	require TL::CharConv;

	TL::CharConv->_getInstance()->_charconv(@_);
}

sub readFile {
	my $this = shift;
	my $fpath = shift;

	if(!defined($fpath)) {
		die __PACKAGE__."#readFile, ARG[1] was undef.\n";
	} elsif(ref($fpath)) {
		die __PACKAGE__."#readFile, ARG[1] was a Ref. [$fpath]\n";
	}

	open my $fh, '<', $fpath
	  or die __PACKAGE__."#readFile, Failed to read file [$fpath]: $!\n";

	local $/ = undef;
	<$fh>;
}

sub readTextFile {
	my $this = shift;
	my $fpath = shift;
	my $coding = shift;
	my $prefer_encode = shift;

	$this->charconv(
		$this->readFile($fpath),
		$coding,
		'utf8',
		$prefer_encode,
	);
}

sub writeFile {
	my $this = shift;
	my $fpath = shift;
	my $fdata = shift;
	my $fmode = shift;

	if(!defined($fpath)) {
		die __PACKAGE__."#writeFile, ARG[1] was undef.\n";
	} elsif(ref($fpath)) {
		die __PACKAGE__."#writeFile, ARG[1] was a Ref. [$fpath]\n";
	}
	
	$fmode = 0 if(!defined($fmode));

	my $fmode_str = '>';
	$fmode_str = '>>' if($fmode == 1);

	open my $fh, $fmode_str, $fpath
	  or die __PACKAGE__."#writeFile, Failed to read file [$fpath]: $!\n";
	print $fh $fdata;
	close $fh;

}

sub writeTextFile {
	my $this = shift;
	my $fpath = shift;
	my $fdata = shift;
	my $fmode = shift;
	my $coding = shift;
	my $prefer_encode = shift;

	if(!defined($coding)) {
		$coding = 'utf8';
	}
	if(ref($coding)) {
		die __PACKAGE__."#writeTextFile, ARG[4] was a Ref. [$coding]\n";
	}

	$this->charconv(
		$this->writeFile($fpath,$fdata,$fmode),
		'utf8',
		$coding,
		$prefer_encode,
	);
}

sub watch {
	my $this = shift;

	require TL::Debug::Watch;

	TL::Debug::Watch::watch(@_);
}

sub dump {
	my $this = shift;
	my $group = shift;
	my $var = shift;
	my $level = shift || 0;

	local($@);
	eval {
		use Data::Dumper;
		my $dump = Data::Dumper->new([$var])
			->Maxdepth($level)->Indent(1)->Terse(1)->Dump;
		$this->log($group => $dump);
	};

	$this;
}

sub printCacheUnlessModified {
	my $this = shift;
	my $key = shift;
	my $flag = shift;
	my $param = shift; # always HASH ref
	my $charset = shift;

	if(!defined($key)) {
		die __PACKAGE__."#printCacheUnlessModified, ARG[1] was undef.\n";
	} elsif(ref($key)) {
		die __PACKAGE__."#printCacheUnlessModified, ARG[1] was a Ref. [$key]\n";
	}

	$flag = 'on' if(!defined($flag));
	$charset = 'Shift_JIS' if(!defined($charset));

	my $cachedata = $TL->newMemCached->get($key);
	return 1 if(!defined($cachedata));
	if($cachedata =~ s/^(\d+),//) {
		my $cachetime = $1;
		if(defined($ENV{HTTP_IF_MODIFIED_SINCE}) && $flag eq 'on' && $TL->newDateTime($ENV{HTTP_IF_MODIFIED_SINCE})->getEpoch >= $cachetime) {
			$TL->setContentFilter('TL::Filter::HeaderOnly');
			$TL->getContentFilter->setHeader('Status' => '304');
			$TL->getContentFilter->setHeader('Last-Modified' => $TL->newDateTime->setEpoch($cachetime)->toStr('rfc822'));
			return undef;
		} else {
			$TL->setContentFilter('TL::Filter::MemCached',key => $key, type => 'out');
			if(defined($param)) {
				foreach my $key2 ($param->getKeys){
					my $val = $TL->charconv($param->get($key2), 'UTF-8' => $charset);
					$cachedata =~ s/$key2/$val/g;
				}
			}
			$TL->print($cachedata);
			return undef;
		}
	}
	1;
}

sub setCache {
	my $this = shift;
	my $key = shift;
	my $param = shift;
	my $charset = shift;
	my $priority = shift;

	if(!defined($key)) {
		die __PACKAGE__."#setCache, ARG[1] was undef.\n";
	} elsif(ref($key)) {
		die __PACKAGE__."#setCache, ARG[1] was a Ref. [$key]\n";
	}

	$priority = 1500 if(!defined($priority));
	
	if(defined($charset)) {
		$TL->setContentFilter(['TL::Filter::MemCached',$priority],key => $key, type => 'in', param => $param,  charset => $charset);
	} else {
		$TL->setContentFilter(['TL::Filter::MemCached',$priority],key => $key, type => 'in', param => $param);
	}
}

sub deleteCache {
	my $this = shift;
	my $key = shift;

	if(!defined($key)) {
		die __PACKAGE__."#deleteCache, ARG[1] was undef.\n";
	} elsif(ref($key)) {
		die __PACKAGE__."#deleteCache, ARG[1] was a Ref. [$key]\n";
	}

	$TL->newMemCached->delete($key);
}

sub _gensym {
	package TL::Symbol;
	no strict;
	$genpkg = "TL::Symbol::";
	$genseq = 0;

	my $name = "GEN" . $genseq++;
	my $ref = \*{$genpkg . $name};
	delete $$genpkg{$name};

	$ref;
}

sub _getRunMode {
	my $this = shift;

	if(!$ENV{PATH}) {
		'FCGI';
	} elsif($ENV{GATEWAY_INTERFACE}) {
		'CGI';
	} else {
		'script';
	}
}

sub _decodeFromURL {
	my $this = shift;
	my $url = shift;

	if(@{$this->{inputfilterlist}} == 0) {
		# フィルタが一つも無い時はデコードできない。
		die __PACKAGE__."#_decodeFromURL, we have no input-filters. Set at least one filter.\n";
	}

	# フラグメントを除去
	my $fragment;
	if($url =~ s/#(.+)$//) {
		$fragment = $1;
	}

	# 最初に空のTL::Formを作り、それを順々にフィルタに通して行く。
	my $form = $this->newForm;
	foreach my $filter (@{$this->{inputfilterlist}}) {
		$filter->decodeURL($form, $url, $fragment);
	}

	($form, $fragment);
}

sub _saveContentFilter {
	my $this = shift;
	
	%{$this->{saved_filter}} = %{$this->{filter}};
	$this->_updateFilterList('filter');
}

sub _restoreContentFilter {
	my $this = shift;

	%{$this->{filter}} = %{$this->{saved_filter}};
	$this->_updateFilterList('filter');

	%{$this->{saved_filter}} = ();
}

sub _updateFilterList {
	my $this = shift;
	my $key = shift;
	my $listkey = $key . 'list';

	@{$this->{$listkey}} =
		map { $this->{$key}{$_} }
			(sort {$a <=> $b} keys %{$this->{$key}});
}

sub __decodeCgi {
	my $this = shift;

	if(@{$this->{inputfilterlist}} == 0) {
		# フィルタが一つも無い時はデコードできない。
		die __PACKAGE__."#__decodeCgi, we have no input-filters. Set at least one filter.\n";
	}

	# 最初に空のTL::Formを作り、それを順々にフィルタに通して行く。
	my $form = $this->newForm;
	foreach my $filter (@{$this->{inputfilterlist}}) {
		$filter->decodeCgi($form);
	}

	$form;
}

sub __executeHook {
	my $this = shift;
	my $type = shift;

	foreach (@{$this->{hooklist}{$type}}) {
		$_->();
	}

	$this;
}

sub __dispError {
	my $this = shift;
	my $err = shift;

	isa($err, 'TL::Error') or
	  $err = $TL->newError('error' => $err);

	my $popup = $TL::Debug::_INSTANCE->_implant_disperror_popup;
	my $html = $err->toHtml;
	$html =~ s|</html>$|$popup</html>|;

	print "Content-Type: text/html; charset=UTF-8\n\n";
	print $html;

	$this->_sendErrorIfNeeded($err);

	my $errorlog = $this->INI->get(TL => 'errorlog', 1);
	if($errorlog > 0) {
		$this->log(__PACKAGE__, "$err");
	}
	if($errorlog > 1) {
		$TL::Debug::_INSTANCE->__log_request;
	}
}

sub __executeCgi {
	my $this = shift;
	my $mainfunc = shift;

	$LOG_SERIAL++;
	
	# ここで$CGIを作り、constにする。
	$this->{CGIORIG} = $this->__decodeCgi->const;
	$this->{CGI} = $this->{CGIORIG}->clone->_trace;
	our $CGI = $this->{CGI};
	$this->{outputbuff} = '';

	# $CGI の export
	my $callpkg = caller(2);
	{
		no strict "refs";
		*{"$callpkg\::CGI"} = *{"TL::CGI"};
	}

	$this->__executeHook('preRequest');
	$this->_saveContentFilter;

	eval {
		$mainfunc->();
	};
	if($@) {
		$this->__dispError($@);
	} else {
		$this->__flushContentFilter;
	}

	$this->_restoreContentFilter;
	$this->__executeHook('postRequest');

	# $CGIを消す。
	$this->{CGI} = undef;
	$this->{CGIORIG} = undef;
	$this->{outputbuff} = '';
	$this;
}

sub __flushContentFilter {
	my $this = shift;

	delete $this->{printflag};

	my $str = $this->{outputbuff};
	foreach my $filter (@{$this->{filterlist}}) {
		$str = $filter->print($str);
		$str .= $filter->flush;
	}

	print $str;
}

__END__

=encoding utf-8

=head1 NAME

TL - Tripletail, Framework for Japanese Web Application

=head1 NAME (ja)

TL - Tripletail, 日本語向けウェブアプリケーションフレームワーク

=head1 SYNOPSIS

  use TL qw(tl.ini);
  
  $TL->startCgi(
      -main => \&main,
  );
  
  sub main {
      my $t = $TL->newTemplate('index.html');

      $t->flush;
  }
  
=head1 DESCRIPTION

=head2 C<use>

tlでは、ライブラリの各種設定は L<Ini|TL::Ini> ファイルに置かれる。

実行が開始されるスクリプトの先頭で、次のように引数として L<Ini|TL::Ini>
ファイルの位置を渡す。するとグローバル変数 C<$TL> がエクスポートされる。
L<Ini|TL::Ini> ファイル指定は必須である。

  use TL qw(/home/www/ini/tl.ini);

他のファイルから C<$TL> 変数を使う場合は、そのパッケージ内で
C<use TL;> のように引数無しで C<use> する。二度目以降の C<use> で
L<Ini|TL::Ini> ファイルの位置を指定しようとした場合はエラーとなる。

設定ファイルの設定値のうち、一部の値を特定のCGIで変更したい場合は、
次のように2つめ以降引数に特化指定をすることが出来る。

  use TL qw(/home/www/ini/tl.ini golduser);

特化指定を行った場合、ライブラリ内で Ini ファイルを参照する際に、
まず「グループ名 + ":" + 特化指定値」のグループで検索を行う。
結果がなかった場合は、通常のグループ名の指定値が使用される。

また、サーバのIPやリモートのIPにより使用するグループを変更することも出来る。それぞれ
「グループ名 + "@sever" + 使用するサーバのマスク値」
「グループ名 + "@remote" + 使用するリモートのマスク値」
といった書式となる。

但し、スクリプトで起動した場合、リモートのIP指定している項目は全て無視される。
サーバのIP指定している項目の場合、hostname -iで取得した値でマッチされる。

使用するサーバのマスク値と、リモートのマスク値に関しては、Ini中の[HOST]グループに設定する。例えば次のようになる。

  [HOST]
  Debughost = 192.168.10.0/24
  Testuser = 192.168.11.5 192.168.11.50
  [TL@server:Debughost]
  logdir = /home/tl/logs
  errormail = tl@example.org
  [TL@server:Debughost]
  logdir = /home/tl/logs/regist

マスクは空白で区切って複数個指定する事が可能。

但し、[HOST]には特化指定は利用できない。

特化指定を二種、もしくは、三種を組み合わせて利用することも出来るが、その場合の順序は「グループ名 + ":" + 特化指定値 + "@sever" + 使用するサーバのマスク値 + "@remote" + 使用するリモートのマスク値」で固定であり、その他の並びで指定することは出来ない。

特化指定は複数行うことができ、その場合は最初の方に書いたものほど優先的に使用される。 

=head2 特化指定

特化指定の具体的例を示す

  [HOST]
  Debughost = 192.168.10.0/24
  Testuser = 192.168.11.5 192.168.11.50
  [TL:regist@server:Debughost]
  logdir = /home/tl/logs/regist/debug
  [TL@server:Debughost]
  logdir = /home/tl/logs
  errormail = tl@example.org
  [TL]
  logdir = /home/tl/logs
  [TL:regist]
  logdir = /home/tl/logs/regist
  [Debug@remote:Testuser]
  enable_debug=1

というtl.iniが存在している場合に

  use TL qw(/home/www/ini/tl.ini regist);
で、起動した場合、次のような動作になる。

プログラムが動いているサーバが、192.168.10.0/24であり、アクセスした箇所のIPが192.168.11.5か192.168.11.50である場合

  [TL]
  logdir = /home/tl/logs/regist/debug
  errormail = tl@example.org
  [Debug]
  enable_debug=1

プログラムが動いているサーバが、192.168.10.0/24であり、アクセスした箇所のIPが192.168.11.5か192.168.11.50では無い場合

  [TL]
  logdir = /home/tl/logs/regist


  use TL qw(/home/www/ini/tl.ini regist);
で、起動した場合、次のような動作になる。

プログラムが動いているサーバが、192.168.10.0/24であり、アクセスした箇所のIPが192.168.11.5か192.168.11.50である場合

  [TL]
  logdir = /home/tl/logs/debug
  errormail = tl@example.org
  [Debug]
  enable_debug=1

プログラムが動いているサーバが、192.168.10.0/24であり、アクセスした箇所のIPが192.168.11.5か192.168.11.50では無い場合

  [TL]
  logdir = /home/tl/logs

=head2 キャッシュの利用

Cache::Memcachedがインストールされ、memcachedサーバがある場合に、キャッシュが利用可能となる。

具体例は次の通り

INIファイルにて、memcachedが動いているサーバを指定する。
[MemCached]
servers = localhost:11211

=over 4

=item 読み込み側例（ページ全体をキャッシュ）

  #topはキャッシュするキー。画面毎にキーを設定する。ページャーなどを利用する場合、画面毎になる点を注意する（page-1等にする）
  #キャッシュにヒットした場合、時間を比較して、304でリダイレクトするか、メモリから読み込んで表示する
  #returnした後にprintやflushなど出力する操作は不可なため注意する事
  return if(!defined($TL->printCacheUnlessModified('top')));
  #キャッシュすることを宣言する。なお、宣言はprintCacheUnlessModifiedより後であれば、どの時点で行ってもかまわない
  $TL->setCache('top');

  #実際のスクリプトを記述し、出力を行う
  
  $TL->print('test code.');

=item 書き込み側例（ページ全体をキャッシュ）

  #書き込みを行った場合、そのデータを表示する可能性があるキャッシュを全て削除する
  #削除漏れがあると、キャッシュしている内容が必要な為注意が必要。
  $TL->deleteCache('top');
  $TL->deleteCache('top2');

=item 読み込み側例（ユーザー名等一部に固有の情報を埋め込んでいる場合）

  #クッキーデータの取得、クッキーに固有の情報を入れておくと高速に動作出来る（DB等から読み込みTL:Formクラスにセットしても可）
  my $cookiedata = $TL->getCookie->get('TLTEST');
  $cookiedata->set('<&NAME>' => $name) if(!$cookiedata->exists('name'));
  $cookiedata->set('<&POINT>' => $point) if(!$cookiedata->exists('point'));

  #topはキャッシュするキー。固有情報が変更された場合、キャッシュ情報をクリアしないと永遠に情報が変わらない為、
  #304は通常無効にする必要がある。
  #固有の情報を置換するための情報をセットする。キーがそのまま置換される。
  #その他の条件はページ全体をキャッシュする場合と同様。
  return if(!defined($TL->printCacheUnlessModified('top','off',$cookiedata)));
  #キャッシュすることを宣言する。その際、固有の情報を置換するための情報をセットする。
  $TL->setCache('top',$cookiedata);

  #実際のスクリプトを記述し、出力を行う
  #この際、固有の情報の部分に関しては、特殊タグ（文字列）に置換する。特殊タグはどのような形でもかまわないが、
  #出力文字列中の全ての同様の特殊タグが変換対象になるため、ユーザーや管理者が任意に変更出来る部分に注意する。
  #（タグエスケープする、その特殊タグが入力された場合エラーにするetc）
  
  $t->expand(
    NAME => '<&NAME>',
    POINT => '<&POINT>',
  );

  
  $TL->print('test code.');

=item 書き込み側例（ユーザー名等一部に固有の情報を埋め込んでいる場合）

  #書き込みを行った場合、そのデータを表示する可能性があるキャッシュを全て削除する
  #削除漏れがあると、キャッシュしている内容が必要な為注意が必要。
  #また、固有の文字列を出力用にクッキーなどに書き出したりする。
  $TL->getCookie->set(TLTEST => $TL->newForm('<&NAME>' => $CGI->get('name'),'<&POINT>' => 1000));

  $TL->deleteCache('top');
  $TL->deleteCache('top2');


=back

=head2 実行モード

実行モードには次の三つがある。

=over 4

=item CGIモード

CGIとしてプログラムを動作させるモード。このモードでは C<< $TL->print >>
メソッドや L</"出力フィルタ"> 、 L</"入力フィルタ"> が利用可能になる。

このモードでは L<< $TL->startCgi|/"startCgi" >> メソッドで L</"Main関数"> を呼ぶ。

=item FastCGIモード

FastCGIとしてプログラムを動作させるモード。httpdからfcgiスクリプトとして起動
しようとすると、自動的に選ばれる。このモードではプロセスのメモリ使用量を
監視し、起動後にある一定の大きさを越えてメモリ使用量が増大すると、メモリリーク
が発生しているとして自動的に終了する。また、 L<Ini|TL::Ini> パラメータ付きで
C<use TL> したスクリプトファイルや、その L<Ini|TL::Ini> ファイルの最終更新時刻
も監視し、更新されていたら自動的に終了する。

=item 一般スクリプトモード

CGIでない一般のスクリプトとしてプログラムを動作させるモード。
CGIモード特有の機能は利用出来ない。

このモードでは L<< $TL->errorTrap|/"errorTrap" >> メソッドで L</"Main関数"> を呼ぶ。

=back


=head2 出力フィルタ

L<< $TL->print|/"print" >> や L<< $template->flush|TL::Template/"flush" >>
で出力される内容は、 L<TL::Filter> によって加工される。出力の先頭にHTTPヘッダを
付加するのも出力フィルタである。


=head2 入力フィルタ

C<< $ENV{QUERY_STRING} >> その他のCGIのリクエスト情報は、 L<TL::InputFilter>
が読み取り、 L<TL::Form> オブジェクトを生成する。得られたリクエスト情報は
$CGI オブジェクトか L<< $TL->CGI|/"CGI" >> メソッドで取得出来る。


=head2 Main関数

リクエスト一回毎に呼ばれる関数。この関数の中でCGIプログラムは入出力を行う。
L</"FastCGIモード"> 以外では一度のプロセスの起動で一度しか呼ばれない。


=head2 フック

L<< $TL->setHook|/"setHook" >> メソッドを用いてフックを掛ける事が出来る。

=over 4

=item init

L</"startCgi"> もしくは L</"errorTrap"> が呼ばれ、最初に L</"Main関数"> が
呼ばれる前。

=item preRequest

L</"Main関数"> が呼ばれる直前。

=item postRequest

L</"Main関数"> が呼ばれた直後。

=item term

最後に L</"Main関数"> が呼ばれた後。termフック呼出し後に L</"startCgi">
もしくは L</"errorTrap"> が終了する。

=back


=head2 METHODS

=over 4

=item C<< INI >>

  $TL->INI

C<< use TL qw(filename.ini); >> で読み込まれた L<TL::Ini> を返す。

=item C<< CGI >>

  $TL->CGI
  $CGI

リクエストを受け取った L<TL::Form> オブジェクトを返す。
また、このオブジェクトは startCgi メソッドの呼び出し元パッケージに export される。

このメソッドがundefでない値を返すのは、 L</"preRequest"> フックが呼ばれる
直前から L</"postRequest"> フックが呼ばれた直後までである。

=item C<< escapeTag >>

  $result = $TL->escapeTag($value)

&E<lt>E<gt>"' の文字をエスケープ処理した文字列を返す。

=item C<< unescapeTag >>

  $result = $TL->unescapeTag($value)

&E<lt>E<gt>"'&#??;&#x??; にエスケープ処理された文字を元に戻した文字列を返す。

=item C<< escapeJs >>

  $result = $TL->escapeJs($value)

'"\ の文字を \ を付けてエスケープし，'\r' '\n' について '\\r' '\\n' に置き換える。

=item C<< unescapeJs >>

  $result = $TL->unescapeJs($value)

escapeJs した文字列を元に戻す。

=item C<< encodeURL >>

  $result = $TL->encodeURL($value)

文字列をURLエンコードした結果を返す。

=item C<< decodeURL >>

  $result = decodeURL($value)

URLエンコードを解除し元に戻した文字列を返す。

=item C<< escapeSqlLike >>

  $result = $TL->escapeSqlLike($value)

% _ \ の文字を \ でエスケープ処理した文字列を返す。

=item C<< unescapeSqlLike >>

  $result = $TL->unescapeSqlLike($value)

\% \_ \\ にエスケープ処理された文字を元に戻した文字列を返す。

=item C<< startCgi >>

  $TL->startCgi(
    -main        => \&Main,    # メイン関数
    -DB          => 'DB',      # DBを使う場合，iniのグループ名を指定
    -Session => 'Session',     # Sessionを使う場合、iniのグループ名を指定
  );

CGIを実行する為の環境を整えた上で、 L</"Main関数"> を実行する。
L</"Main関数"> がdieした場合は、エラー表示HTMLが出力される。

C<DB> は、次のように配列へのリファレンスを渡す事で、複数指定可能。

  $TL->startCgi(
    -main => \&Main,
    -DB   => ['DB1', 'DB2'],
  );

C<Session> は、次のように配列へのリファレンスを渡す事で、複数指定可能。

  $TL->startCgi(
    -main        => \&Main,
    -DB          => 'DB',
    -Session => ['Session1', 'Session2'],
  );

=item C<< errorTrap >>

  $TL->errorTrap(
    -main => \&Main, # メイン関数
    -DB   => 'DB',   # DBを使う場合，iniのグループ名を指定
  );

環境を整え、 L</"Main関数"> を実行する。
L</"Main関数"> がdieした場合は、エラー内容が標準エラーへ出力される。

L</"startCgi"> と同様に、C<DB> には配列へのリファレンスを渡す事も出来る。

=item C<< dispatch >>

  $result = $TL->dispatch($value, default => $default, onerror => \&Error)

'Do' と $value を繋げた関数名の関数を呼び出す。
$valueがundefの場合、defaultを指定していた場合、defaultに設定される。

onerrorが未設定で関数が存在しなければ undef、存在すれば1を返す。

onerrorが設定されていた場合、関数が存在しなければ onerrorで設定された関数が呼び出される。

  例:
  package Foo;
  
  sub main {
      my $what = 'Foo';
      $TL->dispatch($what, default => 'Foo', onerror => \&DoError);
  }
  
  sub DoFoo {
      ...
  }

  sub DoError {
      ...
  }

=item C<< log >>

  $TL->log($group => $log)

ログを記録する。グループとログデータの２つを受け取る。

ログにはヘッダが付けられ、ヘッダは「時刻(epoch値の16進数8桁表現) プロセスIDの16進数4桁表現 FastCGIのリクエスト回数の16進数4桁表現 [グループ]」の形で付けられる。

=item C<< getLogHeader >>

  my $logid = $TL->getLogHeader

ログを記録するときのヘッダと同じ形式の文字列を生成する。
「時刻(epoch値の16進数8桁表現) プロセスIDの16進数4桁表現 FastCGIのリクエスト回数の16進数4桁表現」の形の文字列が返される。

=item C<< setHook >>

  $TL->setHook($type, $priority, \&func)

指定タイプの指定プライオリティのフックを設定する。
既に同一タイプで同一プライオリティのフックが設定されていた場合、
古いフックの設定は解除される。

typeは、L</"init">, L</"term">, L</"preRequest">, L</"postRequest">
の４種類が存在する。

なお、1万の整数倍のプライオリティは Tripletail 内部で使用される。アプリ
ケーション側で不用意に用いるとフックを上書きしてしまう可能性があるので
注意する。

=item C<< removeHook >>

  $TL->removeHook($type, $priority)

指定タイプの指定プライオリティのフックを削除する。

=item C<< setContentFilter >>

  $TL->setContentFilter($classname, %option)
  $TL->setContentFilter([$classname, $priority], %option)
  $TL->setContentFilter('TL::Filter::HTML', charset => 'Shift_JIS')
  $TL->setContentFilter(
      'TL::Filter::CSV', charset => 'Shift_JIS', filename => 'テストデータ.csv')

L</"出力フィルタ"> を設定する。
全ての出力の前に実行する必要がある。
２番目の書式では、プライオリティを指定して独自のコンテンツフィルタを追加できる。
省略時は優先度は1000となる。同一優先度のフィルタが既にセットされているときは、
以前のフィルタ設定は解除される。

返される値は、指定された L<TL::Filter> のサブクラスのインスタンスである。

設定したフィルタは、L</"preRequest"> のタイミングで保存され、
L</"postRequest"> のタイミングで元に戻される。従って、L</"Main関数">内
で setContentFilter を実行した場合、その変更は次回リクエスト時に持ち越
されない。

=item C<< getContentFilter >>

  $TL->getContentFilter($priority)

指定されたプライオリティのフィルタを取得する。省略時は1000となる。

=item C<< removeContentFilter >>

  $TL->removeContentFilter($priority)

指定されたプライオリティのフィルタを削除する。省略時は1000となる。
フィルタが１つもない場合は、致命的エラーとなり出力関数は使用できなくなる。

=item C<< setInputFilter >>

  $TL->setInputFilter($classname, %option)
  $TL->setInputFilter([$classname, $priority], %option)

L</"入力フィルタ"> を設定する。
L</"startCgi"> の前に実行する必要がある。

返される値は、指定された L<TL::InputFilter> のサブクラスのインスタンスである。

=item C<< getInputFilter >>

  $TL->getInputFilter($priority)

=item C<< removeInputFilter >>

  $TL->removeInputFilter($priority)

=item C<< sendError >>

  $TL->sendError(-title => "タイトル", -error => "エラー")

L<ini|TL::Ini> で指定されたアドレスにエラーメールを送る。
設定が無い場合は何もしない。

=item C<< print >>

  $TL->print($str)

コンテンツデータを出力する。L</"startCgi"> から呼ばれた L</"Main関数"> 内
のみで使用できる。ヘッダは出力できない。

フィルタによってはバッファリングされる場合もあるが、
基本的にはバッファリングされない。

=item C<< location >>

  $TL->location('http://example.org/')

CGIモードの時、指定されたURLへリダイレクトする。
このメソッドはあらゆる出力の前に呼ばなくてはならない。 

=item C<< parsePeriod >>

  $TL->parsePeriod('10hour 30min')

時間指定文字列を秒数に変換する。
L</"度量衡"> を参照。

=item C<< parseQuantity >>

  $TL->parseQuantity('100mi 50ki')

量指定文字列を元の数に変換する。
L</"度量衡"> を参照。

=item C<< getCookie >>

L<TL::Cookie> オブジェクトを取得。

=item C<< getCsv >>

L<TL::CSV> オブジェクトを取得。

=item C<< newDateTime >>

L<TL::DateTime> オブジェクトを作成。

=item C<< getDB >>

  $DB = $TL->getDB($group)

L<TL::DB> オブジェクトを取得。

=item C<< newDB >>

  $DB = $TL->newDB($group)

L<TL::DB> オブジェクトを作成。

=item C<< getFileSentinel >>

L<TL::FileSentinel> オブジェクトを取得。

=item C<< newForm >>

L<TL::Form> オブジェクトを作成。

=item C<< newHtmlFilter >>

L<TL::HtmlFilter> オブジェクトを作成。

=item C<< newHtmlMail >>

L<TL::HtmlMail> オブジェクトを作成。

=item C<< newIni >>

L<TL::Ini> オブジェクトを作成。

=item C<< newMail >>

L<TL::Mail> オブジェクトを作成。

=item C<< getMemorySentinel >>

L<TL::MemorySentinel> オブジェクトを取得。

=item C<< newPager >>

L<TL::Pager> オブジェクトを作成。

=item C<< getRawCookie >>

L<TL::RawCookie> オブジェクトを取得。

=item C<< newSendmail >>

L<TL::Sendmail> オブジェクトを作成。

=item C<< newSMIME >>

L<TL::SMIME> オブジェクトを作成。

=item C<< newTagCheck >>

L<TL::TagCheck> オブジェクトを作成。

=item C<< newTemplate >>

L<TL::Template> オブジェクトを作成。

=item C<< getSession >>

L<TL::Session> オブジェクトを取得。

=item C<< newValue >>

L<TL::Value> オブジェクトを作成。

=item C<< newValidator >>

L<TL::Validator> オブジェクトを生成。

=item C<< newMemCached >>

L<TL::MemCached> オブジェクトを生成。

=item C<< charconv >>

  $str = $TL->charconv($str, $from, $to, $prefer_encode);
  $str = $TL->charconv($str, [$from1, $from2, ...], $to, $prefer_encode);
  
  $str = $TL->charconv($str, 'auto' => 'UTF-8');
  $str = $TL->charconv($str, ['EUC-JP', 'Shift_JIS'] => 'UTF-8');

文字コード変換を行う。 L<Encode> が利用可能、且つ C<$prefer_encode> が
真である場合は、 L<Encode> が用いられる。そうでない場合は
L<Unicode::Japanese> が用いられる。

L<Encode> 使用時、変換元文字コードに C<'auto'> を指定すると、
L<Unicode::Japanese> の L<getcode()|Unicode::Japanese/"getcode">
と同じ優先順位で文字コードを自動判別する。また、エンコード名の候補を
配列で指定すると、指定された優先順位で自動判別する。

L<Unicode::Japanese> 使用時に配列で候補を指定した場合は、その配列が無視され、
C<'auto'> が指定されたものと見做される。

C<$from> が省略された場合は C<'auto'> に、
C<$to> が省略された場合は C<'UTF-8'> になる。

確実に指定できる文字コードは、UTF-8，Shift_JIS，EUC-JP，ISO-2022-JP である。
それ以外の場合は、L<Encode> と L<Unicode::Japanese> のどちらが使用されるかにより使用できるものが異なる。

=item C<< readFile >>

  $data = $TL->readFile($fpath);

ファイルを読み込む。文字コード変換をしない。
ファイルロック処理は行わないので、使用の際には注意が必要。

=item C<< readTextFile >>

  $data = $TL->readTextFile($fpath, $coding, $prefer_encode);

ファイルを読み込み、UTF-8に変換する。
ファイルロック処理は行わないので、使用の際には注意が必要。

C<$coding> が省略された場合は C<'auto'> となる。C<$prefer_encode> を真
にすると L<Encode> が利用可能な場合は L<Encode> で変換する。

=item C<< writeFile >>

  $TL->writeFile($fpath, $fdata, $fmode);

ファイルにデータを書き込む。文字コード変換をしない。
ファイルロック処理は行わないので、使用の際には注意が必要。

C<$fmode> が0ならば、上書きモード。
C<$fmode> が1ならば、追加モード。

省略された場合は上書きモードとなる。

=item C<< writeTextFile >>

  $TL->writeTextFile($fpath, $fdata, $fmode, $coding, $prefer_encode);

ファイルにデータを書き込む。C<$fdata> をUTF-8と見なし、指定された文字コードへ変換を行う。
ファイルロック処理は行わないので、使用の際には注意が必要。

C<$fmode> が0ならば、上書きモード。
C<$fmode> が1ならば、追加モード。

省略された場合は上書きモードとなる。

C<$coding> が省略された場合、utf8として扱う。C<$prefer_encode> を真にする
と L<Encode> が利用可能な場合は L<Encode> で変換する。

=item C<< watch >>

  $TL->watch(sdata => \$sdata, $reclevel);
  $TL->watch(adata => \@adata, $reclevel);
  $TL->watch(hdata => \%hdata, $reclevel);

指定したスカラー、配列、ハッシュデータの更新をウォッチし、ログに出力する。
第1引数で変数名を、第2引数で対象変数へのリファレンスを渡す。

第2引数はウォッチ対象の変数に、リファレンスが渡された場合に、
そのリファレンスの先を何段階ウォッチするかを指定する。デフォルトは0。

スカラー、配列、ハッシュ以外のリファレンスが代入された場合はエラーとなる。

また、再帰的にウォッチする場合、変数名は親の変数名を利用して自動的に設定される。

=item C<< dump >>

  $TL->dump(DATA => \$data);
  $TL->dump(DATA => \$data, $level);

第2引数に変数へのリファレンスを渡すと，その内容を Data::Dumper でダンプし、
第1引数のグループ名で $TL->log を呼び出す。

第3引数で、リファレンスをどのくらいの深さまで追うかを指定することが出来る。
指定しなければ全て表示される。

=item C<< printCacheUnlessModified >>

  $bool = $TL->printCacheUnlessModified($key, $flag, $param, $charset)

第1引数で割り当てられたキーがメモリ上にキャッシュされているかを調べる。
利用するには、memcached が必須となる。

第2引数がonの場合、304を返す動作を行う。offの場合、304を返す動作を行わない。省略可能。

デフォルトはon。

第3引数では、L<TL::Form> クラスのインスタンスを指定する。
Formクラスのキーが出力文字列中に存在している場合、値に置換する。省略可能。

第4引数では、第3引数で指定した文字列をUTF-8から変換する際の文字コードを指定する。
省略可能。

使用可能なコードは次の通り。
UTF-8，Shift_JIS，EUC-JP，ISO-2022-JP

デフォルトはShift_JIS。

第2引数がonの場合で、第3引数が省略された場合、以下の動作を行う。

1.memcachedからキーに割り当てられたキャッシュデータを読み込む。
データが無ければ、1を返す。

2.キャッシュデータの保存された時間と前回アクセスされた時間を比較し、
キャッシュデータが新しければキャッシュデータを出力し、undefを返す。

3.アクセスされた時間が新しければ、304ステータスを出力し、undefを返す。

この関数からundefを返された場合、以後出力を行う操作を行ってはならない。

=item C<< setCache >>

  $TL->setCache($key, $param, $charset, $priority)


第1引数で割り当てられたキーに対して出力される内容をメモリ上にキャッシュする。
また、Last-Modifiedヘッダを出力する。
printCacheUnlessModifiedより後で実行する必要がある。
利用するには、memcached が必須となる。

第2引数では、L<TL::Form> クラスのインスタンスを指定する。
Formクラスのキーが出力文字列中に存在している場合、値に置換する。省略可能。

第3引数では、第2引数で指定した文字列をUTF-8から変換する際の文字コードを指定する。
省略可能。

使用可能なコードは次の通り。
UTF-8，Shift_JIS，EUC-JP，ISO-2022-JP

デフォルトはShift_JIS。

第4引数には、L<TL::Filter::MemCached>への優先度を記述する。省略可能。
デフォルトは1500。

TL::Filter::MemCachedは必ず最後に実行する必要性があるため、
1500以上の優先度で設定するフィルタが他にある場合は手動で設定する必要がある。

=item C<< deleteCache >>

  $TL->deleteCache($key)

第1引数で割り当てられたキーのキャッシュを削除する。
利用するには、memcached が必須となる。

なお、setCacheの後にdeleteCacheを実行しても、setCacheでのメモリへの書き込みは、
処理の最後に行われるので、deleteCacheは反映されない。

本関数の使い方としては、キャッシュの内容を含んでいるデータを更新した場合に
該当するキャッシュを削除するように使用する。
それにより、次回アクセス時に最新の情報が出力される。

=item C<< getDebug >>

=item C<< newError >>

内部用メソッド。


=back

=head2 Ini パラメータ

グループ名は常に B<TL> でなければならない。

例:

  [TL]
  logdir = /home/www/cgilog/
  errortemplate = /home/www/error.html

=over 4

=item maxrequestsize

  maxrequestsize = 16M 500K

最大リクエストサイズ。但しファイルアップロードの分を除く。デフォルトは8M。

=item maxfilesize

  maxfilesize = 100M

一回のPOSTでアップロード可能なファイルサイズの合計。デフォルトは8M。ファ
イルのサイズは maxrequestsize とは別にカウントされ、ファイルでないもの
については maxrequestsize の値が使われる。

=item logdir

  logdir = /home/www/cgilog/

ログの出力ディレクトリ。

=item tempdir

  tempdir = /tmp

一時ファイルを置くディレクトリ。このパラメータの指定が無い時、アップロー
ドされたファイルは全てメモリ上に置かれるが、指定があった場合は指定され
たディレクトリに一時ファイルとして置かれる。一時ファイルを作る際には、
ファイルを open した直後に unlink する為、アプリケーション側でファイル
ハンドルを閉じたりプロセスを終了したりすると、作られた一時ファイルは直
ちに自動で削除される。

=item errormail

  errormail = null@example.org%Sendmail

sendErrorや、エラー発生時にメールを送る先を指定する。
アカウント名@ドメイン名%inigroup、の形式で指定する。
inigroupに。 L<TL::Sendmail> クラスで使用するinigroupを指定する。
inigroupが省略されると C<'Sendmail'> が使われる。

=item errormailtype

  errormailtype = error file-update memory-leak

どのような事象が発生した時に errormail で指定された先にメールを送るか。
以下の項目をスペース区切りで任意の数だけ指定する。
デフォルトは 'error memory-leak' である。

=over 4

=item error

エラーが発生した時にメールを送る。
メールの内容にはスタックトレース等が含まれる。

=item file-update

L<TL::FileSentinel> が監視対象のファイルの更新を検出した時にメールを送る。
メールの内容には更新されたファイルやその更新時刻が含まれる。

=item memory-leak

L<TL::MemorySentinel> がメモリリークの可能性を検出した時にメールを送る。
メールの内容にはメモリの使用状況が含まれる。

=back

=item errorlog

  errorlog = 1

エラー発生時にログに情報を残すかどうかを指定する。
1 が指定されればエラー情報を残す。
2 が指定されれば、エラー情報に加え、CGIのリクエスト内容も残す（startCgi内でのエラーのみ）。
3 が指定されれば、ローカル変数内容を含んだ詳細なエラー情報に加えて（但し PadWalker が必要）、CGIのリクエスト内容も残す。
0 であれば情報を残さない。
デフォルトは 1。

=item memorylog

  memorylog = full

リクエスト毎にメモリ消費状況をログに残すかどうかを指定する。
'leak', 'full' のどちらかから選ぶ。
'leak' の場合は、メモリリークが検出された場合のみログに残す。
'full' の場合は、メモリリークの検出とは無関係に、リクエスト毎にログに残す。
デフォルトは 'leak'。

=item trap

  trap = die

エラー処理の種類。'none', 'die'，'diewithprint' から選ぶ。デフォルトは'die'。

=over 4

=item none

エラートラップを一切しない。

=item die

L</"Main関数"> がdieした場合にエラー表示。それ以外の場所ではトラップしない。warnは見逃す。

=item diewithprint

L</"Main関数"> がdieした場合にエラー表示。L</"Main関数"> 以外でdieした場合は、ヘッダと共にエラー内容をテキストで表示する。warnは見逃す。

=back

=item stacktrace

  stacktrace = full

エラー発生時に表示するスタックトレースの種類。'none' の場合は、スタック
トレースを一切表示しない。'onlystack' の場合は、スタックトレースのみを
表示する。'full' の場合は、スタックトレースに加えてソースコード本体並び
に各フレームに於けるローカル変数の一覧をも表示する。デフォルトは
 'onlystack'。

但しローカル変数一覧を表示するには L<PadWalker> がインストールされてい
なければならない。

注意: 'full' の状態では、stackallow で許された全てのユーザーが、
ブラウザから全てのソースコード及び ini
ファイルの中身を読む事が出来る点に注意すること。

=item stackallow

  stackallow = 192.168.0.0/24

stacktrace の値が 'none' でない場合であっても、stackallow で指定された
ネットマスクに該当しない IP からの接続である場合には、スタックトレース
を表示しない。マスクは空白で区切って複数個指定する事が可能。
デフォルトは全て禁止。

=item maxrequestcount

  maxrequestcount = 100

FastCGIモード時に、1つのプロセスで何回まで処理を行うかを設定する。
0を設定すれば回数によってプロセスが終了することはない。
デフォルトは0。

=item errortemplate

  errortemplate = /home/www/error.html

エラー発生時に、通常のエラー表示ではなく、指定された
テンプレートファイルを表示する。

=item outputbuffering

  outputbuffering = 0

startCgi メソッド中で出力をバッファリングする。デフォルトは0。

バッファリングしない場合、print した内容はすぐに表示されるが、少しでも表示を行った後にエラーが発生した場合は、エラーテンプレートが綺麗に表示されない。

バッファリングを行った場合、print した内容はリクエスト終了時まで表示されないが、処理中にエラーが発生した場合、出力内容は破棄され，エラーテンプレートの内容に差し替えられる。

=back

=head2 度量衡

=head3 時間指定

各種タイムアウト時間，セッションのexpiresなど、
時間間隔は以下の指定が可能とする。

単位は大文字小文字を区別しない。

=over 4

=item 数値のみ

秒数での指定を表す。

=item 数値＋ 'sec' or 'second' or 'seconds'

秒での指定を表す。[×1]

=item 数値＋ 'min' or 'minute' or 'minutes'

分での指定を表す。[×60]

=item 数値＋ 'hour' or 'hours'

時間での指定を表す。[×3600]

=item 数値＋ 'day' or 'days'

日数での指定を表す。[×24*3600]

=item 数値＋ 'mon' or 'month' or 'months'

月での指定を表す。１月＝30日として計算する。 [×30*24*3600]

=back

=head3 量指定

メモリサイズ、文字列サイズ等、大きさを指定する場合には、
以下の指定が可能とする。英字の大文字小文字は同一視する。

=head4 10進数系

=over 4

=item 数値のみ

そのままの数を表す。

=item 数値＋ 'k'

数値×1000の指定を表す。[×1,000]

=item 数値＋ 'm'

数値×1000^2の指定を表す。[×1,000,000=×1,000^2]

=item 数値＋ 'g'

数値×1000^3の指定を表す。[×1,000,000,000=×1,000^3]

=item 数値＋ 't'

数値×1000^4の指定を表す。[×1,000,000,000,000=×1,000^4]

=item 数値＋ 'p'

数値×1000^5の指定を表す。[×1,000,000,000,000,000=×1,000^5]

=item 数値＋ 'e'

数値×1000^6の指定を表す。[×1,000,000,000,000,000,000=×1,000^6]

=back

=head4 2進数系

=over 4

=item 数値＋ 'Ki'

数値×1024の指定を表す。[×1024=2^10]

=item 数値＋ 'Mi'

数値×1024^2の指定を表す。[×1024^2=2^20]

=item 数値＋ 'Gi'

数値×1024^3の指定を表す。[×1024^3=2^30]

=item 数値＋ 'Ti'

数値×1024^4の指定を表す。[×1024^4=2^40]

=item 数値＋ 'Pi'

数値×1024^5の指定を表す。[×1024^5=2^50]

=item 数値＋ 'Ei'

数値×1024^6の指定を表す。[×1024^6=2^60]

=back

=head1 SEE ALSO

=over 4

=item L<TL::Cookie>

=item L<TL::DB>

=item L<TL::Debug>

CGI向けデバッグ機能。

リクエストや応答のログ記録、デバッグ情報のポップアップ表示、他。

=item L<TL::Filter>

=item L<TL::FileSentinel>

=item L<TL::Form>

=item L<TL::HtmlFilter>

=item L<TL::HtmlMail>

=item L<TL::Ini>

=item L<TL::InputFilter>

=item L<TL::Mail>

=item L<TL::MemorySentinel>

=item L<TL::Pager>

=item L<TL::RawCookie>

=item L<TL::Sendmail>

=item L<TL::SMIME>

=item L<TL::TagCheck>

=item L<TL::Template>

=item L<TL::Session>

=item L<TL::Value>

=item L<TL::Validator>

=back

=head1 AUTHOR INFORMATION

=over 4

Copyright 2006 YMIRLINK Inc. All Rights Reserved.

This framework is free software; you can redistribute it and/or modify it under the same terms as Perl itself

このフレームワークはフリーソフトウェアです。あなたは Perl と同じライセンスの 元で再配布及び変更を行うことが出来ます。

Address bug reports and comments to: tl@tripletail.jp

HP : http://tripletail.jp/

=back

=cut
